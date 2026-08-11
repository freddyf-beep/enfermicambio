import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/feed_models.dart';

class SupabaseFeedRepository implements FeedRepository {
  const SupabaseFeedRepository({required this._client});

  final SupabaseClient _client;

  @override
  Future<FeedPage> loadLatest({required int limit}) {
    return _load(limit: limit);
  }

  @override
  Future<FeedPage> loadAfter({required String cursor, required int limit}) {
    return _load(limit: limit, before: cursor);
  }

  Future<FeedPage> _load({required int limit, String? before}) async {
    PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _client
        .from('posts')
        .select(
          'id, author_id, post_type, caption, created_at, system_generated, '
          'profiles!posts_author_id_fkey(display_name, avatar_url), '
          'post_media(url, media_type, sort_order)',
        );
    if (before != null) {
      query = query.lt('created_at', before);
    }
    final data = await query
        .order('created_at', ascending: false)
        .limit(limit + 1);

    final hasMore = data.length > limit;
    final slice = hasMore ? data.sublist(0, limit) : data;
    final nextCursor = hasMore ? (slice.last['created_at'] as String) : null;

    final posts = slice
        .map<FeedPost>((row) {
          final author = row['profiles'] as Map<String, dynamic>? ?? const {};
          final media = (row['post_media'] as List<dynamic>? ?? const [])
              .map((m) => (m as Map<String, dynamic>)['url'] as String)
              .toList(growable: false);
          return FeedPost(
            id: row['id'] as String,
            authorId: row['author_id'] as String,
            authorName: (author['display_name'] as String?) ?? 'Unknown',
            authorAvatarUrl: author['avatar_url'] as String?,
            type: _mapType(row['post_type'] as String),
            createdAt: DateTime.parse(row['created_at'] as String),
            isSystem: row['system_generated'] as bool,
            caption: row['caption'] as String?,
            mediaUrls: media,
          );
        })
        .toList(growable: false);

    return FeedPage(posts: posts, nextCursor: nextCursor);
  }

  PostType _mapType(String type) {
    return switch (type) {
      'photo' => PostType.photo,
      'meal' => PostType.meal,
      'workout' => PostType.workout,
      'route' => PostType.route,
      'achievement' => PostType.achievement,
      'steps' => PostType.steps,
      'ranking_change' => PostType.rankingChange,
      'round_result' => PostType.roundResult,
      'mission' => PostType.mission,
      'season' => PostType.season,
      _ => PostType.text,
    };
  }
}
