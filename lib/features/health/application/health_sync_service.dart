import 'package:timezone/timezone.dart' as timezone;

import '../../../shared/config/app_config.dart';
import '../domain/activity_segmenter.dart';
import '../domain/health_models.dart';

class HealthSyncService {
  const HealthSyncService({
    required this._repository,
    required this._sink,
    this._segmenter = const ActivitySegmenter(),
    this._config = const AppConfig.defaults(),
  });

  final HealthRepository _repository;
  final DailyActivitySink _sink;
  final ActivitySegmenter _segmenter;
  final AppConfig _config;

  Future<HealthSyncResult> sync({DateTime? now}) async {
    final currentTime = now ?? DateTime.now().toUtc();
    final read = await _repository.readToday(
      now: currentTime,
      competitionTimezone: _config.competitionTimezone,
    );
    if (read.status != HealthReadStatus.success) {
      return HealthSyncResult(
        readStatus: read.status,
        aggregate: null,
        message: read.message,
      );
    }

    final localDate = _localDate(currentTime);
    final aggregate = _segmenter.segment(
      samples: read.samples,
      competitionDate: localDate,
      competitionTimezone: _config.competitionTimezone,
      windows: _config.windows,
      syncedAt: read.lastSyncedAt,
      sourcePlatform: read.sourcePlatform,
      sourceApp: _firstSourceApp(read.samples),
      sourceDevice: _firstSourceDevice(read.samples),
      recordingMethod: read.samples.any((sample) => sample.isManual)
          ? 'mixed'
          : 'automatic',
      sourceMetadata: {
        'sample_count': read.samples.length,
        'manual_records_excluded': read.samples
            .where((sample) => sample.isManual)
            .length,
      },
    );
    await _sink.upsert(aggregate);
    return HealthSyncResult(readStatus: read.status, aggregate: aggregate);
  }

  DateTime _localDate(DateTime currentTime) {
    final location = timezone.getLocation(_config.competitionTimezone);
    final local = timezone.TZDateTime.from(currentTime.toUtc(), location);
    return DateTime(local.year, local.month, local.day);
  }

  String? _firstSourceApp(List<HealthSample> samples) {
    return samples.isEmpty ? null : samples.first.sourceApp;
  }

  String? _firstSourceDevice(List<HealthSample> samples) {
    return samples.isEmpty ? null : samples.first.sourceDevice;
  }
}

class HealthSyncResult {
  const HealthSyncResult({
    required this.readStatus,
    required this.aggregate,
    this.message,
  });

  final HealthReadStatus readStatus;
  final DailyActivityAggregate? aggregate;
  final String? message;
}
