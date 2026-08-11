import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as timezone_data;

import 'features/app/data/health_sync_bootstrap.dart';
import 'features/app/presentation/app_shell.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'shared/config/app_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(isOptional: true);
  timezone_data.initializeTimeZones();

  if (AppEnvironment.isConfigured) {
    try {
      await Supabase.initialize(
        url: AppEnvironment.supabaseUrl,
        publishableKey: AppEnvironment.supabaseAnonKey,
      );
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
      title: 'Enfermicambio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff176b87),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
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
                'App configuration missing',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Build with --dart-define=SUPABASE_URL=... and '
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
