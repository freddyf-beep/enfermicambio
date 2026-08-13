import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/text/text_encoding.dart';
import '../domain/feed_models.dart';

/// Feed access kept deliberately flat.
///
/// PostgREST nested relations are convenient, but one malformed relation,
/// missing foreign-key metadata, or a storage URL can make the whole response
/// impossible to decode. Posts are the source of truth; profiles, media and
/// counters are optional enrichments and can fail independently.
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
    final requestedLimit = limit < 1 ? 1 : limit;
    PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _client
        .from('posts')
        .select(
          'id, author_id, post_type, caption, created_at, system_generated',
        );
    if (before != null && before.isNotEmpty) {
      query = query.lt('created_at', before);
    }

    final rawPosts = await query
        .order('created_at', ascending: false)
        .limit(requestedLimit + 1);
    final data = _asRows(rawPosts);
    final hasMore = data.length > requestedLimit;
    final slice = hasMore ? data.sublist(0, requestedLimit) : data;
    if (slice.isEmpty) {
      return const FeedPage(posts: [], nextCursor: null);
    }

    final postIds = slice
        .map((row) => _string(row['id']))
        .whereType<String>()
        .toList();
    final authorIds = slice
        .map((row) => _string(row['author_id']))
        .whereType<String>()
        .toSet()
        .toList();

    // These queries are independent. A missing profile or a denied media
    // relation must never hide a text/event post from the feed.
    final related = await Future.wait<List<Map<String, dynamic>>>([
      _fetchByIds(
        table: 'profiles',
        columns: 'id, display_name, avatar_url',
        column: 'id',
        ids: authorIds,
      ),
      _fetchByIds(
        table: 'post_media',
        columns: 'post_id, url, media_type, sort_order',
        column: 'post_id',
        ids: postIds,
      ),
      _fetchByIds(
        table: 'reactions',
        columns: 'post_id',
        column: 'post_id',
        ids: postIds,
      ),
      _fetchByIds(
        table: 'comments',
        columns: 'post_id',
        column: 'post_id',
        ids: postIds,
      ),
    ]);

    final profilesById = <String, Map<String, dynamic>>{
      for (final row in related[0]) ?_string(row['id']): row,
    };
    final mediaByPost = _groupById(related[1], 'post_id');
    final reactionCounts = _countById(related[2]);
    final commentCounts = _countById(related[3]);

    final posts = await Future.wait(
      slice.map((row) async {
        final postId = _string(row['id']) ?? '';
        final authorId = _string(row['author_id']) ?? '';
        final profile = profilesById[authorId] ?? const <String, dynamic>{};
        final media = await _resolveMedia(mediaByPost[postId] ?? const []);
        final createdAt =
            DateTime.tryParse(_string(row['created_at']) ?? '')?.toLocal() ??
            DateTime.now();
        final rawCaption = row['caption'];

        return FeedPost(
          id: postId,
          authorId: authorId,
          authorName: repairMojibake(
            _string(profile['display_name']) ?? 'Amigo',
          ),
          authorAvatarUrl: _string(profile['avatar_url']),
          type: _mapType(_string(row['post_type']) ?? ''),
          createdAt: createdAt,
          isSystem: row['system_generated'] == true,
          caption: rawCaption == null
              ? null
              : repairMojibake(rawCaption.toString()),
          mediaUrls: media,
          reactionCount: reactionCounts[postId] ?? 0,
          commentCount: commentCounts[postId] ?? 0,
        );
      }),
    );

    return FeedPage(
      posts: posts,
      nextCursor: hasMore ? _string(slice.last['created_at']) : null,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchByIds({
    required String table,
    required String columns,
    required String column,
    required List<String> ids,
  }) async {
    if (ids.isEmpty) return const [];
    try {
      final rows = await _client
          .from(table)
          .select(columns)
          .inFilter(column, ids);
      return _asRows(rows);
    } on Object {
      return const [];
    }
  }

  List<Map<String, dynamic>> _asRows(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Map<String, List<Map<String, dynamic>>> _groupById(
    List<Map<String, dynamic>> rows,
    String key,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final id = _string(row[key]);
      if (id == null || id.isEmpty) continue;
      (grouped[id] ??= <Map<String, dynamic>>[]).add(row);
    }
    return grouped;
  }

  Map<String, int> _countById(List<Map<String, dynamic>> rows) {
    final counts = <String, int>{};
    for (final row in rows) {
      final id = _string(row['post_id']);
      if (id == null || id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<List<String>> _resolveMedia(List<Map<String, dynamic>> media) async {
    final urls = await Future.wait(
      media.map((row) async {
        final value = _string(row['url']);
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
        } on Object {
          return null;
        }
      }),
    );
    return urls.whereType<String>().toList(growable: false);
  }

  String? _string(dynamic value) {
    if (value == null) return null;
    final result = value.toString().trim();
    return result.isEmpty ? null : result;
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
