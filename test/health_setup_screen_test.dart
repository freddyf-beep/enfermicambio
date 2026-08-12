import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/health/domain/health_models.dart';
import 'package:enfermicambio/features/health/presentation/health_connection_card.dart';
import 'package:enfermicambio/features/health/presentation/health_setup_screen.dart';

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
      MaterialApp(home: HealthSetupScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Apple Health protege el detalle del permiso.'),
      findsOneWidget,
    );
    expect(find.text('Apple protege este estado'), findsNWidgets(4));
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
      MaterialApp(home: HealthSetupScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Leer salud ahora'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Leer salud ahora'), findsOneWidget);
    expect(find.text('Sin datos visibles'), findsNWidgets(4));
    await tester.tap(find.text('Leer salud ahora'));
    await tester.pumpAndSettle();

    expect(repository.readCount, 1);
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
