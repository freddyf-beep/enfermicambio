import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/config/app_environment.dart';
import '../../../shared/text/text_encoding.dart';
import '../../../shared/ui/app_theme.dart';
import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import '../data/supabase_game_repository.dart';
import '../domain/game_models.dart';

/// Datos agregados de la pantalla JUEGO. Cuando `loadFromBackend` es false,
/// el widget renderiza este snapshot (contrato de prueba).
class GameSnapshot {
  const GameSnapshot({
    this.seasonName,
    this.seasonStatus,
    this.standings = const [],
    this.missions = const [],
    this.missionProgress = const {},
    this.achievements = const [],
    this.unlockedAchievements = const {},
    this.streaks = const [],
    this.battlePassTiers = const [],
    this.battlePassClaims = const {},
    this.seasonKm = const [],
    this.seasonHistory = const [],
    this.totalPoints = 0,
    this.myPosition,
  });

  final String? seasonName;
  final String? seasonStatus;
  final List<SeasonStanding> standings;
  final List<Mission> missions;
  final Map<String, MissionProgress?> missionProgress;
  final List<Achievement> achievements;
  final Set<String> unlockedAchievements;
  final List<Streak> streaks;
  final List<BattlePassTier> battlePassTiers;
  final Set<int> battlePassClaims;
  final List<SeasonKm> seasonKm;
  final List<SeasonResult> seasonHistory;
  final double totalPoints;
  final int? myPosition;
}

class GameTab extends StatefulWidget {
  const GameTab({super.key, this.loadFromBackend = true, this.snapshot});

  final bool loadFromBackend;
  final GameSnapshot? snapshot;

  @override
  State<GameTab> createState() => _GameTabState();
}

class _GameTabState extends State<GameTab> {
  late final SupabaseGameRepository _repository;
  RealtimeChannel? _channel;
  GameSnapshot? _snapshot;
  AsyncViewStatus? _status;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    if (!widget.loadFromBackend) {
      _snapshot = widget.snapshot ?? const GameSnapshot();
      return;
    }
    _repository = SupabaseGameRepository(client: Supabase.instance.client);
    _load();
    _subscribeCelebrations();
  }

  @override
  void dispose() {
    if (widget.loadFromBackend) {
      final channel = _channel;
      if (channel != null) {
        Supabase.instance.client.removeChannel(channel);
      }
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _status = null;
    });
    try {
      final me = Supabase.instance.client.auth.currentUser?.id;
      final season = await _repository.currentSeason();
      if (season == null) {
        if (!mounted) return;
        setState(() => _snapshot = const GameSnapshot());
        return;
      }

      final today = DateTime.parse(AppEnvironment.todayInCompetitionTz());
      final results = await Future.wait<Object>([
        _repository.standingsFor(season),
        _repository.dailyMissionsFor(today),
        _repository.missionProgressFor(today),
        _repository.achievements(),
        if (me != null) _repository.userAchievements(me),
        if (me != null) _repository.streaksFor(me),
        _repository.battlePassTiers(),
        if (me != null) _repository.battlePassClaims(me, season.id),
        _repository.seasonKm(season),
        _repository.seasonHistory(),
      ]);

      final standings = results[0] as List<SeasonStanding>;
      final missions = results[1] as List<Mission>;
      final progressRows = results[2] as List<MissionProgress>;
      final achievements = results[3] as List<Achievement>;
      final unlocked = results.length > 4 && results[4] is List<dynamic>
          ? results[4] as List<UserAchievement>
          : const <UserAchievement>[];
      final streaks = results.length > 5 && results[5] is List<dynamic>
          ? results[5] as List<Streak>
          : const <Streak>[];
      final tiers = results.length > 6 && results[6] is List<dynamic>
          ? results[6] as List<BattlePassTier>
          : const <BattlePassTier>[];
      final claims = results.length > 7 && results[7] is List<dynamic>
          ? results[7] as List<BattlePassClaim>
          : const <BattlePassClaim>[];
      final seasonKm = results.length > 8 && results[8] is List<dynamic>
          ? results[8] as List<SeasonKm>
          : const <SeasonKm>[];
      final history = results.length > 9 && results[9] is List<dynamic>
          ? results[9] as List<SeasonResult>
          : const <SeasonResult>[];

      final progressByMission = <String, MissionProgress?>{
        for (final mission in missions)
          mission.id: _pickProgress(mission, progressRows, me),
      };
      final myStanding = me == null
          ? null
          : standings.where((s) => s.userId == me).firstOrNull;

      if (!mounted) return;
      setState(() {
        _snapshot = GameSnapshot(
          seasonName: season.name,
          seasonStatus: season.status,
          standings: standings,
          missions: missions,
          missionProgress: progressByMission,
          achievements: achievements,
          unlockedAchievements: {for (final u in unlocked) u.achievementId},
          streaks: streaks,
          battlePassTiers: tiers,
          battlePassClaims: {for (final c in claims) c.tier},
          seasonKm: seasonKm,
          seasonHistory: history,
          totalPoints: myStanding?.totalPoints ?? 0,
          myPosition: myStanding?.position,
        );
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _snapshot == null
            ? AsyncViewStatus.backendError(error.toString())
            : AsyncViewStatus.offline('No se pudieron actualizar los puntos.');
      });
    }
  }

  MissionProgress? _pickProgress(
    Mission mission,
    List<MissionProgress> rows,
    String? me,
  ) {
    for (final row in rows) {
      if (mission.missionType == 'cooperative') {
        if (row.userId == null) return row;
      } else if (row.userId == me) {
        return row;
      }
    }
    return null;
  }

  void _subscribeCelebrations() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final client = Supabase.instance.client;
    _channel = client
        .channel('game-celebrations')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'user_achievements',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _celebrateAchievement(payload),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mission_progress',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _celebrateMission(payload),
        )
        .subscribe();
  }

  void _celebrateAchievement(PostgresChangePayload payload) {
    final achievementId =
        (payload.newRecord['achievement_id'] as String?) ?? '';
    if (achievementId.isEmpty || !mounted) return;
    final name = _snapshot?.achievements
        .where((a) => a.id == achievementId)
        .map((a) => a.name)
        .firstOrNull;
    _celebrate('¡Logro desbloqueado: ${name ?? 'Nuevo logro'}! 🏅');
  }

  void _celebrateMission(PostgresChangePayload payload) {
    final completed = (payload.newRecord['completed'] as bool?) ?? false;
    if (!completed || !mounted) return;
    final missionId = (payload.newRecord['mission_id'] as String?) ?? '';
    final name = _snapshot?.missions
        .where((m) => m.id == missionId)
        .map((m) => m.name)
        .firstOrNull;
    _celebrate('¡Misión completada: ${name ?? 'Misión'}! 🎉');
  }

  void _celebrate(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _load();
  }

  Future<void> _claimTier(BattlePassTier tier) async {
    final season = await _repository.currentSeason();
    if (season == null || _claiming) return;
    setState(() => _claiming = true);
    try {
      final result = await _repository.claimBattlePassReward(
        season.id,
        tier.tier,
      );
      if (!mounted) return;
      final message = result.startsWith('claimed:')
          ? 'Recompensa del nivel ${tier.tier} reclamada: ${tier.rewardName}'
          : 'Ya reclamaste esta recompensa.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
      await _load();
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo reclamar: ${error.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (widget.loadFromBackend && snapshot == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('JUEGO')),
        body: AsyncStateView(
          status: _status ?? const AsyncViewStatus.loading(),
          onRetry: _load,
          child: const SizedBox(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('JUEGO')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (snapshot!.seasonName != null)
              _SeasonBanner(
                seasonName: snapshot.seasonName!,
                seasonStatus: snapshot.seasonStatus,
                totalPoints: snapshot.totalPoints,
                myPosition: snapshot.myPosition,
              ),
            const SizedBox(height: 20),

            if (snapshot.battlePassTiers.isNotEmpty) ...[
              const _SectionHeader(
                title: 'Pase de Batalla',
                icon: Icons.military_tech,
              ),
              const SizedBox(height: 8),
              _BattlePassTrack(
                tiers: snapshot.battlePassTiers,
                totalPoints: snapshot.totalPoints,
                claimedTiers: snapshot.battlePassClaims,
                claiming: _claiming,
                onClaim: _claimTier,
              ),
              const SizedBox(height: 24),
            ],

            const _SectionHeader(
              title: 'Misiones del Día',
              icon: Icons.assignment_turned_in,
            ),
            const SizedBox(height: 8),
            if (snapshot.missions.isEmpty)
              const AsyncStateView(
                status: AsyncViewStatus.empty(
                  'No hay misiones asignadas para hoy. Vuelve mañana.',
                ),
              )
            else
              for (final mission in snapshot.missions) ...[
                _MissionCard(
                  mission: mission,
                  progress: snapshot.missionProgress[mission.id],
                ),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 16),

            const _SectionHeader(
              title: 'Rachas',
              icon: Icons.local_fire_department,
            ),
            const SizedBox(height: 8),
            if (snapshot.streaks.isEmpty)
              const AsyncStateView(
                status: AsyncViewStatus.empty(
                  'Tu racha empieza cuando cumplas tu meta de pasos un día.',
                ),
              )
            else
              for (final streak in snapshot.streaks)
                _StreakCard(streak: streak),
            const SizedBox(height: 24),

            const _SectionHeader(title: 'Logros', icon: Icons.military_tech),
            const SizedBox(height: 8),
            if (snapshot.achievements.isEmpty)
              const AsyncStateView(
                status: AsyncViewStatus.empty('Aún no hay logros publicados.'),
              )
            else
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  for (final achievement in snapshot.achievements)
                    _BadgeTile(
                      name: achievement.name,
                      description: achievement.description,
                      icon: achievement.icon,
                      unlocked: snapshot.unlockedAchievements.contains(
                        achievement.id,
                      ),
                      isSecret: achievement.hidden,
                    ),
                ],
              ),
            const SizedBox(height: 24),

            const _SectionHeader(
              title: 'Tabla de Puntos',
              icon: Icons.leaderboard,
            ),
            const SizedBox(height: 8),
            if (snapshot.standings.isEmpty)
              const AsyncStateView(
                status: AsyncViewStatus.empty(
                  'Aún no hay puntos asignados en la temporada. Los puntos aparecerán tras cerrar la primera franja del día.',
                ),
              )
            else
              for (final standing in snapshot.standings)
                _StandingCard(standing: standing),
            const SizedBox(height: 24),

            if (snapshot.seasonKm.isNotEmpty) ...[
              const _SectionHeader(
                title: 'Kilómetros de la Temporada',
                icon: Icons.route,
              ),
              const SizedBox(height: 8),
              for (final km in snapshot.seasonKm) _KmCard(km: km),
              const SizedBox(height: 24),
            ],

            if (snapshot.seasonHistory.isNotEmpty) ...[
              const _SectionHeader(
                title: 'Historial de Temporadas',
                icon: Icons.history,
              ),
              const SizedBox(height: 8),
              _SeasonHistorySection(results: snapshot.seasonHistory),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeasonBanner extends StatelessWidget {
  const _SeasonBanner({
    required this.seasonName,
    required this.seasonStatus,
    required this.totalPoints,
    required this.myPosition,
  });

  final String seasonName;
  final String? seasonStatus;
  final double totalPoints;
  final int? myPosition;

  @override
  Widget build(BuildContext context) {
    final active = seasonStatus == 'active';
    return Card(
      color: AppColors.darkSurfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.trophyPurple.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events,
                color: AppColors.trophyPurple,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seasonName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    active ? 'En Competencia' : 'Finalizada',
                    style: TextStyle(
                      color: AppColors.fitnessGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (myPosition != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Posición #$myPosition · $totalPoints pts',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryLight),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _BattlePassTrack extends StatelessWidget {
  const _BattlePassTrack({
    required this.tiers,
    required this.totalPoints,
    required this.claimedTiers,
    required this.claiming,
    required this.onClaim,
  });

  final List<BattlePassTier> tiers;
  final double totalPoints;
  final Set<int> claimedTiers;
  final bool claiming;
  final ValueChanged<BattlePassTier> onClaim;

  @override
  Widget build(BuildContext context) {
    final nextTier = tiers
        .where((t) => !claimedTiers.contains(t.tier))
        .where((t) => totalPoints >= t.thresholdPoints)
        .firstOrNull;
    final nextThreshold = tiers
        .map((t) => t.thresholdPoints)
        .where((p) => p > totalPoints)
        .fold<double>(totalPoints, (a, b) => b < a ? b.toDouble() : a);
    final progressTarget = nextThreshold <= 0 ? 1.0 : nextThreshold;

    return Card(
      color: AppColors.darkSurfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$totalPoints pts',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (totalPoints / progressTarget).clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.black.withValues(alpha: 0.3),
                      color: AppColors.trophyPurple,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tiers.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tier = tiers[index];
                  final claimed = claimedTiers.contains(tier.tier);
                  final reached = totalPoints >= tier.thresholdPoints;
                  return _TierChip(
                    tier: tier,
                    reached: reached,
                    claimed: claimed,
                    isNext: nextTier?.tier == tier.tier,
                    onClaim: () => onClaim(tier),
                    claiming: claiming,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({
    required this.tier,
    required this.reached,
    required this.claimed,
    required this.isNext,
    required this.onClaim,
    required this.claiming,
  });

  final BattlePassTier tier;
  final bool reached;
  final bool claimed;
  final bool isNext;
  final VoidCallback onClaim;
  final bool claiming;

  @override
  Widget build(BuildContext context) {
    final color = claimed
        ? AppColors.fitnessGreen
        : reached
        ? AppColors.trophyPurple
        : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    final icon = claimed
        ? Icons.check_circle
        : reached
        ? Icons.workspace_premium
        : Icons.lock;

    return SizedBox(
      width: 100,
      child: Card(
        color: isNext
            ? AppColors.trophyPurple.withValues(alpha: 0.15)
            : AppColors.darkSurfaceVariant,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                'Nv ${tier.tier} · ${tier.thresholdPoints} pts',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tier.rewardName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              if (reached && !claimed)
                FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: AppColors.trophyPurple,
                  ),
                  onPressed: claiming ? null : onClaim,
                  child: Text(
                    claiming ? '...' : 'Reclamar',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      claimed ? Icons.check_circle : Icons.lock,
                      size: 12,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        claimed ? 'Reclamado' : 'Bloqueado',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: color),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission, required this.progress});

  final Mission mission;
  final MissionProgress? progress;

  @override
  Widget build(BuildContext context) {
    final metric = (mission.rules['metric'] as String?) ?? 'steps';
    final target = ((mission.rules['target'] as num?) ?? 0).toDouble();
    final value = progress?.valueOf(metric) ?? 0;
    final completed = progress?.completed ?? false;
    final icon = switch (mission.missionType) {
      'cooperative' => Icons.group,
      'competitive' => Icons.emoji_events,
      _ => Icons.person,
    };

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetails(
          context,
          metric: metric,
          target: target,
          value: value,
          completed: completed,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryLight, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            repairMojibake(mission.name),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (completed)
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.fitnessGreen,
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      repairMojibake(mission.description),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: target <= 0 ? 0 : (value / target).clamp(0.0, 1.0),
                        backgroundColor: AppColors.darkSurfaceVariant,
                        color: AppColors.fitnessGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatNumber(value)} / ${_formatNumber(target)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.streakOrange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${mission.rewardPoints} pts',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.streakOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(
    BuildContext context, {
    required String metric,
    required double target,
    required double value,
    required bool completed,
  }) async {
    final extra = mission.rules['details'] as String?;
    final description = repairMojibake(mission.description);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(repairMojibake(mission.name)),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text(description.isEmpty ? 'Misión diaria' : description),
              const SizedBox(height: 16),
              Text(
                'Cómo se completa',
                style: Theme.of(dialogContext).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Alcanza ${_formatMissionTarget(metric, target)} en ${_metricLabel(metric)}.',
              ),
              if (extra != null && extra.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(repairMojibake(extra)),
              ],
              const SizedBox(height: 16),
              Text(
                'Progreso: ${_formatMissionTarget(metric, value)} de ${_formatMissionTarget(metric, target)}',
              ),
              const SizedBox(height: 4),
              Text(completed ? 'Estado: completada' : 'Estado: en progreso'),
              const SizedBox(height: 4),
              Text('Recompensa: ${mission.rewardPoints} puntos'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  String _metricLabel(String metric) {
    return switch (metric) {
      'steps' || 'morning_steps' || 'afternoon_steps' || 'night_steps' =>
        'pasos',
      'distance_meters' || 'workout_distance_m' => 'distancia',
      'active_calories' => 'calorías activas',
      'exercise_minutes' => 'minutos de ejercicio',
      _ => metric.replaceAll('_', ' '),
    };
  }

  String _formatMissionTarget(String metric, double value) {
    if (metric == 'distance_meters' || metric == 'workout_distance_m') {
      return value >= 1000
          ? '${(value / 1000).toStringAsFixed(1)} km'
          : '${value.round()} m';
    }
    if (metric == 'active_calories') return '${value.round()} kcal';
    if (metric == 'exercise_minutes') return '${value.round()} min';
    return '${_formatNumber(value)} ${_metricLabel(metric)}';
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});

  final Streak streak;

  @override
  Widget build(BuildContext context) {
    final label = switch (streak.streakType) {
      'step_goal' => 'Meta de pasos',
      _ => streak.streakType,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(
          Icons.local_fire_department,
          color: AppColors.streakOrange,
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${streak.currentCount} días seguidos · Récord: ${streak.longestCount} días',
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.name,
    required this.description,
    required this.icon,
    required this.unlocked,
    required this.isSecret,
  });

  final String name;
  final String description;
  final String icon;
  final bool unlocked;
  final bool isSecret;

  @override
  Widget build(BuildContext context) {
    final visible = unlocked || !isSecret;
    final color = unlocked
        ? AppColors.trophyPurple
        : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
    final iconData = !visible ? Icons.lock : _iconFor(icon);
    return Tooltip(
      message: visible
          ? '$name — $description'
          : 'Logro secreto: desbloquéalo para verlo.',
      child: Card(
        color: unlocked
            ? AppColors.darkSurfaceVariant
            : Theme.of(context).cardTheme.color?.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconData, size: 28, color: color),
              const SizedBox(height: 6),
              Text(
                visible ? name : '???',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: unlocked ? FontWeight.bold : FontWeight.normal,
                  color: unlocked
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StandingCard extends StatelessWidget {
  const _StandingCard({required this.standing});

  final SeasonStanding standing;

  @override
  Widget build(BuildContext context) {
    final rankColor = switch (standing.position) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => AppColors.primaryLight,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rankColor.withValues(alpha: 0.2),
          child: Text(
            '#${standing.position}',
            style: TextStyle(fontWeight: FontWeight.bold, color: rankColor),
          ),
        ),
        title: Text(
          standing.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.trophyPurple.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${standing.totalPoints.round()} pts',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.trophyPurple,
            ),
          ),
        ),
      ),
    );
  }
}

class _KmCard extends StatelessWidget {
  const _KmCard({required this.km});

  final SeasonKm km;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.route, color: AppColors.fitnessGreen),
        title: Text(
          km.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: Text(
          '${km.km.toStringAsFixed(1)} km',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.fitnessGreen,
          ),
        ),
      ),
    );
  }
}

class _SeasonHistorySection extends StatelessWidget {
  const _SeasonHistorySection({required this.results});

  final List<SeasonResult> results;

  @override
  Widget build(BuildContext context) {
    final bySeason = <String, List<SeasonResult>>{};
    for (final result in results) {
      bySeason.putIfAbsent(result.seasonId, () => []).add(result);
    }
    final seasons = bySeason.values.toList()
      ..sort((a, b) => (b.first.seasonName).compareTo(a.first.seasonName));
    return Column(
      children: [
        for (final season in seasons) ...[
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(
                Icons.emoji_events,
                color: AppColors.trophyPurple,
              ),
              title: Text(
                season.first.seasonName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Campeón: ${_championOf(season)}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Text(
                '${season.length} jugadores',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _championOf(List<SeasonResult> season) {
    final champion = season.where((r) => r.position == 1).firstOrNull;
    return champion?.displayName ?? 'Sin registro';
  }
}

String _formatNumber(double value) {
  if (value >= 100000) return '${(value / 1000).toStringAsFixed(1)}k';
  final rounded = value.round();
  final digits = rounded.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) buffer.write('.');
  }
  return buffer.toString();
}

IconData _iconFor(String name) {
  const fallback = Icons.military_tech;
  const icons = <String, IconData>{
    'directions_walk': Icons.directions_walk,
    'directions_run': Icons.directions_run,
    'fitness_center': Icons.fitness_center,
    'wb_twilight': Icons.wb_twilight,
    'nightlight': Icons.nightlight,
    'emoji_events': Icons.emoji_events,
    'local_fire_department': Icons.local_fire_department,
    'weekend': Icons.weekend,
    'star': Icons.star,
    'workspace_premium': Icons.workspace_premium,
    'route': Icons.route,
    'lock': Icons.lock,
    'military_tech': Icons.military_tech,
    'sentiment_satisfied': Icons.sentiment_satisfied,
    'flag': Icons.flag,
    'sports_gymnastics': Icons.sports_gymnastics,
    'auto_awesome': Icons.auto_awesome,
  };
  return icons[name] ?? fallback;
}
