import 'health_auto_export_setup_service.dart';

/// Read model for the private Health Auto Export audit exposed by the setup
/// function. Raw health payloads never reach the client or this repository.
class HealthIngestionRunRepository {
  const HealthIngestionRunRepository({required this.setupService});

  final HealthAutoExportSetupService setupService;

  Future<HealthIngestionRunSummary?> latestForCurrentUser() async {
    final status = await setupService.statusForCurrentUser();
    return status.latestRun;
  }
}
