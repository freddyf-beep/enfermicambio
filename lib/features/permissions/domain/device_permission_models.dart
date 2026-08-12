enum DevicePermissionKind { motion, location, bluetooth, notifications }

enum DevicePermissionState {
  granted,
  limited,
  provisional,
  denied,
  permanentlyDenied,
  restricted,
  unavailable,
}

class DevicePermissionSnapshot {
  const DevicePermissionSnapshot({
    required this.kind,
    required this.state,
    this.serviceEnabled = true,
    this.message,
  });

  final DevicePermissionKind kind;
  final DevicePermissionState state;
  final bool serviceEnabled;
  final String? message;

  bool get isGranted =>
      state == DevicePermissionState.granted ||
      state == DevicePermissionState.limited ||
      state == DevicePermissionState.provisional;

  bool get requiresSettings =>
      state == DevicePermissionState.permanentlyDenied ||
      state == DevicePermissionState.restricted ||
      !serviceEnabled;
}

abstract interface class DevicePermissionRepository {
  Future<List<DevicePermissionSnapshot>> readAll();

  Future<DevicePermissionSnapshot> request(DevicePermissionKind kind);

  Future<bool> openSettings();
}
