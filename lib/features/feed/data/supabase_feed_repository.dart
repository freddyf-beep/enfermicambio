import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/text/text_encoding.dart';
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
          'post_media(url, media_type, sort_order), '
          'reactions(count), comments(count)',
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

    final posts = await Future.wait(
      slice
          .map<Future<FeedPost>>((row) async {
            final author = _relationObject(row['profiles']);
            final media = await _resolveMedia(row['post_media']);
            return FeedPost(
              id: row['id'] as String,
              authorId: row['author_id'] as String,
              authorName: repairMojibake(
                (author['display_name'] as String?) ?? 'Unknown',
              ),
              authorAvatarUrl: author['avatar_url'] as String?,
              type: _mapType(row['post_type'] as String),
              createdAt: DateTime.parse(row['created_at'] as String),
              isSystem: row['system_generated'] as bool,
              caption: (row['caption'] as String?) == null
                  ? null
                  : repairMojibake(row['caption'] as String),
              mediaUrls: media,
              reactionCount: _count(row['reactions']),
              commentCount: _count(row['comments']),
            );
          })
          .toList(growable: false),
    );

    return FeedPage(posts: posts, nextCursor: nextCursor);
  }

  Future<List<String>> _resolveMedia(dynamic rawMedia) async {
    final media = rawMedia is List ? rawMedia : const <dynamic>[];
    final urls = await Future.wait(
      media.map((raw) async {
        final value = raw is Map ? raw['url'] as String? : null;
        if (value == null || value.isEmpty) return null;
        if (value.startsWith('http://') || value.startsWith('https://')) {
          return value;
        }

        final separator = value.indexOf('/');
        if (separator <= 0 || separator == value.length - 1) return null;
        final bucket = value.substring(0, separator);
        final path = value.substring(separator + 1);
        try {
          return await _client.storage.from(bucket).createSignedUrl(path, 3600);
        } on Exception {
          return null;
        }
      }),
    );
    return urls.whereType<String>().toList(growable: false);
  }

  int _count(dynamic rows) {
    if (rows is! List || rows.isEmpty) return 0;
    final first = rows.first;
    if (first is Map<String, dynamic>) {
      return ((first['count'] as num?) ?? 0).toInt();
    }
    return 0;
  }

  Map<String, dynamic> _relationObject(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    if (value is List && value.isNotEmpty && value.first is Map) {
      return (value.first as Map).cast<String, dynamic>();
    }
    return const {};
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
