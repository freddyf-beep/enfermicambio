import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as timezone_data;

import 'features/health/data/health_plugin_repository.dart';
import 'features/health/presentation/health_spike_screen.dart';

void main() {
  timezone_data.initializeTimeZones();
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
      home: HealthSpikeScreen(repository: HealthPluginRepository()),
    );
  }
}
