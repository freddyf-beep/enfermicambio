import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as timezone_data;

import 'package:enfermicambio/features/health/application/health_sync_service.dart';
import 'package:enfermicambio/features/health/domain/health_models.dart';

class FakeHealthRepository implements HealthRepository {
  FakeHealthRepository(this.result);

  final HealthReadResult result;

  @override
  Future<bool> requestStepReadPermission() async => true;

  @override
  Future<HealthReadResult> readToday({
    required DateTime now,
    required String competitionTimezone,
  }) async => result;

  @override
  Future<HealthSetupSnapshot> readSetupStatus() async =>
      const HealthSetupSnapshot(
        platform: 'ios',
        healthAvailable: true,
        grantedTypes: {},
        message: null,
      );

  @override
  Future<bool> requestAllPermissions() async => true;
}

class FakeDailyActivitySink implements DailyActivitySink {
  int upsertCount = 0;

  @override
  Future<void> upsert(DailyActivityAggregate aggregate) async {
    upsertCount++;
  }
}

void main() {
  setUpAll(timezone_data.initializeTimeZones);

  test('does not upload a zero aggregate for a no-data read', () async {
    final sink = FakeDailyActivitySink();
    final service = HealthSyncService(
      repository: FakeHealthRepository(
        HealthReadResult(
          status: HealthReadStatus.noData,
          samples: const [],
          lastSyncedAt: DateTime.utc(2026, 8, 12),
          sourcePlatform: 'ios',
          message: 'No hay datos visibles.',
        ),
      ),
      sink: sink,
    );

    final result = await service.sync(now: DateTime.utc(2026, 8, 12, 15));

    expect(result.readStatus, HealthReadStatus.noData);
    expect(result.aggregate, isNull);
    expect(sink.upsertCount, 0);
  });
}
