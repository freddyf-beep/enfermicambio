import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enfermicambio/features/app/presentation/app_shell.dart';
import 'package:enfermicambio/shared/ui/app_theme.dart';
import 'mocks/user_mocks.dart';

void main() {
  testWidgets('Navegación de las 5 pestañas en español en el AppShell', (tester) async {
    final mockTabs = [
      Scaffold(body: Center(child: Text('Vista HOY de ${UserMocks.fourProfiles[0].displayName}'))),
      Scaffold(body: Center(child: Text('Vista RANKING del Grupo'))),
      Scaffold(body: Center(child: Text('Vista REGISTRAR Alimentos'))),
      Scaffold(body: Center(child: Text('Vista JUEGO y Puntos'))),
      Scaffold(body: Center(child: Text('Vista NOSOTROS Perfiles'))),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: AppShell(tabs: mockTabs),
      ),
    );

    // Verificar que la pestaña HOY es la inicial
    expect(find.text('Vista HOY de Freddy'), findsOneWidget);

    // Navegar a RANKING
    await tester.tap(find.text('RANKING'));
    await tester.pumpAndSettle();
    expect(find.text('Vista RANKING del Grupo'), findsOneWidget);

    // Navegar a REGISTRAR
    await tester.tap(find.text('REGISTRAR'));
    await tester.pumpAndSettle();
    expect(find.text('Vista REGISTRAR Alimentos'), findsOneWidget);

    // Navegar a JUEGO
    await tester.tap(find.text('JUEGO'));
    await tester.pumpAndSettle();
    expect(find.text('Vista JUEGO y Puntos'), findsOneWidget);

    // Navegar a NOSOTROS
    await tester.tap(find.text('NOSOTROS'));
    await tester.pumpAndSettle();
    expect(find.text('Vista NOSOTROS Perfiles'), findsOneWidget);
  });
}
