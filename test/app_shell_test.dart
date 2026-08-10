import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/app/presentation/app_shell.dart';
import 'package:enfermicambio/shared/ui/async_state_view.dart';
import 'package:enfermicambio/shared/ui/async_view_status.dart';

void main() {
  testWidgets('shows the five product tabs in the navigation bar', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in ['HOY', 'RANKING', 'REGISTRAR', 'JUEGO', 'NOSOTROS']) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('switching tabs changes the visible content', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));

    expect(
      find.text(
        'Your daily summary and the four-person ranking will appear here.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('RANKING'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Today, week, and season rankings will appear here once the group '
        'syncs their activity.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('REGISTRAR'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('manual step entry'), findsOneWidget);
  });

  testWidgets('AsyncStateView renders the requested state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncStateView(
            status: const AsyncViewStatus.permissionDenied(),
            child: const SizedBox(),
          ),
        ),
      ),
    );

    expect(find.text('Permission needed'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
}
