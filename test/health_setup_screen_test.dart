import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/health/domain/health_models.dart';
import 'package:enfermicambio/features/health/presentation/health_connection_card.dart';
import 'package:enfermicambio/features/health/presentation/health_setup_screen.dart';
import 'package:enfermicambio/features/permissions/domain/device_permission_models.dart';

class FakeHealthRepository implements HealthRepository {
  FakeHealthRepository(this.snapshot, {this.readResult});

  HealthSetupSnapshot snapshot;
  HealthReadResult? readResult;
  int requestCount = 0;
  int readCount = 0;

  @override
  Future<bool> requestStepReadPermission() async => true;

  @override
  Future<HealthReadResult> readToday({
    required DateTime now,
    required String competitionTimezone,
  }) async {
    readCount++;
    return readResult ??
        HealthReadResult(
          status: HealthReadStatus.noData,
          samples: [],
          lastSyncedAt: DateTime.utc(2026, 1, 1),
        );
  }

  @override
  Future<HealthSetupSnapshot> readSetupStatus() async => snapshot;

  @override
  Future<bool> requestAllPermissions() async {
    requestCount++;
    return true;
  }
}

class FakeDevicePermissionRepository implements DevicePermissionRepository {
  FakeDevicePermissionRepository({
    this.snapshots = const [
      DevicePermissionSnapshot(
        kind: DevicePermissionKind.motion,
        state: DevicePermissionState.denied,
      ),
      DevicePermissionSnapshot(
        kind: DevicePermissionKind.location,
        state: DevicePermissionState.denied,
      ),
      DevicePermissionSnapshot(
        kind: DevicePermissionKind.bluetooth,
        state: DevicePermissionState.denied,
      ),
      DevicePermissionSnapshot(
        kind: DevicePermissionKind.notifications,
        state: DevicePermissionState.denied,
      ),
    ],
  });

  List<DevicePermissionSnapshot> snapshots;
  final List<DevicePermissionKind> requested = [];

  @override
  Future<List<DevicePermissionSnapshot>> readAll() async => snapshots;

  @override
  Future<DevicePermissionSnapshot> request(DevicePermissionKind kind) async {
    requested.add(kind);
    final result = DevicePermissionSnapshot(
      kind: kind,
      state: DevicePermissionState.granted,
    );
    snapshots = [
      for (final snapshot in snapshots)
        if (snapshot.kind != kind) snapshot,
      result,
    ];
    return result;
  }

  @override
  Future<bool> openSettings() async => true;
}

void main() {
  testWidgets('does not show iOS read permission as denied', (tester) async {
    final repository = FakeHealthRepository(
      const HealthSetupSnapshot(
        platform: 'ios',
        healthAvailable: true,
        grantedTypes: {},
        state: HealthSetupState.requested,
        message: 'Apple Health protege el detalle del permiso.',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HealthSetupScreen(
          repository: repository,
          devicePermissionRepository: FakeDevicePermissionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Apple Health protege el detalle del permiso.'),
      findsOneWidget,
    );
    expect(find.text('Apple protege este estado'), findsNWidgets(6));
    expect(find.text('No concedido'), findsNothing);
  });

  testWidgets('shows a connected no-data state and reads again', (
    tester,
  ) async {
    final repository = FakeHealthRepository(
      const HealthSetupSnapshot(
        platform: 'ios',
        healthAvailable: true,
        grantedTypes: {},
        state: HealthSetupState.noData,
        message: null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HealthSetupScreen(
          repository: repository,
          devicePermissionRepository: FakeDevicePermissionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin datos visibles'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Leer salud ahora'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.ensureVisible(find.text('Leer salud ahora'));
    await tester.pumpAndSettle();
    expect(find.text('Leer salud ahora'), findsOneWidget);
    await tester.tap(find.text('Leer salud ahora'));
    await tester.pumpAndSettle();

    expect(repository.readCount, 1);
  });

  testWidgets('requests motion, location, Bluetooth and notifications', (
    tester,
  ) async {
    final devicePermissions = FakeDevicePermissionRepository();
    final repository = FakeHealthRepository(
      const HealthSetupSnapshot(
        platform: 'ios',
        healthAvailable: true,
        grantedTypes: {},
        state: HealthSetupState.available,
        message: null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HealthSetupScreen(
          repository: repository,
          devicePermissionRepository: devicePermissions,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Activar permisos de entrenamiento'),
      400,
      scrollable: find.byType(Scrollable),
    );
    await tester.ensureVisible(find.text('Activar permisos de entrenamiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activar permisos de entrenamiento'));
    await tester.pumpAndSettle();

    expect(devicePermissions.requested, DevicePermissionKind.values);
    expect(find.text('Concedido'), findsNWidgets(4));
  });

  testWidgets('health connection card exposes an explicit action', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HealthConnectionCard(onConnect: () => tapped = true),
        ),
      ),
    );

    await tester.tap(find.text('Conectar salud'));
    expect(tapped, isTrue);
  });
}
