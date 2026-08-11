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
