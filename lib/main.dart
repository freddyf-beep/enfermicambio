import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as timezone_data;

import 'features/app/data/health_sync_bootstrap.dart';
import 'features/app/presentation/app_shell.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/notifications/data/notification_delivery_coordinator.dart';
import 'features/notifications/data/push_notification_service.dart';
import 'shared/config/app_environment.dart';
import 'shared/ui/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(isOptional: true);
  await initializeDateFormatting('es');
  timezone_data.initializeTimeZones();

  if (AppEnvironment.isFirebaseConfigured) {
    try {
      await Firebase.initializeApp(options: AppEnvironment.firebaseOptions!);
    } on Exception {
      // Firebase remains optional during the Supabase compatibility phase.
      // Auth/Firestore surfaces report their own setup error instead of
      // preventing the rest of the app from rendering.
    }
  }

  if (AppEnvironment.isConfigured) {
    try {
      await Supabase.initialize(
        url: AppEnvironment.supabaseUrl,
        publishableKey: AppEnvironment.supabaseAnonKey,
      );
      unawaited(NotificationDeliveryCoordinator.ensure().start());
      // iPhone uses Bark as the external notification bridge. Avoid starting
      // Firebase Messaging there so the UI does not report a misleading APNs
      // token error. Android keeps the native FCM registration.
      if (defaultTargetPlatform == TargetPlatform.android) {
        unawaited(PushNotificationService.ensure().start());
      }
    } on Exception {
      // A backend failure must never blank the screen; the auth gate will
      // surface an offline/error state instead.
    }
  }

  runApp(const EnfermicambioApp());
}

class EnfermicambioApp extends StatelessWidget {
  const EnfermicambioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EnfermiCambio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: AppEnvironment.isConfigured
          ? AuthGate(
              child: AppShell(onResume: HealthSyncBootstrap.syncOnResume),
            )
          : const _SetupMissingScreen(),
    );
  }
}

class _SetupMissingScreen extends StatelessWidget {
  const _SetupMissingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.settings_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                'Falta configuración de la app',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Ejecuta con --dart-define=SUPABASE_URL=... y '
                '--dart-define=SUPABASE_ANON_KEY=...',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
