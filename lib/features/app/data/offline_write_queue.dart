import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A pending write that could not reach the backend. Stored locally and
/// replayed when connectivity returns.
class PendingWrite {
  const PendingWrite({
    required this.id,
    required this.operation,
    required this.payload,
    required this.createdAt,
  });

  factory PendingWrite.fromJson(Map<String, dynamic> json) {
    return PendingWrite(
      id: json['id'] as String,
      operation: json['operation'] as String,
      payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String operation;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operation': operation,
      'payload': payload,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }
}

/// Durable queue of writes that failed while offline. Persisted across app
/// restarts; `flush` retries them in order. Duplicate-safe writes (posts,
/// reactions) use idempotent operations so a retry never duplicates.
class OfflineWriteQueue {
  OfflineWriteQueue._(this._prefs);

  static const _key = 'offline.write_queue.v1';

  final SharedPreferences _prefs;

  static Future<OfflineWriteQueue> open() async {
    final prefs = await SharedPreferences.getInstance();
    return OfflineWriteQueue._(prefs);
  }

  int _nextId = 0;

  Future<List<PendingWrite>> _load() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => PendingWrite.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Exception {
      return [];
    }
  }

  Future<void> _save(List<PendingWrite> writes) async {
    await _prefs.setString(
      _key,
      jsonEncode(writes.map((write) => write.toJson()).toList()),
    );
  }

  Future<void> enqueue({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final writes = await _load();
    _nextId++;
    writes.add(
      PendingWrite(
        id: '${DateTime.now().millisecondsSinceEpoch}-$_nextId',
        operation: operation,
        payload: payload,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    await _save(writes);
  }

  Future<List<PendingWrite>> pending() => _load();

  /// Replays all queued writes. Returns writes that still failed so they stay
  /// queued. A successful write is removed from the queue.
  Future<List<PendingWrite>> flush(
    Future<void> Function(PendingWrite write) execute,
  ) async {
    final writes = await _load();
    if (writes.isEmpty) return [];
    final remaining = <PendingWrite>[];
    for (final write in writes) {
      try {
        await execute(write);
      } on Exception {
        remaining.add(write);
      } on Error {
        remaining.add(write);
      }
    }
    await _save(remaining);
    return remaining;
  }
}
