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
  String? _lastAuthorizationError;
  HealthReadStatus? _lastReadStatus;

  static const _dailyReadTypes = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.EXERCISE_TIME,
  ];

  // Health Connect exposes distance as DISTANCE_DELTA and does not expose
  // Apple's EXERCISE_TIME type. Exercise minutes are derived from workouts
  // below, so unsupported Apple-only types never block Android authorization.
  static const _androidDailyReadTypes = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
  ];

  static const _authorizationTypes = <HealthDataType>[
    ..._dailyReadTypes,
    HealthDataType.WORKOUT,
    HealthDataType.WORKOUT_ROUTE,
  ];

  List<HealthDataType> get _platformDailyReadTypes =>
      Platform.isAndroid ? _androidDailyReadTypes : _dailyReadTypes;

  List<HealthDataType> get _platformAuthorizationTypes => Platform.isAndroid
      ? [
          ..._androidDailyReadTypes,
          HealthDataType.WORKOUT,
          HealthDataType.WORKOUT_ROUTE,
        ]
      : _authorizationTypes;

  List<HealthDataAccess> get _platformAuthorizationPermissions =>
      List<HealthDataAccess>.filled(
        _platformAuthorizationTypes.length,
        HealthDataAccess.READ,
        growable: false,
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
        final hasMetricPermissions = await _health
            .hasPermissions(
              _platformDailyReadTypes,
              permissions: _platformAuthorizationPermissions.sublist(
                0,
                _platformDailyReadTypes.length,
              ),
            )
            .timeout(permissionTimeout);
        if (hasMetricPermissions != true) {
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
      final readTypes = <HealthDataType>[..._platformDailyReadTypes];
      if (Platform.isAndroid) {
        for (final type in [
          HealthDataType.WORKOUT,
          HealthDataType.WORKOUT_ROUTE,
        ]) {
          final granted = await _health
              .hasPermissions([type], permissions: [HealthDataAccess.READ])
              .timeout(permissionTimeout);
          if (granted == true) readTypes.add(type);
        }
      }
      final points = await _health
          .getHealthDataFromTypes(
            types: readTypes,
            startTime: localStart,
            endTime: localNow,
          )
          .timeout(permissionTimeout);
      final baseSamples = points
          .where((point) => _platformDailyReadTypes.contains(point.type))
          .map(_toSample)
          .toList(growable: false);
      final workouts = _toWorkouts(points);
      final samples = [
        ...baseSamples,
        for (final workout in workouts)
          HealthSample(
            type: HealthMetricType.exerciseMinutes,
            value: workout.durationSeconds / 60,
            dateFrom: workout.startedAt,
            dateTo: workout.endedAt,
            sourceApp: 'Health Connect',
            sourceDevice: 'Health Connect',
            recordingMethod: HealthRecordingMethod.automatic,
            sourceId: workout.externalId,
          ),
      ];
      return _rememberRead(
        HealthReadResult(
          status: samples.isEmpty && workouts.isEmpty
              ? HealthReadStatus.noData
              : HealthReadStatus.success,
          samples: samples,
          workouts: workouts,
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
        for (final type in _platformAuthorizationTypes) {
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
        _ when _lastAuthorizationError != null => HealthSetupState.retryable,
        _ when _authorizationRequested => HealthSetupState.requested,
        _ => HealthSetupState.available,
      };
      return HealthSetupSnapshot(
        platform: platform,
        healthAvailable: state != HealthSetupState.unavailable,
        grantedTypes: const {},
        state: state,
        message:
            _lastAuthorizationError ??
            (state == HealthSetupState.requested
                ? 'Apple Health protege el detalle de los permisos de lectura. Verificaremos el acceso con una lectura real.'
                : null),
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
  Future<bool> requestAllPermissions() => _requestPermissions(
    _platformAuthorizationTypes,
    _platformAuthorizationPermissions,
  );

  Future<bool> _requestPermissions(
    List<HealthDataType> types,
    List<HealthDataAccess> permissions,
  ) async {
    try {
      _lastAuthorizationError = null;
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
      } else if (Platform.isIOS) {
        _lastAuthorizationError =
            'Apple Health no abrió o no completó la autorización. Si ya la rechazaste, revisa Salud > tu perfil > Apps > Enfermicambio.';
      }
      return requested;
    } on TimeoutException {
      _lastAuthorizationError =
          'Apple Health tardó demasiado en responder a la autorización.';
      return false;
    } on Exception catch (error) {
      _lastAuthorizationError =
          'No se pudo solicitar Apple Health. La firma instalada debe incluir el permiso HealthKit. Detalle: $error';
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
      _ when granted.length < _platformAuthorizationTypes.length =>
        HealthSetupState.partial,
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
      HealthDataType.DISTANCE_DELTA => HealthMetricType.distance,
      HealthDataType.DISTANCE_WALKING_RUNNING => HealthMetricType.distance,
      HealthDataType.EXERCISE_TIME => HealthMetricType.exerciseMinutes,
      HealthDataType.WORKOUT => HealthMetricType.workouts,
      HealthDataType.WORKOUT_ROUTE => HealthMetricType.workoutRoutes,
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

  List<HealthWorkoutRecord> _toWorkouts(List<HealthDataPoint> points) {
    final routesByWorkout = <String, List<HealthRoutePoint>>{};
    for (final point in points.where(
      (point) => point.type == HealthDataType.WORKOUT_ROUTE,
    )) {
      final value = point.value;
      if (value is! WorkoutRouteHealthValue) continue;
      final externalId = value.workoutUuid?.trim().isNotEmpty == true
          ? value.workoutUuid!.trim()
          : point.uuid;
      if (externalId.isEmpty) continue;
      routesByWorkout[externalId] = [
        ...(routesByWorkout[externalId] ?? const []),
        ...value.locations.map(
          (location) => HealthRoutePoint(
            timestamp: location.timestamp,
            latitude: location.latitude,
            longitude: location.longitude,
            altitude: location.altitude,
            accuracy: location.horizontalAccuracy,
            bearing: location.course,
          ),
        ),
      ];
    }

    return points
        .where((point) => point.type == HealthDataType.WORKOUT)
        .map((point) {
          final value = point.value;
          final summary = point.workoutSummary;
          final workoutValue = value is WorkoutHealthValue ? value : null;
          final duration = point.dateTo.difference(point.dateFrom);
          final durationSeconds = duration.inSeconds > 0
              ? duration.inSeconds
              : 1;
          final distance = _workoutDistanceMeters(
            workoutValue?.totalDistance ?? summary?.totalDistance,
            workoutValue?.totalDistanceUnit,
          );
          final calories = _workoutCalories(
            workoutValue?.totalEnergyBurned ?? summary?.totalEnergyBurned,
            workoutValue?.totalEnergyBurnedUnit,
          );
          final externalId = point.uuid.isNotEmpty
              ? point.uuid
              : '${point.sourceId}:${point.dateFrom.toUtc().toIso8601String()}';
          return HealthWorkoutRecord(
            externalId: externalId,
            workoutType:
                (workoutValue?.workoutActivityType.name ??
                        summary?.workoutType ??
                        'workout')
                    .toLowerCase(),
            startedAt: point.dateFrom,
            endedAt: point.dateTo,
            durationSeconds: durationSeconds,
            distanceMeters: distance,
            activeCalories: calories,
            avgSpeed: distance == null ? null : distance / durationSeconds,
            routePoints: routesByWorkout[externalId] ?? const [],
          );
        })
        .toList(growable: false);
  }

  double? _workoutDistanceMeters(num? value, HealthDataUnit? unit) {
    if (value == null) return null;
    final amount = value.toDouble();
    return switch (unit) {
      HealthDataUnit.MILE => amount * 1609.344,
      HealthDataUnit.FOOT => amount * 0.3048,
      HealthDataUnit.YARD => amount * 0.9144,
      _ => amount,
    };
  }

  double? _workoutCalories(num? value, HealthDataUnit? unit) {
    if (value == null) return null;
    final amount = value.toDouble();
    return switch (unit) {
      HealthDataUnit.JOULE => amount / 4184,
      HealthDataUnit.SMALL_CALORIE => amount / 1000,
      _ => amount,
    };
  }
}
