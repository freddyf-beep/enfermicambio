import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/health/data/health_auto_export_setup_service.dart';

void main() {
  test('parses the latest bridge reception status', () {
    final status = HealthAutoExportStatus.fromJson({
      'configured': true,
      'token_prefix': 'abc123456789',
      'last_received_at': '2026-08-13T15:45:15.480Z',
      'latest_activity_date': '2026-08-13',
      'latest_daily_steps': 56,
    });

    expect(status.configured, isTrue);
    expect(status.tokenPrefix, 'abc123456789');
    expect(status.lastReceivedAt, isNotNull);
    expect(status.latestDailySteps, 56);
  });

  test('parses the two Health Auto Export deep links', () {
    final setup = HealthAutoExportSetup.fromJson({
      'token_prefix': 'abc123456789',
      'metrics_link': 'com.HealthExport://automation?datatype=healthMetrics',
      'workouts_link': 'com.HealthExport://automation?datatype=workouts',
    });

    expect(setup.tokenPrefix, 'abc123456789');
    expect(setup.metricsLink.scheme.toLowerCase(), 'com.healthexport');
    expect(setup.workoutsLink.queryParameters['datatype'], 'workouts');
  });

  test('rejects an incomplete setup response', () {
    expect(
      () => HealthAutoExportSetup.fromJson(const {}),
      throwsFormatException,
    );
  });

  test('builds a shareable file containing both private deep links', () {
    final setup = HealthAutoExportSetup.fromJson({
      'token_prefix': 'abc123456789',
      'metrics_link': 'com.HealthExport://automation?datatype=healthMetrics',
      'workouts_link': 'com.HealthExport://automation?datatype=workouts',
    });

    expect(setup.shareableFileName, 'enfermicambio-health-auto-export.html');
    expect(setup.shareableFileText, contains(setup.metricsLink.toString()));
    expect(setup.shareableFileText, contains(setup.workoutsLink.toString()));
    expect(setup.shareableFileText, contains('No compartas este archivo'));
    expect(setup.shareableFileText, contains('No lo uses en'));
  });
}
