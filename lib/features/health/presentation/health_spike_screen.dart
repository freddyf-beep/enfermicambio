import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/config/app_config.dart';
import '../application/health_sync_service.dart';
import '../data/in_memory_activity_sink.dart';
import '../domain/health_models.dart';

class HealthSpikeScreen extends StatefulWidget {
  const HealthSpikeScreen({required this.repository, super.key});

  final HealthRepository repository;

  @override
  State<HealthSpikeScreen> createState() => _HealthSpikeScreenState();
}

class _HealthSpikeScreenState extends State<HealthSpikeScreen> {
  final _config = const AppConfig.defaults();
  final _sink = InMemoryActivitySink();
  late final HealthSyncService _syncService;
  HealthSyncResult? _result;
  bool _isBusy = false;
  String? _permissionMessage;

  @override
  void initState() {
    super.initState();
    _syncService = HealthSyncService(
      repository: widget.repository,
      sink: _sink,
      config: _config,
    );
  }

  @override
  Widget build(BuildContext context) {
    final aggregate = _result?.aggregate;
    return Scaffold(
      appBar: AppBar(title: const Text('Enfermicambio')),
      body: RefreshIndicator(
        onRefresh: _sync,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Phase 0 health spike',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Automatic steps only. Competition timezone: '
              '${_config.competitionTimezone}.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isBusy ? null : _requestPermission,
              icon: const Icon(Icons.health_and_safety_outlined),
              label: const Text('Connect health source'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isBusy ? null : _sync,
              icon: const Icon(Icons.sync),
              label: const Text('Sync today'),
            ),
            if (_isBusy) ...[
              const SizedBox(height: 20),
              const LinearProgressIndicator(),
            ],
            if (_permissionMessage != null) ...[
              const SizedBox(height: 20),
              _StatusPanel(
                title: 'Permission state',
                message: _permissionMessage!,
                icon: Icons.lock_outline,
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 20),
              _ResultPanel(result: _result!, aggregate: aggregate),
            ],
            const SizedBox(height: 20),
            const _StatusPanel(
              title: 'Validation status',
              message:
                  'Physical iPhone and Android evidence, platform totals, '
                  'and Supabase persistence are still required before Phase 0 '
                  'can pass.',
              icon: Icons.fact_check_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isBusy = true;
      _permissionMessage = null;
    });
    final granted = await widget.repository.requestStepReadPermission();
    if (!mounted) {
      return;
    }
    setState(() {
      _isBusy = false;
      _permissionMessage = granted
          ? 'Step read permission granted by the platform.'
          : 'Step read permission was denied or unavailable.';
    });
  }

  Future<void> _sync() async {
    setState(() {
      _isBusy = true;
      _permissionMessage = null;
    });
    final result = await _syncService.sync();
    if (!mounted) {
      return;
    }
    setState(() {
      _isBusy = false;
      _result = result;
    });
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result, required this.aggregate});

  final HealthSyncResult result;
  final DailyActivityAggregate? aggregate;

  @override
  Widget build(BuildContext context) {
    final title = switch (result.readStatus) {
      HealthReadStatus.success => 'Sync complete',
      HealthReadStatus.noData => 'No health data',
      _ => 'Sync unavailable',
    };
    final message = aggregate == null
        ? (result.message ?? 'No aggregate was written.')
        : 'Last synced ${DateFormat.Hm().format(aggregate!.syncedAt.toLocal())}.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(message),
            if (aggregate != null) ...[
              const SizedBox(height: 16),
              _MetricRow(label: 'Morning', value: aggregate!.morningSteps),
              _MetricRow(label: 'Afternoon', value: aggregate!.afternoonSteps),
              _MetricRow(label: 'Night', value: aggregate!.nightSteps),
              const Divider(),
              _MetricRow(label: 'Today', value: aggregate!.dailySteps),
              Text(
                '${aggregate!.manualRecordsExcluded} manual record(s) excluded',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            NumberFormat.decimalPattern().format(value),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
