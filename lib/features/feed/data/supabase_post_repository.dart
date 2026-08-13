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
  }) async {
    final storagePath =
        '$authorId/${DateTime.now().microsecondsSinceEpoch}.jpg';
    final reference = '$bucket/$storagePath';
    try {
      await _client.storage
          .from(bucket)
          .upload(
            storagePath,
            File(filePath),
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
      return await createPhotoPost(
        authorId: authorId,
        caption: caption,
        mediaUrls: [reference],
      );
    } on Exception {
      try {
        await _client.storage.from(bucket).remove([storagePath]);
      } on Exception {
        // Best effort cleanup; keep the original upload/post error.
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
