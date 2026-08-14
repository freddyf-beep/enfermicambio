import 'package:flutter/material.dart';

import '../../../../shared/ui/app_theme.dart';
import '../../../health/domain/health_models.dart';
import '../../../ranking/domain/ranking_models.dart';

class CompetitionDashboardHero extends StatelessWidget {
  const CompetitionDashboardHero({
    required this.date,
    required this.activity,
    required this.currentRanking,
    required this.notificationButton,
    required this.onOpenGame,
    required this.onRefresh,
    required this.onShare,
    this.showingCachedData = false,
    super.key,
  });

  final DateTime date;
  final DailyActivityAggregate? activity;
  final RankingRow? currentRanking;
  final Widget notificationButton;
  final VoidCallback onOpenGame;
  final VoidCallback onRefresh;
  final VoidCallback onShare;
  final bool showingCachedData;

  @override
  Widget build(BuildContext context) {
    final steps = activity?.dailySteps ?? currentRanking?.value.round() ?? 0;
    final rank = currentRanking?.rank;
    final distance = activity?.distanceMeters ?? 0;
    final calories = activity?.activeCalories ?? 0;
    final exerciseMinutes = activity?.exerciseMinutes ?? 0;

    return Semantics(
      container: true,
      label: rank == null
          ? 'Resumen de hoy, $_stepsLabel pasos'
          : 'Tu posición es $rank, $_stepsLabel pasos',
      child: Container(
        key: const Key('competition-dashboard-hero'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF073A69), Color(0xFF112B55), Color(0xFF351A42)],
            stops: [0, 0.58, 1],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF087EC5).withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              const Positioned(
                right: -70,
                top: -90,
                child: _AmbientGlow(size: 230, color: Color(0xFFFF4F50)),
              ),
              const Positioned(
                left: -90,
                bottom: -120,
                child: _AmbientGlow(size: 260, color: Color(0xFF00A9FF)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DashboardTopBar(
                      date: date,
                      notificationButton: notificationButton,
                      onOpenGame: onOpenGame,
                      onRefresh: onRefresh,
                    ),
                    const SizedBox(height: 16),
                    DashboardWeekStrip(selectedDate: date),
                    const SizedBox(height: 24),
                    Text(
                      rank == null
                          ? 'Tu actividad de hoy'
                          : 'Tu posición #$rank',
                      style: const TextStyle(
                        color: Color(0xFFB7D7F7),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final valueSize = constraints.maxWidth < 330
                            ? 46.0
                            : 56.0;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                _formatWholeNumber(steps),
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: valueSize,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -2.2,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(left: 7, bottom: 7),
                              child: Text(
                                'pasos',
                                style: TextStyle(
                                  color: Color(0xFFB7D7F7),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HeroMetric(
                          icon: Icons.route_outlined,
                          value: _formatDistance(distance),
                          color: const Color(0xFF57D7FF),
                        ),
                        _HeroMetric(
                          icon: Icons.local_fire_department_rounded,
                          value: '${calories.round()} kcal',
                          color: const Color(0xFFFF6B73),
                        ),
                        _HeroMetric(
                          icon: Icons.timer_outlined,
                          value: '${exerciseMinutes.round()} min',
                          color: AppColors.primaryLight,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final status = showingCachedData
                            ? const _StatusPill(
                                icon: Icons.cloud_off_outlined,
                                text: 'Datos guardados',
                                color: AppColors.streakOrange,
                              )
                            : _StatusPill(
                                icon: activity == null
                                    ? Icons.sync_problem_outlined
                                    : Icons.check_circle_outline,
                                text: activity == null
                                    ? 'Pendiente de sincronizar'
                                    : 'Sincronizado',
                                color: activity == null
                                    ? AppColors.streakOrange
                                    : AppColors.primaryLight,
                              );
                        final shareButton = TextButton.icon(
                          key: const Key('share-daily-summary'),
                          onPressed: onShare,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                          icon: const Icon(Icons.ios_share_rounded, size: 17),
                          label: const Text(
                            'Compartir',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        );
                        if (constraints.maxWidth < 285) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              status,
                              Align(
                                alignment: Alignment.centerRight,
                                child: shareButton,
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [status, const Spacer(), shareButton],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _stepsLabel {
    final steps = activity?.dailySteps ?? currentRanking?.value.round() ?? 0;
    return _formatWholeNumber(steps);
  }
}

class DashboardWeekStrip extends StatelessWidget {
  const DashboardWeekStrip({required this.selectedDate, super.key});

  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final day = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final monday = day.subtract(Duration(days: day.weekday - DateTime.monday));
    final days = List<DateTime>.generate(
      7,
      (index) => monday.add(Duration(days: index)),
    );

    return Row(
      children: [
        for (var index = 0; index < days.length; index++) ...[
          Expanded(
            child: _WeekDayChip(
              date: days[index],
              selected: _sameDay(days[index], day),
            ),
          ),
          if (index != days.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class GroupRankingCard extends StatelessWidget {
  const GroupRankingCard({
    required this.rows,
    required this.currentUserId,
    required this.onCreatePost,
    required this.onOpenGroup,
    super.key,
  });

  final List<RankingRow> rows;
  final String? currentUserId;
  final VoidCallback onCreatePost;
  final VoidCallback onOpenGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('dashboard-group-ranking'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2638),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF30445F)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EnfermiCambio',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Competencia privada · ${rows.length} amigos',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF9CB1CA),
                      ),
                    ),
                  ],
                ),
              ),
              _RoundActionButton(
                tooltip: 'Publicar en el feed',
                icon: Icons.chat_bubble_outline_rounded,
                onPressed: onCreatePost,
              ),
              const SizedBox(width: 8),
              _RoundActionButton(
                tooltip: 'Ver grupo',
                icon: Icons.group_outlined,
                onPressed: onOpenGroup,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text(
                'El ranking aparecerá cuando lleguen los primeros pasos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9CB1CA)),
              ),
            )
          else
            for (var index = 0; index < rows.length; index++) ...[
              DashboardRankingRow(
                row: rows[index],
                isCurrentUser: rows[index].userId == currentUserId,
              ),
              if (index != rows.length - 1)
                const Divider(height: 1, color: Color(0xFF2B3B52)),
            ],
        ],
      ),
    );
  }
}

class DashboardRankingRow extends StatelessWidget {
  const DashboardRankingRow({
    required this.row,
    required this.isCurrentUser,
    super.key,
  });

  final RankingRow row;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final rankColor = _rankColor(row.rank);
    final freshness = _freshnessLabel(row.freshness);
    return Semantics(
      label:
          'Posición ${row.rank}, ${row.displayName}, ${_formatWholeNumber(row.value.round())} pasos',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: _RankMedal(rank: row.rank, color: rankColor),
            ),
            const SizedBox(width: 8),
            _DashboardAvatar(row: row, color: rankColor),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isCurrentUser ? 'Tú' : row.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(
                              alpha: 0.16,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'TÚ',
                            style: TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    freshness.text,
                    style: TextStyle(
                      color: freshness.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatWholeNumber(row.value.round()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'pasos',
                  style: TextStyle(color: Color(0xFF9CB1CA), fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardSectionHeader extends StatelessWidget {
  const DashboardSectionHeader({
    required this.title,
    required this.icon,
    this.trailing,
    super.key,
  });

  final String title;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primaryLight),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({
    required this.date,
    required this.notificationButton,
    required this.onOpenGame,
    required this.onRefresh,
  });

  final DateTime date;
  final Widget notificationButton;
  final VoidCallback onOpenGame;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 290;
        return Row(
          children: [
            Expanded(
              child: Text(
                '${date.day} ${_monthName(date.month)}',
                maxLines: 1,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 23 : 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _RoundActionButton(
              tooltip: 'Abrir competencia',
              label: 'VS',
              foregroundColor: const Color(0xFFFFC44D),
              backgroundColor: const Color(0xFF5A3345),
              onPressed: onOpenGame,
            ),
            if (!compact) ...[
              const SizedBox(width: 6),
              _RoundActionButton(
                tooltip: 'Actualizar',
                icon: Icons.refresh_rounded,
                onPressed: onRefresh,
              ),
            ],
            const SizedBox(width: 2),
            SizedBox(width: 40, height: 40, child: notificationButton),
          ],
        );
      },
    );
  }
}

class _WeekDayChip extends StatelessWidget {
  const _WeekDayChip({required this.date, required this.selected});

  final DateTime date;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF355F91)
            : Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: selected
              ? const Color(0xFF5EA7F1)
              : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        children: [
          Text(
            _weekdayName(date.weekday),
            style: TextStyle(
              color: selected
                  ? const Color(0xFF9BD4FF)
                  : const Color(0xFF788EA8),
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${date.day}',
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFFA2B1C4),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.label,
    this.foregroundColor = const Color(0xFFD9E6F5),
    this.backgroundColor = const Color(0xFF2B3C55),
  }) : assert(icon != null || label != null);

  final String tooltip;
  final VoidCallback onPressed;
  final IconData? icon;
  final String? label;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 19, color: foregroundColor)
                  : Text(
                      label!,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RankMedal extends StatelessWidget {
  const _RankMedal({required this.rank, required this.color});

  final int rank;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DashboardAvatar extends StatelessWidget {
  const _DashboardAvatar({required this.row, required this.color});

  final RankingRow row;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      alignment: Alignment.center,
      color: color.withValues(alpha: 0.16),
      child: Text(
        row.displayName.isEmpty ? '?' : row.displayName[0].toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );

    return Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: ClipOval(
        child: row.avatarUrl == null || row.avatarUrl!.isEmpty
            ? fallback
            : Image.network(
                row.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _FreshnessPresentation {
  const _FreshnessPresentation(this.text, this.color);

  final String text;
  final Color color;
}

_FreshnessPresentation _freshnessLabel(UserFreshness freshness) {
  return switch (freshness) {
    UserFreshness.fresh => const _FreshnessPresentation(
      'Sincronizado hoy',
      AppColors.primaryLight,
    ),
    UserFreshness.stale => const _FreshnessPresentation(
      'Datos desactualizados',
      AppColors.streakOrange,
    ),
    UserFreshness.missing => const _FreshnessPresentation(
      'Aún sin datos',
      Color(0xFF9CB1CA),
    ),
    UserFreshness.denied => const _FreshnessPresentation(
      'Puente sin sincronizar',
      AppColors.streakOrange,
    ),
    UserFreshness.unavailable => const _FreshnessPresentation(
      'No disponible',
      Color(0xFF9CB1CA),
    ),
  };
}

Color _rankColor(int rank) {
  return switch (rank) {
    1 => const Color(0xFFFFC94A),
    2 => const Color(0xFF55C7FF),
    3 => const Color(0xFFD99563),
    _ => const Color(0xFF90A5BE),
  };
}

String _formatDistance(double meters) {
  if (!meters.isFinite || meters <= 0) return '0 m';
  if (meters < 1000) {
    final value = meters < 100
        ? meters.toStringAsFixed(1)
        : '${meters.round()}';
    return '$value m';
  }
  return '${(meters / 1000).toStringAsFixed(2)} km';
}

String _formatWholeNumber(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

String _monthName(int month) {
  const names = [
    'ENE',
    'FEB',
    'MAR',
    'ABR',
    'MAY',
    'JUN',
    'JUL',
    'AGO',
    'SEP',
    'OCT',
    'NOV',
    'DIC',
  ];
  return names[month.clamp(1, 12) - 1];
}

String _weekdayName(int weekday) {
  const names = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
  return names[weekday.clamp(1, 7) - 1];
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
