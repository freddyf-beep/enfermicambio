import 'health_models.dart';

/// A single health permission the user can grant or revoke.
class HealthPermissionSetting {
  const HealthPermissionSetting({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    this.granted = false,
    this.supported = true,
    this.isDerived = false,
  });

  final String id;
  final String title;
  final String description;
  final HealthMetricType metric;

  /// `null` means the platform intentionally does not disclose the read
  /// permission state (currently Apple HealthKit).
  final bool? granted;
  final bool supported;

  /// True when the value is calculated from another permission rather than a
  /// platform health type (Android exercise minutes come from workouts).
  final bool isDerived;
}

/// Snapshot of all health permission state plus a platform-aware health
/// status so the UI can explain why a connection may not work.
class HealthSetupStatus {
  const HealthSetupStatus({
    required this.permissions,
    required this.platform,
    required this.healthAvailable,
    required this.message,
  });

  final List<HealthPermissionSetting> permissions;
  final String platform;
  final bool healthAvailable;
  final String? message;

  int get grantedCount =>
      permissions.where((permission) => permission.granted == true).length;
}
