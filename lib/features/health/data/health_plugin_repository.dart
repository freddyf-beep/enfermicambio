import 'dart:async';

import 'package:health/health.dart';
import 'package:timezone/timezone.dart' as timezone;

import '../domain/health_models.dart';

class HealthPluginRepository implements HealthRepository {
  HealthPluginRepository({
    Health? health,
    this.permissionTimeout = const Duration(seconds: 20),
  }) : _health = health ?? Health();

  final Health _health;
  final Duration permissionTimeout;
  bool _configured = false;

  static const _readTypes = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.EXERCISE_TIME,
  ];
  @override
  Future<bool> requestStepReadPermission() async {
    try {
      await _configure();
      return await _health
          .requestAuthorization(
            const [
              HealthDataType.STEPS,
              HealthDataType.ACTIVE_ENERGY_BURNED,
              HealthDataType.DISTANCE_WALKING_RUNNING,
              HealthDataType.EXERCISE_TIME,
            ],
            permissions: const [HealthDataAccess.READ],
          )
          .timeout(permissionTimeout);
    } on TimeoutException {
      return false;
    } on Exception {
      return false;
    }
  }

  @override
  Future<HealthReadResult> readToday({
    required DateTime now,
    required String competitionTimezone,
  }) async {
    await _configure();
    final location = timezone.getLocation(competitionTimezone);
    final localNow = timezone.TZDateTime.from(now.toUtc(), location);
    final localStart = timezone.TZDateTime(
      location,
      localNow.year,
      localNow.month,
      localNow.day,
    );
    try {
      final points = await _health.getHealthDataFromTypes(
        types: _readTypes,
        startTime: localStart,
        endTime: localNow,
      );
      final samples = points.map(_toSample).toList(growable: false);
      return HealthReadResult(
        status: samples.isEmpty
            ? HealthReadStatus.noData
            : HealthReadStatus.success,
        samples: samples,
        lastSyncedAt: DateTime.now().toUtc(),
        sourcePlatform: _platformName,
      );
    } on HealthException catch (error) {
      return HealthReadResult(
        status: HealthReadStatus.sourceUnavailable,
        samples: const [],
        lastSyncedAt: DateTime.now().toUtc(),
        sourcePlatform: _platformName,
        message: error.toString(),
      );
    } on Exception catch (error) {
      return HealthReadResult(
        status: HealthReadStatus.retryableFailure,
        samples: const [],
        lastSyncedAt: DateTime.now().toUtc(),
        sourcePlatform: _platformName,
        message: error.toString(),
      );
    }
  }

  @override
  Future<HealthSetupSnapshot> readSetupStatus() async {
    final platform = _platformName;
    try {
      await _configure();
      final granted = <HealthMetricType>{};
      for (final type in _readTypes) {
        final has = await _health
            .hasPermissions([type])
            .timeout(permissionTimeout);
        if (has == true) {
          granted.add(_mapType(type));
        }
      }
      return HealthSetupSnapshot(
        platform: platform,
        healthAvailable: true,
        grantedTypes: granted,
        message: null,
      );
    } on TimeoutException catch (error) {
      return HealthSetupSnapshot(
        platform: platform,
        healthAvailable: false,
        grantedTypes: const {},
        message: 'Timed out waiting for the health service: $error',
      );
    } on Exception catch (error) {
      return HealthSetupSnapshot(
        platform: platform,
        healthAvailable: false,
        grantedTypes: const {},
        message: error.toString(),
      );
    }
  }

  @override
  Future<bool> requestAllPermissions() async {
    try {
      await _configure();
      return await _health
          .requestAuthorization(
            _readTypes,
            permissions: const [HealthDataAccess.READ],
          )
          .timeout(permissionTimeout);
    } on TimeoutException {
      return false;
    } on Exception {
      return false;
    }
  }

  Future<void> _configure() async {
    if (_configured) {
      return;
    }
    await _health.configure().timeout(permissionTimeout);
    _configured = true;
  }

  String get _platformName {
    return switch (_health.platformType) {
      HealthPlatformType.appleHealth => 'ios',
      HealthPlatformType.googleHealthConnect => 'android',
    };
  }

  HealthMetricType _mapType(HealthDataType type) {
    return switch (type) {
      HealthDataType.STEPS => HealthMetricType.steps,
      HealthDataType.ACTIVE_ENERGY_BURNED => HealthMetricType.activeCalories,
      HealthDataType.DISTANCE_WALKING_RUNNING => HealthMetricType.distance,
      HealthDataType.EXERCISE_TIME => HealthMetricType.exerciseMinutes,
      _ => HealthMetricType.steps,
    };
  }

  HealthSample _toSample(HealthDataPoint point) {
    final value = point.value;
    final numericValue = value is NumericHealthValue ? value.numericValue : 0;
    return HealthSample(
      type: _mapType(point.type),
      value: numericValue.toDouble(),
      dateFrom: point.dateFrom,
      dateTo: point.dateTo,
      sourceApp: point.sourceName,
      sourceDevice: point.deviceModel ?? point.sourceDeviceId,
      sourceId: point.sourceId,
      recordingMethod: switch (point.recordingMethod) {
        RecordingMethod.active => HealthRecordingMethod.active,
        RecordingMethod.automatic => HealthRecordingMethod.automatic,
        RecordingMethod.manual => HealthRecordingMethod.manual,
        RecordingMethod.unknown => HealthRecordingMethod.unknown,
      },
    );
  }
}
