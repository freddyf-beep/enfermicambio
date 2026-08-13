import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/app_theme.dart';
import '../data/supabase_nutrition_profile_repository.dart';
import '../domain/nutrition_profile.dart';

class CaloriePlanScreen extends StatefulWidget {
  const CaloriePlanScreen({super.key});

  @override
  State<CaloriePlanScreen> createState() => _CaloriePlanScreenState();
}

class _CaloriePlanScreenState extends State<CaloriePlanScreen> {
  late final SupabaseNutritionProfileRepository _repository;
  final _height = TextEditingController();
  final _manualTarget = TextEditingController();
  DateTime? _birthDate;
  FormulaSex? _sex;
  ActivityLevel _activity = ActivityLevel.moderate;
  NutritionGoal _goal = NutritionGoal.maintain;
  double _deficit = 15;
  double? _weightKg;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = SupabaseNutritionProfileRepository(
      client: Supabase.instance.client,
    );
    _load();
  }

  @override
  void dispose() {
    _height.dispose();
    _manualTarget.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repository.load(),
        _repository.latestWeightKg(),
      ]);
      final profile = results[0] as NutritionProfile?;
      if (!mounted) return;
      setState(() {
        _weightKg = results[1] as double?;
        if (profile != null) {
          _birthDate = profile.birthDate;
          _height.text = profile.heightCm?.toStringAsFixed(1) ?? '';
          _manualTarget.text = profile.manualCalorieTarget?.toString() ?? '';
          _sex = profile.sexForFormula;
          _activity = profile.activityLevel;
          _goal = profile.goal;
          _deficit = profile.deficitPercent;
        }
        _loading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cargar el plan nutricional: $error'),
        ),
      );
    }
  }

  NutritionProfile get _profile => NutritionProfile(
    userId: Supabase.instance.client.auth.currentUser?.id ?? '',
    birthDate: _birthDate,
    heightCm: double.tryParse(_height.text.trim().replaceAll(',', '.')),
    sexForFormula: _sex,
    activityLevel: _activity,
    goal: _goal,
    deficitPercent: _deficit,
    manualCalorieTarget: int.tryParse(_manualTarget.text.trim()),
  );

  CaloriePlan get _plan =>
      const CaloriePlanner().calculate(profile: _profile, weightKg: _weightKg);

  Future<void> _chooseBirthDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(today.year - 25),
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year - 18, today.month, today.day),
    );
    if (selected != null && mounted) setState(() => _birthDate = selected);
  }

  Future<void> _save() async {
    final profile = _profile;
    if (profile.heightCm != null &&
        (profile.heightCm! < 100 || profile.heightCm! > 250)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La altura debe estar entre 100 y 250 cm.'),
        ),
      );
      return;
    }
    if (profile.manualCalorieTarget != null &&
        (profile.manualCalorieTarget! < 800 ||
            profile.manualCalorieTarget! > 10000)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La meta manual debe estar entre 800 y 10.000 kcal.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await _repository.save(profile);
      final plan = const CaloriePlanner().calculate(
        profile: saved,
        weightKg: _weightKg,
      );
      if (plan.target != null) {
        await _repository.saveCalculatedDailyTarget(plan.target!);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            plan.target == null
                ? 'Perfil guardado. Puedes definir una meta manual mientras faltan datos.'
                : 'Meta diaria actualizada: ${plan.target} kcal.',
          ),
        ),
      );
      Navigator.pop(context);
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el perfil: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(title: const Text('Plan de calorías')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PlanCard(plan: plan, weightKg: _weightKg),
                const SizedBox(height: 16),
                Text(
                  'Datos para calcular',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Peso actual'),
                        subtitle: Text(
                          _weightKg == null
                              ? 'Regístralo en “Mi peso” para calcular la meta.'
                              : '${_weightKg!.toStringAsFixed(1)} kg',
                        ),
                        leading: const Icon(
                          Icons.monitor_weight_outlined,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      ListTile(
                        onTap: _chooseBirthDate,
                        title: const Text('Fecha de nacimiento'),
                        subtitle: Text(
                          _birthDate == null
                              ? 'Obligatoria para el cálculo'
                              : '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}',
                        ),
                        trailing: const Icon(Icons.calendar_today_outlined),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: TextField(
                          controller: _height,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Altura (cm)',
                            border: OutlineInputBorder(),
                            suffixText: 'cm',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Preferencias',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        DropdownButtonFormField<FormulaSex?>(
                          initialValue: _sex,
                          decoration: const InputDecoration(
                            labelText: 'Sexo para la ecuación (opcional)',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: null,
                              child: Text('Prefiero no indicarlo'),
                            ),
                            DropdownMenuItem(
                              value: FormulaSex.female,
                              child: Text('Femenino'),
                            ),
                            DropdownMenuItem(
                              value: FormulaSex.male,
                              child: Text('Masculino'),
                            ),
                          ],
                          onChanged: (value) => setState(() => _sex = value),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<ActivityLevel>(
                          initialValue: _activity,
                          decoration: const InputDecoration(
                            labelText: 'Nivel de actividad',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: ActivityLevel.sedentary,
                              child: Text('Sedentario'),
                            ),
                            DropdownMenuItem(
                              value: ActivityLevel.light,
                              child: Text('Ligero'),
                            ),
                            DropdownMenuItem(
                              value: ActivityLevel.moderate,
                              child: Text('Moderado'),
                            ),
                            DropdownMenuItem(
                              value: ActivityLevel.active,
                              child: Text('Activo'),
                            ),
                            DropdownMenuItem(
                              value: ActivityLevel.veryActive,
                              child: Text('Muy activo'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _activity = value!),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<NutritionGoal>(
                          initialValue: _goal,
                          decoration: const InputDecoration(
                            labelText: 'Objetivo',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: NutritionGoal.maintain,
                              child: Text('Mantener peso'),
                            ),
                            DropdownMenuItem(
                              value: NutritionGoal.lose,
                              child: Text('Perder peso'),
                            ),
                            DropdownMenuItem(
                              value: NutritionGoal.gain,
                              child: Text('Ganar peso'),
                            ),
                          ],
                          onChanged: (value) => setState(() => _goal = value!),
                        ),
                        if (_goal == NutritionGoal.lose) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Déficit inicial: ${_deficit.round()}%',
                                ),
                              ),
                              SizedBox(
                                width: 180,
                                child: Slider(
                                  value: _deficit,
                                  min: 5,
                                  max: 30,
                                  divisions: 25,
                                  onChanged: (value) =>
                                      setState(() => _deficit = value),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Meta manual (opcional)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _manualTarget,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'kcal por día',
                    hintText: 'Úsala si no quieres el cálculo',
                    border: OutlineInputBorder(),
                    suffixText: 'kcal',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Estimación orientativa para adultos, no consejo médico. “Presupuesto restante” no equivale a un déficit metabólico real.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Guardando…' : 'Guardar plan'),
                ),
              ],
            ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.weightKg});
  final CaloriePlan plan;
  final double? weightKg;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.primaryLight.withValues(alpha: 0.10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: plan.target == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aún no se puede calcular',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text('Falta: ${plan.missingInputs.join(', ')}.'),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${plan.target} kcal/día',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  plan.isManual
                      ? 'Meta manual elegida por ti.'
                      : 'BMR ${plan.bmr!.round()} · mantenimiento ${plan.tdee!.round()} kcal',
                ),
                if (weightKg == null)
                  const Text(
                    'Registra tu peso para mantener el cálculo actualizado.',
                  ),
              ],
            ),
    ),
  );
}
