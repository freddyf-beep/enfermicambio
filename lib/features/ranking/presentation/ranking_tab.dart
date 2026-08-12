import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/app_theme.dart';
import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import '../data/ranking_repository.dart';
import '../domain/ranking_models.dart';

export '../domain/ranking_models.dart'
    show RankingCategory, RankingTimePeriod, RankingRow, UserFreshness;

class RankingTab extends StatefulWidget {
  const RankingTab({
    super.key,
    this.rows = const [],
    this.loadFromBackend = true,
  });

  final List<RankingRow> rows;
  final bool loadFromBackend;

  @override
  State<RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<RankingTab> {
  late final RankingRepository _repository;
  List<RankingRow>? _rows;
  AsyncViewStatus? _status;

  RankingTimePeriod _selectedPeriod = RankingTimePeriod.hoy;
  RankingCategory _selectedCategory = RankingCategory.pasos;

  @override
  void initState() {
    super.initState();
    if (!widget.loadFromBackend) {
      _rows = widget.rows;
      return;
    }
    _repository = RankingRepository(client: Supabase.instance.client);
    _load();
  }

  void _onSelectionChanged() {
    setState(() {});
    if (widget.loadFromBackend) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _status = null;
    });
    try {
      final rows = await _repository.load(
        category: _selectedCategory,
        period: _selectedPeriod,
        now: DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _rows == null
            ? AsyncViewStatus.backendError(error.toString())
            : AsyncViewStatus.offline(
                'No se pudo actualizar la tabla de clasificación.',
              );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_rows == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('RANKING')),
        body: AsyncStateView(
          status: _status ?? const AsyncViewStatus.loading(),
          onRetry: _load,
          child: const SizedBox(),
        ),
      );
    }

    if (_rows!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('RANKING')),
        body: AsyncStateView(
          status: AsyncViewStatus.empty(
            'Las clasificaciones del día, semana y temporada aparecerán cuando los 4 amigos sincronicen su actividad.',
          ),
        ),
      );
    }

    final rows = _rows!;
    return Scaffold(
      appBar: AppBar(title: const Text('RANKING')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // Segmented Period Selector (Hoy | Semana | Temporada)
            SegmentedButton<RankingTimePeriod>(
              segments: const [
                ButtonSegment(
                  value: RankingTimePeriod.hoy,
                  label: Text('Hoy'),
                  icon: Icon(Icons.today),
                ),
                ButtonSegment(
                  value: RankingTimePeriod.semana,
                  label: Text('Semana'),
                  icon: Icon(Icons.date_range),
                ),
                ButtonSegment(
                  value: RankingTimePeriod.temporada,
                  label: Text('Temporada'),
                  icon: Icon(Icons.emoji_events),
                ),
              ],
              selected: {_selectedPeriod},
              onSelectionChanged: (newSelection) {
                _selectedPeriod = newSelection.first;
                _onSelectionChanged();
              },
            ),
            const SizedBox(height: 16),

            // Horizontal Category Selector Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _CategoryChip(
                    label: 'Pasos',
                    icon: Icons.directions_walk,
                    selected: _selectedCategory == RankingCategory.pasos,
                    onSelected: () {
                      _selectedCategory = RankingCategory.pasos;
                      _onSelectionChanged();
                    },
                  ),
                  const SizedBox(width: 8),
                  _CategoryChip(
                    label: 'Franjas Horarias',
                    icon: Icons.access_time,
                    selected: _selectedCategory == RankingCategory.franjas,
                    onSelected: () {
                      _selectedCategory = RankingCategory.franjas;
                      _onSelectionChanged();
                    },
                  ),
                  const SizedBox(width: 8),
                  _CategoryChip(
                    label: 'Distancia',
                    icon: Icons.straighten,
                    selected: _selectedCategory == RankingCategory.distancia,
                    onSelected: () {
                      _selectedCategory = RankingCategory.distancia;
                      _onSelectionChanged();
                    },
                  ),
                  const SizedBox(width: 8),
                  _CategoryChip(
                    label: 'Entrenamientos',
                    icon: Icons.fitness_center,
                    selected:
                        _selectedCategory == RankingCategory.entrenamientos,
                    onSelected: () {
                      _selectedCategory = RankingCategory.entrenamientos;
                      _onSelectionChanged();
                    },
                  ),
                  const SizedBox(width: 8),
                  _CategoryChip(
                    label: 'Calorías',
                    icon: Icons.local_fire_department,
                    selected: _selectedCategory == RankingCategory.calorias,
                    onSelected: () {
                      _selectedCategory = RankingCategory.calorias;
                      _onSelectionChanged();
                    },
                  ),
                  const SizedBox(width: 8),
                  _CategoryChip(
                    label: 'Puntos de Juego',
                    icon: Icons.stars,
                    selected: _selectedCategory == RankingCategory.puntos,
                    onSelected: () {
                      _selectedCategory = RankingCategory.puntos;
                      _onSelectionChanged();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Leaderboard Cards
            for (final row in rows)
              _RankingCard(row: row, category: _selectedCategory),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? Colors.white : AppColors.primaryLight,
      ),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.darkSurfaceVariant,
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({required this.row, required this.category});

  final RankingRow row;
  final RankingCategory category;

  @override
  Widget build(BuildContext context) {
    final rankColor = switch (row.rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => AppColors.primaryLight,
    };

    final freshnessText = switch (row.freshness) {
      UserFreshness.fresh => 'Sincronizado ahora',
      UserFreshness.stale => 'Desactualizado',
      UserFreshness.missing => 'Sin datos aún',
      UserFreshness.denied => 'Permiso denegado',
      UserFreshness.unavailable => 'No disponible',
    };

    final unitLabel = switch (category) {
      RankingCategory.pasos => 'pasos',
      RankingCategory.franjas => 'franjas ganadas',
      RankingCategory.distancia => 'km',
      RankingCategory.entrenamientos => 'entrenamientos',
      RankingCategory.calorias => 'kcal',
      RankingCategory.puntos => 'pts',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: rankColor, width: 2),
              ),
              child: Text(
                '#${row.rank}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: rankColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: row.freshness == UserFreshness.fresh
                              ? AppColors.fitnessGreen
                              : Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        freshnessText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatValue(row.value),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: AppColors.primaryLight,
                  ),
                ),
                Text(
                  unitLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatValue(double val) {
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}k';
    if (val != val.roundToDouble()) return val.toStringAsFixed(1);
    return val.toStringAsFixed(0);
  }
}
