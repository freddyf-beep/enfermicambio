import 'package:supabase_flutter/supabase_flutter.dart';

import '../../feed/data/supabase_post_repository.dart';
import 'offline_write_queue.dart';

/// Writes posts/reactions/comments with offline resilience: tries the backend
/// first, and on failure persists the operation in a durable queue that is
/// replayed on the next `flushPending`.
class OfflinePostService {
  OfflinePostService({required SupabaseClient client, OfflineWriteQueue? queue})
    : _posts = SupabasePostRepository(client: client) {
    _queue = queue;
  }

  final SupabasePostRepository _posts;
  OfflineWriteQueue? _queue;

  Future<OfflineWriteQueue> _ensureQueue() async {
    return _queue ??= await OfflineWriteQueue.open();
  }

  /// Attempts to create a text post; on failure it is queued for later.
  Future<void> createTextPost({
    required String authorId,
    required String caption,
  }) async {
    try {
      await _posts.createTextPost(authorId: authorId, caption: caption);
    } on Exception {
      final queue = await _ensureQueue();
      await queue.enqueue(
        operation: 'create_text_post',
        payload: {'author_id': authorId, 'caption': caption},
      );
    }
  }

  Future<void> addReaction({
    required String postId,
    required String userId,
    required String emoji,
  }) async {
    try {
      await _posts.addReaction(postId: postId, userId: userId, emoji: emoji);
    } on Exception {
      final queue = await _ensureQueue();
      await queue.enqueue(
        operation: 'add_reaction',
        payload: {'post_id': postId, 'user_id': userId, 'emoji': emoji},
      );
    }
  }

  Future<void> toggleReaction({
    required String postId,
    required String userId,
    required String emoji,
  }) async {
    try {
      await _posts.toggleReaction(postId: postId, userId: userId, emoji: emoji);
    } on Exception {
      final queue = await _ensureQueue();
      await queue.enqueue(
        operation: 'toggle_reaction',
        payload: {'post_id': postId, 'user_id': userId, 'emoji': emoji},
      );
    }
  }

  Future<void> addComment({
    required String postId,
    required String authorId,
    required String body,
  }) async {
    try {
      await _posts.addComment(postId: postId, authorId: authorId, body: body);
    } on Exception {
      final queue = await _ensureQueue();
      await queue.enqueue(
        operation: 'add_comment',
        payload: {'post_id': postId, 'author_id': authorId, 'body': body},
      );
    }
  }

  /// Replays queued writes. Returns how many remain pending.
  Future<int> flushPending() async {
    final queue = await _ensureQueue();
    final remaining = await queue.flush((write) async {
      switch (write.operation) {
        case 'create_text_post':
          await _posts.createTextPost(
            authorId: write.payload['author_id'] as String,
            caption: write.payload['caption'] as String,
          );
        case 'add_reaction':
          await _posts.addReaction(
            postId: write.payload['post_id'] as String,
            userId: write.payload['user_id'] as String,
            emoji: write.payload['emoji'] as String,
          );
        case 'toggle_reaction':
          await _posts.toggleReaction(
            postId: write.payload['post_id'] as String,
            userId: write.payload['user_id'] as String,
            emoji: write.payload['emoji'] as String,
          );
        case 'add_comment':
          await _posts.addComment(
            postId: write.payload['post_id'] as String,
            authorId: write.payload['author_id'] as String,
            body: write.payload['body'] as String,
          );
        default:
          throw StateError('Unknown operation: ${write.operation}');
      }
    });
    return remaining.length;
  }
}
