enum HealthRecordingMethod { unknown, active, automatic, manual }

enum HealthReadStatus {
  success,
  noData,
  permissionDenied,
  sourceUnavailable,
  backendUnavailable,
  retryableFailure,
}

enum HealthMetricType { steps, activeCalories, distance, exerciseMinutes }

class HealthSample {
  const HealthSample({
    required this.type,
    required this.value,
    required this.dateFrom,
    required this.dateTo,
    required this.sourceApp,
    required this.sourceDevice,
    required this.recordingMethod,
    this.sourceId,
  });

  final HealthMetricType type;
  final double value;
  final DateTime dateFrom;
  final DateTime dateTo;
  final String sourceApp;
  final String sourceDevice;
  final HealthRecordingMethod recordingMethod;
  final String? sourceId;

  bool get isManual => recordingMethod == HealthRecordingMethod.manual;
}

class HealthReadResult {
  const HealthReadResult({
    required this.status,
    required this.samples,
    required this.lastSyncedAt,
    this.sourcePlatform = 'unknown',
    this.message,
  });

  final HealthReadStatus status;
  final List<HealthSample> samples;
  final DateTime lastSyncedAt;
  final String sourcePlatform;
  final String? message;
}

class DailyActivityAggregate {
  const DailyActivityAggregate({
    required this.date,
    required this.morningSteps,
    required this.afternoonSteps,
    required this.nightSteps,
    required this.dailySteps,
    required this.activeCalories,
    required this.distanceMeters,
    required this.exerciseMinutes,
    required this.syncedAt,
    required this.manualRecordsExcluded,
    this.sourcePlatform = 'unknown',
    this.sourceApp,
    this.sourceDevice,
    this.recordingMethod = 'automatic',
    this.sourceMetadata = const {},
  });

  final DateTime date;
  final int morningSteps;
  final int afternoonSteps;
  final int nightSteps;
  final int dailySteps;
  final double activeCalories;
  final double distanceMeters;
  final double exerciseMinutes;
  final DateTime syncedAt;
  final int manualRecordsExcluded;
  final String sourcePlatform;
  final String? sourceApp;
  final String? sourceDevice;
  final String recordingMethod;
  final Map<String, dynamic> sourceMetadata;

  DailyActivityAggregate copyWith({
    int? morningSteps,
    int? afternoonSteps,
    int? nightSteps,
    int? dailySteps,
    double? activeCalories,
    double? distanceMeters,
    double? exerciseMinutes,
    DateTime? syncedAt,
  }) {
    return DailyActivityAggregate(
      date: date,
      morningSteps: morningSteps ?? this.morningSteps,
      afternoonSteps: afternoonSteps ?? this.afternoonSteps,
      nightSteps: nightSteps ?? this.nightSteps,
      dailySteps: dailySteps ?? this.dailySteps,
      activeCalories: activeCalories ?? this.activeCalories,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      exerciseMinutes: exerciseMinutes ?? this.exerciseMinutes,
      syncedAt: syncedAt ?? this.syncedAt,
      manualRecordsExcluded: manualRecordsExcluded,
      sourcePlatform: sourcePlatform,
      sourceApp: sourceApp,
      sourceDevice: sourceDevice,
      recordingMethod: recordingMethod,
      sourceMetadata: sourceMetadata,
    );
  }
}

abstract interface class HealthRepository {
  Future<bool> requestStepReadPermission();

  Future<HealthReadResult> readToday({
    required DateTime now,
    required String competitionTimezone,
  });
}

abstract interface class DailyActivitySink {
  Future<void> upsert(DailyActivityAggregate aggregate);
}
