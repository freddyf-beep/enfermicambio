import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/config/app_environment.dart';
import '../../../shared/ui/app_theme.dart';
import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import '../../profiles/data/supabase_profile_repository.dart';
import '../data/supabase_weight_repository.dart';
import '../domain/weight_models.dart';

/// Private weight tracker: last weight, goal, progress and history.
/// Weight is owner-only; nothing here is shared with the other users.
class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  late final SupabaseWeightRepository _repository;
  WeightEntry? _latest;
  List<WeightEntry> _history = const [];
  double? _goal;
  AsyncViewStatus? _status;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _repository = SupabaseWeightRepository(client: Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _status = null;
    });
    try {
      final userId = Supabase.instance.client.auth.currentSession?.user.id;
      final profile = userId == null
          ? null
          : await SupabaseProfileRepository(
              client: Supabase.instance.client,
            ).fetchById(userId);
      final latest = await _repository.latest();
      final history = await _repository.history(limit: 10);
      if (!mounted) return;
      setState(() {
        _latest = latest;
        _history = history;
        _goal = profile?.weightGoalKg;
        _loaded = true;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _loaded
            ? AsyncViewStatus.offline('No se pudo cargar tu peso.')
            : AsyncViewStatus.backendError(error.toString());
      });
    }
  }

  Future<void> _registerWeight() async {
    final controller = TextEditingController(
      text: _latest?.weightKg.toStringAsFixed(1) ?? '',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar mi peso'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Peso (kg)',
            border: OutlineInputBorder(),
            suffixText: 'kg',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );
              if (parsed != null) {
                Navigator.pop(context, parsed);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (value == null) return;
    if (value < 20 || value > 400) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El peso debe estar entre 20 y 400 kg.'),
          ),
        );
      }
      return;
    }
    try {
      await _repository.upsert(
        date: DateTime.parse(AppEnvironment.todayInCompetitionTz()),
        weightKg: value,
      );
      await _repository.notifyGoalIfMet();
      await _load();
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el peso.')),
        );
      }
    }
  }

  Future<void> _setGoal() async {
    final controller = TextEditingController(
      text: _goal?.toStringAsFixed(1) ?? '',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Meta de peso'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Peso objetivo (kg)',
            border: OutlineInputBorder(),
            suffixText: 'kg',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('Quitar meta'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );
              if (parsed != null) {
                Navigator.pop(context, parsed);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (value == null) return;
    if (value != 0 && (value < 20 || value > 400)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La meta debe estar entre 20 y 400 kg.'),
          ),
        );
      }
      return;
    }
    try {
      await _repository.setGoal(value == 0 ? null : value);
      await _load();
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la meta.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Peso')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (!_loaded)
              AsyncStateView(
                status: _status ?? const AsyncViewStatus.loading(),
                onRetry: _load,
                child: const SizedBox(),
              )
            else ...[
              _CurrentWeightCard(
                latest: _latest,
                goal: _goal,
                onRegister: _registerWeight,
                onSetGoal: _setGoal,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.history, size: 20, color: AppColors.primaryLight),
                  const SizedBox(width: 8),
                  Text(
                    'Historial',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_history.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Aún no hay registros. Registra tu primer peso para '
                      'empezar a ver tu evolución.',
                    ),
                  ),
                )
              else
                for (final entry in _history)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(
                        Icons.monitor_weight_outlined,
                        color: AppColors.primaryLight,
                      ),
                      title: Text(
                        '${entry.weightKg.toStringAsFixed(1)} kg',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${entry.entryDate.day}/${entry.entryDate.month}/${entry.entryDate.year}',
                      ),
                      trailing: _deltaBadge(entry),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _deltaBadge(WeightEntry entry) {
    final index = _history.indexOf(entry);
    if (index >= _history.length - 1) return null;
    final previous = _history[index + 1];
    final delta = entry.weightKg - previous.weightKg;
    if (delta.abs() < 0.1) return null;
    return Text(
      '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: delta < 0 ? AppColors.fitnessGreen : AppColors.streakOrange,
      ),
    );
  }
}

class _CurrentWeightCard extends StatelessWidget {
  const _CurrentWeightCard({
    required this.latest,
    required this.goal,
    required this.onRegister,
    required this.onSetGoal,
  });

  final WeightEntry? latest;
  final double? goal;
  final VoidCallback onRegister;
  final VoidCallback onSetGoal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Peso actual',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  latest == null ? '--' : latest!.weightKg.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                  child: Text(
                    'kg',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (goal == null)
              Text(
                'Sin meta definida. Fija un objetivo personal y celebra '
                'cuando lo alcances.',
                style: theme.textTheme.bodySmall,
              )
            else
              _GoalProgress(latest: latest, goal: goal!),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onRegister,
                    icon: const Icon(Icons.monitor_weight_outlined),
                    label: const Text('Registrar peso'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onSetGoal,
                  icon: const Icon(Icons.flag_outlined),
                  label: Text(goal == null ? 'Fijar meta' : 'Meta'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalProgress extends StatelessWidget {
  const _GoalProgress({required this.latest, required this.goal});

  final WeightEntry? latest;
  final double goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (latest == null) {
      return Text('Meta: $goal kg', style: theme.textTheme.bodyMedium);
    }
    final current = latest!.weightKg;
    final reached = current <= goal;
    if (reached) {
      return Row(
        children: [
          const Icon(Icons.celebration, color: AppColors.fitnessGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '¡Meta de $goal kg lograda!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.fitnessGreen,
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meta: $goal kg • Actual: $current kg',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: current > 0 ? (current / goal).clamp(0.0, 1.0) : 0,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: AppColors.primaryLight,
          ),
        ),
      ],
    );
  }
}
