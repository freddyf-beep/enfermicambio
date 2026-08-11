import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/app/presentation/app_shell.dart';
import 'package:enfermicambio/shared/ui/async_state_view.dart';
import 'package:enfermicambio/shared/ui/async_view_status.dart';

void main() {
  Widget shellWith({required List<Widget> tabs}) {
    return MaterialApp(home: AppShell(tabs: tabs));
  }

  Widget placeholder(String label) {
    return Scaffold(body: Center(child: Text('content:$label')));
  }

  testWidgets('shows the five product tabs in the navigation bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      shellWith(
        tabs: [
          placeholder('HOY'),
          placeholder('RANKING'),
          placeholder('REGISTRAR'),
          placeholder('JUEGO'),
          placeholder('NOSOTROS'),
        ],
      ),
    );

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
    await tester.pumpWidget(
      shellWith(
        tabs: [
          placeholder('HOY'),
          placeholder('RANKING'),
          placeholder('REGISTRAR'),
          placeholder('JUEGO'),
          placeholder('NOSOTROS'),
        ],
      ),
    );

    expect(find.text('content:HOY'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('RANKING'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('content:RANKING'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('REGISTRAR'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('content:REGISTRAR'), findsOneWidget);
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
