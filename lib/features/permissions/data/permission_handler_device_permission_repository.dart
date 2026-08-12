import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/device_permission_models.dart';

class PermissionHandlerDevicePermissionRepository
    implements DevicePermissionRepository {
  const PermissionHandlerDevicePermissionRepository();

  static const _kinds = <DevicePermissionKind>[
    DevicePermissionKind.motion,
    DevicePermissionKind.location,
    DevicePermissionKind.bluetooth,
    DevicePermissionKind.notifications,
  ];

  @override
  Future<List<DevicePermissionSnapshot>> readAll() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) {
      return _kinds
          .map(
            (kind) => DevicePermissionSnapshot(
              kind: kind,
              state: DevicePermissionState.unavailable,
              message: 'Este permiso solo está disponible en iOS o Android.',
            ),
          )
          .toList(growable: false);
    }

    return Future.wait(_kinds.map(_read));
  }

  @override
  Future<DevicePermissionSnapshot> request(DevicePermissionKind kind) async {
    try {
      final permissions = _permissionsFor(kind);
      if (permissions.isEmpty) {
        return DevicePermissionSnapshot(
          kind: kind,
          state: DevicePermissionState.unavailable,
        );
      }

      final results = await permissions.request();
      final state = _combinedState(results.values);
      final serviceEnabled = kind == DevicePermissionKind.location
          ? await Permission.locationWhenInUse.serviceStatus.isEnabled
          : true;
      return DevicePermissionSnapshot(
        kind: kind,
        state: state,
        serviceEnabled: serviceEnabled,
      );
    } on Exception catch (error) {
      return DevicePermissionSnapshot(
        kind: kind,
        state: DevicePermissionState.unavailable,
        message: error.toString(),
      );
    }
  }

  @override
  Future<bool> openSettings() => openAppSettings();

  Future<DevicePermissionSnapshot> _read(DevicePermissionKind kind) async {
    try {
      final permissions = _permissionsFor(kind);
      final statuses = await Future.wait(
        permissions.map((permission) => permission.status),
      );
      final serviceEnabled = kind == DevicePermissionKind.location
          ? await Permission.locationWhenInUse.serviceStatus.isEnabled
          : true;
      return DevicePermissionSnapshot(
        kind: kind,
        state: _combinedState(statuses),
        serviceEnabled: serviceEnabled,
      );
    } on Exception catch (error) {
      return DevicePermissionSnapshot(
        kind: kind,
        state: DevicePermissionState.unavailable,
        message: error.toString(),
      );
    }
  }

  List<Permission> _permissionsFor(DevicePermissionKind kind) {
    return switch (kind) {
      DevicePermissionKind.motion => [
        Platform.isIOS ? Permission.sensors : Permission.activityRecognition,
      ],
      DevicePermissionKind.location => [Permission.locationWhenInUse],
      DevicePermissionKind.bluetooth =>
        Platform.isIOS
            ? [Permission.bluetooth]
            : [Permission.bluetoothScan, Permission.bluetoothConnect],
      DevicePermissionKind.notifications => [Permission.notification],
    };
  }

  DevicePermissionState _combinedState(Iterable<PermissionStatus> statuses) {
    final values = statuses.toList(growable: false);
    if (values.isEmpty) return DevicePermissionState.unavailable;
    if (values.any((status) => status.isPermanentlyDenied)) {
      return DevicePermissionState.permanentlyDenied;
    }
    if (values.any((status) => status.isRestricted)) {
      return DevicePermissionState.restricted;
    }
    if (values.every((status) => status.isGranted)) {
      return DevicePermissionState.granted;
    }
    if (values.any((status) => status.isLimited)) {
      return DevicePermissionState.limited;
    }
    if (values.any((status) => status.isProvisional)) {
      return DevicePermissionState.provisional;
    }
    return DevicePermissionState.denied;
  }
}
