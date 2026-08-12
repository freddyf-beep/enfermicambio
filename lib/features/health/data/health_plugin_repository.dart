import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
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
  bool _authorizationRequested = false;
  HealthReadStatus? _lastReadStatus;

  static const _readTypes = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.EXERCISE_TIME,
  ];

  static const _readPermissions = <HealthDataAccess>[
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  @override
  Future<bool> requestStepReadPermission() => _requestPermissions(
    _readTypes.sublist(0, 1),
    _readPermissions.sublist(0, 1),
  );

  @override
  Future<HealthReadResult> readToday({
    required DateTime now,
    required String competitionTimezone,
  }) async {
    try {
      await _configure();
      if (Platform.isAndroid) {
        final available = await _health.getHealthConnectSdkStatus().timeout(
          permissionTimeout,
        );
        if (available != HealthConnectSdkStatus.sdkAvailable) {
          return _rememberRead(
            HealthReadResult(
              status: HealthReadStatus.sourceUnavailable,
              samples: const [],
              lastSyncedAt: DateTime.now().toUtc(),
              sourcePlatform: _platformName,
              message: 'Health Connect no está disponible en este dispositivo.',
            ),
          );
        }
        final hasPermissions = await _health
            .hasPermissions(_readTypes, permissions: _readPermissions)
            .timeout(permissionTimeout);
        if (hasPermissions == false) {
          return _rememberRead(
            HealthReadResult(
              status: HealthReadStatus.permissionDenied,
              samples: const [],
              lastSyncedAt: DateTime.now().toUtc(),
              sourcePlatform: _platformName,
              message: 'Faltan permisos de lectura en Health Connect.',
            ),
          );
        }
      }

      final location = timezone.getLocation(competitionTimezone);
      final localNow = timezone.TZDateTime.from(now.toUtc(), location);
      final localStart = timezone.TZDateTime(
        location,
        localNow.year,
        localNow.month,
        localNow.day,
      );
      final points = await _health
          .getHealthDataFromTypes(
            types: _readTypes,
            startTime: localStart,
            endTime: localNow,
          )
          .timeout(permissionTimeout);
      final samples = points.map(_toSample).toList(growable: false);
      return _rememberRead(
        HealthReadResult(
          status: samples.isEmpty
              ? HealthReadStatus.noData
              : HealthReadStatus.success,
          samples: samples,
          lastSyncedAt: DateTime.now().toUtc(),
          sourcePlatform: _platformName,
          message: null,
        ),
      );
    } on HealthException catch (error) {
      return _rememberRead(
        HealthReadResult(
          status: HealthReadStatus.sourceUnavailable,
          samples: const [],
          lastSyncedAt: DateTime.now().toUtc(),
          sourcePlatform: _platformName,
          message: error.toString(),
        ),
      );
    } on TimeoutException catch (error) {
      return _rememberRead(
        HealthReadResult(
          status: HealthReadStatus.retryableFailure,
          samples: const [],
          lastSyncedAt: DateTime.now().toUtc(),
          sourcePlatform: _platformName,
          message: 'La lectura de salud tardó demasiado: $error',
        ),
      );
    } on Exception catch (error) {
      return _rememberRead(
        HealthReadResult(
          status: HealthReadStatus.retryableFailure,
          samples: const [],
          lastSyncedAt: DateTime.now().toUtc(),
          sourcePlatform: _platformName,
          message: error.toString(),
        ),
      );
    }
  }

  @override
  Future<HealthSetupSnapshot> readSetupStatus() async {
    final platform = _platformName;
    try {
      await _configure();
      if (Platform.isAndroid) {
        final available = await _health.getHealthConnectSdkStatus().timeout(
          permissionTimeout,
        );
        if (available != HealthConnectSdkStatus.sdkAvailable) {
          return HealthSetupSnapshot(
            platform: platform,
            healthAvailable: false,
            grantedTypes: const {},
            state: HealthSetupState.unavailable,
            message:
                'Health Connect no está disponible. Instálalo o actívalo en este dispositivo.',
          );
        }

        final granted = <HealthMetricType>{};
        for (final type in _readTypes) {
          final has = await _health
              .hasPermissions([type], permissions: [HealthDataAccess.READ])
              .timeout(permissionTimeout);
          if (has == true) {
            granted.add(_mapType(type));
          }
        }
        return HealthSetupSnapshot(
          platform: platform,
          healthAvailable: true,
          grantedTypes: granted,
          state: _androidSetupState(granted),
          message: null,
        );
      }

      // HealthKit intentionally returns null for read permission checks. The
      // only trustworthy signal is a real read after the authorization sheet.
      final state = switch (_lastReadStatus) {
        HealthReadStatus.success => HealthSetupState.connected,
        HealthReadStatus.noData => HealthSetupState.noData,
        HealthReadStatus.sourceUnavailable => HealthSetupState.unavailable,
        HealthReadStatus.retryableFailure => HealthSetupState.retryable,
        _ when _authorizationRequested => HealthSetupState.requested,
        _ => HealthSetupState.available,
      };
      return HealthSetupSnapshot(
        platform: platform,
        healthAvailable: state != HealthSetupState.unavailable,
        grantedTypes: const {},
        state: state,
        message: state == HealthSetupState.requested
            ? 'Apple Health protege el detalle de los permisos de lectura. Verificaremos el acceso con una lectura real.'
            : null,
      );
    } on TimeoutException catch (error) {
      return HealthSetupSnapshot(
        platform: platform,
        healthAvailable: false,
        grantedTypes: const {},
        state: HealthSetupState.retryable,
        message: 'La comprobación de salud tardó demasiado: $error',
      );
    } on Exception catch (error) {
      return HealthSetupSnapshot(
        platform: platform,
        healthAvailable: false,
        grantedTypes: const {},
        state: HealthSetupState.unavailable,
        message: error.toString(),
      );
    }
  }

  @override
  Future<bool> requestAllPermissions() =>
      _requestPermissions(_readTypes, _readPermissions);

  Future<bool> _requestPermissions(
    List<HealthDataType> types,
    List<HealthDataAccess> permissions,
  ) async {
    try {
      await _configure();
      if (Platform.isAndroid) {
        final activityStatus = await Permission.activityRecognition.request();
        if (!activityStatus.isGranted) {
          return false;
        }
        final available = await _health.getHealthConnectSdkStatus().timeout(
          permissionTimeout,
        );
        if (available != HealthConnectSdkStatus.sdkAvailable) {
          return false;
        }
      }
      final requested = await _health
          .requestAuthorization(types, permissions: permissions)
          .timeout(permissionTimeout);
      if (requested) {
        _authorizationRequested = true;
      }
      return requested;
    } on TimeoutException {
      return false;
    } on Exception catch (error) {
      debugPrint('Health permission request failed: $error');
      return false;
    }
  }

  HealthSetupState _androidSetupState(Set<HealthMetricType> granted) {
    return switch (_lastReadStatus) {
      HealthReadStatus.success => HealthSetupState.connected,
      HealthReadStatus.noData => HealthSetupState.noData,
      HealthReadStatus.sourceUnavailable => HealthSetupState.unavailable,
      HealthReadStatus.retryableFailure => HealthSetupState.retryable,
      _ when granted.isEmpty => HealthSetupState.notGranted,
      _ when granted.length < _readTypes.length => HealthSetupState.partial,
      _ => HealthSetupState.available,
    };
  }

  HealthReadResult _rememberRead(HealthReadResult result) {
    _lastReadStatus = result.status;
    return result;
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
