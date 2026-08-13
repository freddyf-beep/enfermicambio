import 'dart:typed_data';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabasePostRepository {
  const SupabasePostRepository({required this._client});

  final SupabaseClient _client;

  Future<String> createTextPost({
    required String authorId,
    required String caption,
  }) async {
    final row = await _client
        .from('posts')
        .insert({
          'author_id': authorId,
          'post_type': 'text',
          'caption': caption,
          'system_generated': false,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<String> createPhotoPost({
    required String authorId,
    required String caption,
    required List<String> mediaUrls,
  }) async {
    final row = await _client
        .from('posts')
        .insert({
          'author_id': authorId,
          'post_type': 'photo',
          'caption': caption,
          'system_generated': false,
        })
        .select('id')
        .single();
    final postId = row['id'] as String;

    await _client.from('post_media').insert([
      for (var i = 0; i < mediaUrls.length; i++)
        {
          'post_id': postId,
          'url': mediaUrls[i],
          'media_type': 'image',
          'sort_order': i,
        },
    ]);

    return postId;
  }

  Future<String> createWorkoutPost({
    required String authorId,
    required String workoutId,
    required String caption,
  }) async {
    final existing = await _client
        .from('posts')
        .select('id')
        .eq('author_id', authorId)
        .eq('workout_id', workoutId)
        .eq('post_type', 'workout')
        .maybeSingle();
    if (existing != null) return existing['id'] as String;
    try {
      final row = await _client
          .from('posts')
          .insert({
            'author_id': authorId,
            'post_type': 'workout',
            'caption': caption,
            'workout_id': workoutId,
            'system_generated': false,
          })
          .select('id')
          .single();
      return row['id'] as String;
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      final raced = await _client
          .from('posts')
          .select('id')
          .eq('author_id', authorId)
          .eq('workout_id', workoutId)
          .eq('post_type', 'workout')
          .single();
      return raced['id'] as String;
    }
  }

  Future<String> createMealPost({
    required String authorId,
    required String caption,
    required String foodEntryId,
    List<String> mediaUrls = const [],
  }) async {
    final row = await _client
        .from('posts')
        .insert({
          'author_id': authorId,
          'post_type': 'meal',
          'caption': caption,
          'food_entry_id': foodEntryId,
          'system_generated': false,
        })
        .select('id')
        .single();
    final postId = row['id'] as String;
    if (mediaUrls.isNotEmpty) {
      await _client.from('post_media').insert([
        for (var i = 0; i < mediaUrls.length; i++)
          {
            'post_id': postId,
            'url': mediaUrls[i],
            'media_type': 'image',
            'sort_order': i,
          },
      ]);
    }
    return postId;
  }

  /// Uploads a private image and stores a bucket/path reference in
  /// `post_media.url`. The feed resolves that reference into a short-lived
  /// signed URL when it reads the post.
  Future<String> uploadPhotoPost({
    required String authorId,
    required String caption,
    required String filePath,
    String bucket = 'meal-media',
    String contentType = 'image/jpeg',
  }) {
    return uploadPhotoPostWithRetry(
      authorId: authorId,
      caption: caption,
      filePath: filePath,
      bucket: bucket,
      contentType: contentType,
    );
  }

  Future<String> uploadPhotoPostWithRetry({
    required String authorId,
    required String caption,
    required String filePath,
    String bucket = 'feed-media',
    String contentType = 'image/jpeg',
    int attempts = 3,
  }) async {
    final extension = contentType.contains('png') ? '.png' : '.jpg';
    final storagePath =
        '$authorId/${DateTime.now().microsecondsSinceEpoch}$extension';
    Object? lastError;
    final reference = '$bucket/$storagePath';
    var uploaded = false;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        await _client.storage
            .from(bucket)
            .upload(
              storagePath,
              File(filePath),
              fileOptions: FileOptions(
                contentType: contentType,
                upsert: attempt > 0,
              ),
            );
        uploaded = true;
        break;
      } on Object catch (error) {
        lastError = error;
        if (attempt + 1 < attempts) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }
    }
    if (uploaded) {
      try {
        return await createPhotoPost(
          authorId: authorId,
          caption: caption,
          mediaUrls: [reference],
        );
      } on Object {
        try {
          await _client.storage.from(bucket).remove([storagePath]);
        } on Object {
          // Best effort cleanup; preserve the post/media error.
        }
        rethrow;
      }
    }
    try {
      await _client.storage.from(bucket).remove([storagePath]);
    } on Object {
      // Best effort cleanup; preserve the upload/post error.
    }
    throw StateError(
      'No se pudo publicar la foto tras $attempts intentos: $lastError',
    );
  }

  Future<String> shareWorkoutRoute({
    required String authorId,
    required String workoutId,
    required String caption,
    required Uint8List previewBytes,
  }) async {
    const bucket = 'workout-media';
    final storagePath = '$authorId/routes/$workoutId.png';
    final reference = '$bucket/$storagePath';
    final existing = await _client
        .from('posts')
        .select('id')
        .eq('author_id', authorId)
        .eq('workout_id', workoutId)
        .eq('post_type', 'route')
        .maybeSingle();
    if (existing != null) {
      // A feed retry must also repair a missing/deleted preview, not just
      // return the already-existing post.
      await _client.storage
          .from(bucket)
          .uploadBinary(
            storagePath,
            previewBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );
      final postId = existing['id'] as String;
      final media = await _client
          .from('post_media')
          .select('id')
          .eq('post_id', postId)
          .limit(1);
      if (media.isEmpty) {
        await _client.from('post_media').insert({
          'post_id': postId,
          'url': reference,
          'media_type': 'image',
          'sort_order': 0,
        });
      }
      return postId;
    }

    try {
      await _client.storage
          .from(bucket)
          .uploadBinary(
            storagePath,
            previewBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );
      final row = await _client
          .from('posts')
          .insert({
            'author_id': authorId,
            'post_type': 'route',
            'caption': caption,
            'workout_id': workoutId,
            'system_generated': false,
          })
          .select('id')
          .single();
      final postId = row['id'] as String;
      await _client.from('post_media').insert({
        'post_id': postId,
        'url': reference,
        'media_type': 'image',
        'sort_order': 0,
      });
      return postId;
    } on PostgrestException {
      final raced = await _client
          .from('posts')
          .select('id')
          .eq('author_id', authorId)
          .eq('workout_id', workoutId)
          .eq('post_type', 'route')
          .maybeSingle();
      if (raced != null) {
        final media = await _client
            .from('post_media')
            .select('id')
            .eq('post_id', raced['id'] as String)
            .limit(1);
        if (media.isEmpty) {
          await _client.from('post_media').insert({
            'post_id': raced['id'],
            'url': reference,
            'media_type': 'image',
            'sort_order': 0,
          });
        }
        return raced['id'] as String;
      }
      try {
        await _client.storage.from(bucket).remove([storagePath]);
      } on Object {
        // Best effort cleanup.
      }
      rethrow;
    } on Object {
      try {
        await _client.storage.from(bucket).remove([storagePath]);
      } on Object {
        // Best effort cleanup.
      }
      rethrow;
    }
  }

  Future<void> addReaction({
    required String postId,
    required String userId,
    required String emoji,
  }) async {
    await _client.from('reactions').upsert({
      'post_id': postId,
      'user_id': userId,
      'emoji': emoji,
    });
  }

  Future<void> toggleReaction({
    required String postId,
    required String userId,
    required String emoji,
  }) async {
    final existing = await _client
        .from('reactions')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .eq('emoji', emoji)
        .maybeSingle();
    if (existing != null) {
      await _client
          .from('reactions')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .eq('emoji', emoji);
      return;
    }
    await addReaction(postId: postId, userId: userId, emoji: emoji);
  }

  Future<void> addComment({
    required String postId,
    required String authorId,
    required String body,
  }) async {
    await _client.from('comments').insert({
      'post_id': postId,
      'author_id': authorId,
      'body': body,
    });
  }
}
