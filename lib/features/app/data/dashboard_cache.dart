import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../ranking/domain/ranking_models.dart';

class DashboardCache {
  DashboardCache(this._prefs);

  final SharedPreferences _prefs;

  static const _rankingKey = 'dashboard.ranking.v1';
  static const _lastSyncKey = 'dashboard.last_sync_at.v1';

  List<RankingRow>? readRanking() {
    final raw = _prefs.getString(_rankingKey);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => RankingRow.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } on Exception {
      return null;
    }
  }

  Future<void> writeRanking(List<RankingRow> rows) async {
    final payload = jsonEncode(rows.map((row) => row.toJson()).toList());
    await _prefs.setString(_rankingKey, payload);
  }

  DateTime? readLastSync() {
    final millis = _prefs.getInt(_lastSyncKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  Future<void> writeLastSync(DateTime time) async {
    await _prefs.setInt(_lastSyncKey, time.toUtc().millisecondsSinceEpoch);
  }
}
