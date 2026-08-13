import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:enfermicambio/features/feed/data/supabase_feed_repository.dart';
import 'package:enfermicambio/features/feed/domain/feed_models.dart';

void main() {
  test('loads posts even when feed relations are queried separately', () async {
    final httpClient = MockClient((request) async {
      final table = request.url.pathSegments.last;
      final body = switch (table) {
        'posts' => [
          {
            'id': 'post-1',
            'author_id': 'user-1',
            'post_type': 'meal',
            'caption': 'Almuerzo del día',
            'created_at': '2026-08-12T19:00:00Z',
            'system_generated': false,
          },
        ],
        'profiles' => [
          {'id': 'user-1', 'display_name': 'Freddy', 'avatar_url': null},
        ],
        'post_media' => <Map<String, dynamic>>[],
        'reactions' => [
          {'post_id': 'post-1'},
        ],
        'comments' => [
          {'post_id': 'post-1'},
          {'post_id': 'post-1'},
        ],
        _ => <Map<String, dynamic>>[],
      };
      return http.Response(
        jsonEncode(body),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: httpClient,
    );
    addTearDown(client.dispose);

    final page = await SupabaseFeedRepository(
      client: client,
    ).loadLatest(limit: 20);

    expect(page.posts, hasLength(1));
    expect(page.posts.single.authorName, 'Freddy');
    expect(page.posts.single.caption, 'Almuerzo del día');
    expect(page.posts.single.type, PostType.meal);
    expect(page.posts.single.reactionCount, 1);
    expect(page.posts.single.commentCount, 2);
  });

  test('keeps a post visible when optional feed relations fail', () async {
    final httpClient = MockClient((request) async {
      final table = request.url.pathSegments.last;
      if (table != 'posts') {
        return http.Response('denied', 403, request: request);
      }
      return http.Response(
        jsonEncode([
          {
            'id': 'post-2',
            'author_id': 'user-2',
            'post_type': 'text',
            'caption': 'Publicación visible',
            'created_at': '2026-08-12T18:00:00Z',
            'system_generated': false,
          },
        ]),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: httpClient,
    );
    addTearDown(client.dispose);

    final page = await SupabaseFeedRepository(
      client: client,
    ).loadLatest(limit: 20);

    expect(page.posts, hasLength(1));
    expect(page.posts.single.authorName, 'Amigo');
    expect(page.posts.single.caption, 'Publicación visible');
  });
}
