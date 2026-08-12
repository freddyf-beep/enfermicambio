import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profiles/data/supabase_profile_repository.dart';
import '../domain/notification_models.dart';

/// Supabase-backed notification repository. Reads and marks read the current
/// user's rows (RLS restricts to the owner); new rows arrive via Realtime
/// and are refetched from the database, which stays authoritative.
class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository({required this._client});

  final SupabaseClient _client;
  RealtimeChannel? _channel;
  final _unreadController = StreamController<int>.broadcast();

  @override
  Future<NotificationPage> loadLatest({required int limit}) async {
    final data = await _client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    final items = (data as List)
        .map((row) => AppNotification.fromJson(row as Map<String, dynamic>))
        .toList();
    return NotificationPage(
      items: items,
      nextCursor: items.length == limit
          ? items.last.createdAt.toUtc().toIso8601String()
          : null,
    );
  }

  @override
  Future<NotificationPage> loadAfter({
    required String cursor,
    required int limit,
  }) async {
    PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _client
        .from('notifications')
        .select();
    final data = await query
        .lt('created_at', cursor)
        .order('created_at', ascending: false)
        .limit(limit);
    final items = data
        .map((row) => AppNotification.fromJson(row))
        .toList(growable: false);
    return NotificationPage(
      items: items,
      nextCursor: items.length == limit
          ? items.last.createdAt.toUtc().toIso8601String()
          : null,
    );
  }

  @override
  Future<int> unreadCount() async {
    final data = await _client
        .from('notifications')
        .select('id')
        .eq('is_read', false);
    return data.length;
  }

  @override
  Future<void> markRead(String id) async {
    await _client.from('notifications').update({'is_read': true}).eq('id', id);
    await _emitCount();
  }

  @override
  Future<void> markAllRead() async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('is_read', false);
    await _emitCount();
  }

  @override
  Future<NotificationPreferences> fetchPreferences() async {
    final userId = _client.auth.currentSession?.user.id;
    if (userId == null) {
      return NotificationPreferences.allEnabled;
    }
    final repository = SupabaseProfileRepository(client: _client);
    final profile = await repository.fetchById(userId);
    return NotificationPreferences.fromJson(profile.notificationPreferences);
  }

  @override
  Future<void> setPreference(
    NotificationCategory category,
    bool enabled,
  ) async {
    final current = await fetchPreferences();
    final next = current.copyWithEnabled(category, enabled);
    final userId = _client.auth.currentSession?.user.id;
    if (userId == null) return;
    await _client
        .from('profiles')
        .update({'notification_preferences': next.toJson()})
        .eq('id', userId);
  }

  @override
  Stream<int> watchUnreadCount() {
    _subscribe();
    return _unreadController.stream;
  }

  void _subscribe() {
    if (_channel != null) return;
    _channel = _client
        .channel('notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (_) {
            _emitCount();
          },
        )
        .subscribe();
    _emitCount();
  }

  Future<void> _emitCount() async {
    try {
      final count = await unreadCount();
      if (!_unreadController.isClosed) {
        _unreadController.add(count);
      }
    } on Exception {
      // Best effort: the badge silently keeps its last known value.
    }
  }

  void dispose() {
    final channel = _channel;
    if (channel != null) {
      _client.removeChannel(channel);
      _channel = null;
    }
    _unreadController.close();
  }
}
