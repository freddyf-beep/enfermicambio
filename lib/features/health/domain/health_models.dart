enum HealthRecordingMethod { unknown, active, automatic, manual }

enum HealthReadStatus {
  success,
  noData,
  permissionDenied,
  sourceUnavailable,
  backendUnavailable,
  retryableFailure,
}

enum HealthMetricType {
  steps,
  activeCalories,
  distance,
  exerciseMinutes,
  workouts,
  workoutRoutes,
}

/// The state the setup UI can honestly communicate across HealthKit and
/// Health Connect. iOS deliberately keeps read permission status private, so
/// a requested iOS permission is verified by attempting a real read instead of
/// being rendered as denied.
enum HealthSetupState {
  available,
  unavailable,
  notGranted,
  partial,
  requested,
  connected,
  noData,
  retryable,
}

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
    this.workouts = const [],
  });

  final HealthReadStatus status;
  final List<HealthSample> samples;
  final DateTime lastSyncedAt;
  final String sourcePlatform;
  final String? message;
  final List<HealthWorkoutRecord> workouts;
}

/// A workout read from Apple Health/Health Connect. It stays independent from
/// the persistence model until Supabase assigns the database UUID.
class HealthWorkoutRecord {
  const HealthWorkoutRecord({
    required this.externalId,
    required this.workoutType,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    this.distanceMeters,
    this.activeCalories,
    this.avgSpeed,
    this.routePoints = const [],
  });

  final String externalId;
  final String workoutType;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final double? distanceMeters;
  final double? activeCalories;
  final double? avgSpeed;
  final List<HealthRoutePoint> routePoints;
}

class HealthRoutePoint {
  const HealthRoutePoint({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.bearing,
  });

  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? bearing;
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
  Future<HealthReadResult> readToday({
    required DateTime now,
    required String competitionTimezone,
  });

  /// Platform identity and whether the underlying health service is usable.
  /// [message] explains why a connection may fail (missing Health Connect app,
  /// simulator, unsupported platform, etc.).
  Future<HealthSetupSnapshot> readSetupStatus();

  /// Requests all read permissions the app supports in one flow.
  Future<bool> requestAllPermissions();
}

/// Platform-level health availability and permission state.
class HealthSetupSnapshot {
  const HealthSetupSnapshot({
    required this.platform,
    required this.healthAvailable,
    required this.grantedTypes,
    required this.message,
    HealthSetupState? state,
  }) : state =
           state ??
           (healthAvailable
               ? HealthSetupState.available
               : HealthSetupState.unavailable);

  final String platform;
  final bool healthAvailable;
  final Set<HealthMetricType> grantedTypes;
  final String? message;
  final HealthSetupState state;
}

abstract interface class DailyActivitySink {
  Future<void> upsert(DailyActivityAggregate aggregate);
}
