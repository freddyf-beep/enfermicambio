import 'package:supabase_flutter/supabase_flutter.dart';

class HealthAutoExportSetup {
  const HealthAutoExportSetup({
    required this.tokenPrefix,
    required this.metricsLink,
    required this.workoutsLink,
  });

  final String tokenPrefix;
  final Uri metricsLink;
  final Uri workoutsLink;

  String get shareableFileName => 'enfermicambio-health-auto-export.html';

  String get shareableFileText =>
      '''<!doctype html>
<html lang="es">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>EnfermiCambio · Health Auto Export</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 24px; line-height: 1.45; }
  a { display: block; padding: 16px; margin: 12px 0; border-radius: 12px; background: #d7ff00; color: #111; font-weight: 700; text-decoration: none; }
  .warning { color: #8a1c1c; font-weight: 600; }
</style>
<h1>EnfermiCambio</h1>
<p>Instalador de las automatizaciones privadas de Health Auto Export para esta cuenta.</p>
<p class="warning">No compartas este archivo con otra persona: contiene credenciales privadas.</p>
<a href="${metricsLink.toString()}" target="_blank">1. Instalar métricas de Salud</a>
<a href="${workoutsLink.toString()}" target="_blank">2. Instalar entrenamientos y rutas</a>
<h2>Después de abrir cada enlace</h2>
<ol>
  <li>Concede los permisos de Apple Salud.</li>
  <li>Revisa la automatización y pulsa Actualizar.</li>
  <li>Ejecuta una prueba manual la primera vez.</li>
</ol>
<p>Este archivo se abre en Safari. No lo uses en “Importar automatización”: esa opción requiere el JSON propio exportado por Health Auto Export.</p>
</html>
''';

  factory HealthAutoExportSetup.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics_link'];
    final workouts = json['workouts_link'];
    if (metrics is! String || workouts is! String) {
      throw const FormatException(
        'La configuración de Health Auto Export está incompleta.',
      );
    }
    return HealthAutoExportSetup(
      tokenPrefix: json['token_prefix'] as String? ?? '',
      metricsLink: Uri.parse(metrics),
      workoutsLink: Uri.parse(workouts),
    );
  }
}

class HealthAutoExportSetupService {
  const HealthAutoExportSetupService({required this._client});

  final SupabaseClient _client;

  Future<HealthAutoExportSetup> prepareForCurrentUser() async {
    final response = await _client.functions.invoke(
      'health_auto_export_setup',
      body: const {},
    );
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('El servidor no devolvió la configuración.');
    }
    return HealthAutoExportSetup.fromJson(Map<String, dynamic>.from(data));
  }
}
