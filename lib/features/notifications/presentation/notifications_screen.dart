import 'package:flutter/material.dart';

import '../../../shared/ui/app_tab_navigator.dart';
import '../../../shared/ui/app_theme.dart';
import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import '../domain/notification_models.dart';

/// Notifications center: paginated list grouped by day, tap-to-read, and
/// deep links into the app area referenced by the payload.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.repository});

  final NotificationRepository repository;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _pageSize = 20;

  final List<AppNotification> _items = [];
  String? _nextCursor;
  bool _loading = false;
  bool _initialLoaded = false;
  AsyncViewStatus? _status;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _nextCursor == null && _items.isNotEmpty) return;
    setState(() {
      _loading = true;
      _status = null;
    });
    try {
      final page = _nextCursor == null
          ? await widget.repository.loadLatest(limit: _pageSize)
          : await widget.repository.loadAfter(
              cursor: _nextCursor!,
              limit: _pageSize,
            );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _nextCursor = page.nextCursor;
        _loading = false;
        _initialLoaded = true;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _initialLoaded = true;
        _status = _items.isEmpty
            ? AsyncViewStatus.backendError(error.toString())
            : AsyncViewStatus.offline(
                'No se pudieron cargar las notificaciones.',
              );
      });
    }
  }

  Future<void> _open(AppNotification notification) async {
    if (!notification.isRead) {
      await widget.repository.markRead(notification.id);
      if (mounted) {
        setState(() {
          final index = _items.indexWhere((item) => item.id == notification.id);
          if (index != -1) {
            _items[index] = AppNotification(
              id: notification.id,
              type: notification.type,
              title: notification.title,
              body: notification.body,
              payload: notification.payload,
              isRead: true,
              createdAt: notification.createdAt,
            );
          }
        });
      }
    }
    if (!mounted) return;
    final tab = _targetTab(notification);
    if (tab == null) return;
    Navigator.of(context).pop();
    AppTabNavigator.goTo(tab);
  }

  /// 0 HOY (feed posts), 1 RANKING (competition dates), 3 JUEGO (season).
  int? _targetTab(AppNotification notification) {
    if (notification.postId != null) return 0;
    if (notification.seasonId != null) return 3;
    if (notification.competitionDate != null) return 1;
    return switch (notification.type) {
      'round_result' ||
      'round_ending_soon' ||
      'overtake' ||
      'leader_change' => 1,
      'season' => 3,
      'feed_post' || 'comment' || 'reaction' || 'workout' => 0,
      _ => null,
    };
  }

  Future<void> _markAll() async {
    await widget.repository.markAllRead();
    if (!mounted) return;
    setState(() {
      for (final item in _items) {
        final index = _items.indexOf(item);
        _items[index] = AppNotification(
          id: item.id,
          type: item.type,
          title: item.title,
          body: item.body,
          payload: item.payload,
          isRead: true,
          createdAt: item.createdAt,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notificaciones')),
        body: _initialLoaded && _status == null
            ? const _EmptyState()
            : AsyncStateView(
                status: _status ?? const AsyncViewStatus.loading(),
                onRetry: _loadMore,
                child: const _EmptyState(),
              ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            tooltip: 'Marcar todas como leídas',
            icon: const Icon(Icons.done_all),
            onPressed: _markAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadMore(),
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          itemCount: _items.length + 1,
          itemBuilder: (context, index) {
            if (index == _items.length) {
              if (_status?.state == AsyncState.offline) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _status!.message ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return const SizedBox(height: 64);
            }
            final notification = _items[index];
            final showHeader =
                index == 0 ||
                !_sameDay(_items[index - 1].createdAt, notification.createdAt);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                    child: Text(
                      _dayLabel(notification.createdAt),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                _NotificationTile(
                  notification: notification,
                  onTap: () => _open(notification),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    if (_sameDay(date, now)) return 'Hoy';
    if (_sameDay(date, now.subtract(const Duration(days: 1)))) return 'Ayer';
    final monthNames = const [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${date.day} ${monthNames[date.month - 1]}';
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: notification.isRead
          ? null
          : AppColors.primaryLight.withValues(alpha: 0.06),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.12),
          child: _iconFor(notification.type),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead
                ? FontWeight.normal
                : FontWeight.bold,
          ),
        ),
        subtitle: Text(notification.body),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _timeLabel(notification.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!notification.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.streakOrange,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _iconFor(String type) {
    return Icon(
      switch (type) {
        'overtake' || 'leader_change' => Icons.emoji_events,
        'round_result' || 'round_ending_soon' => Icons.timer,
        'achievement' => Icons.military_tech,
        'workout' => Icons.fitness_center,
        'feed_post' => Icons.dynamic_feed,
        'comment' => Icons.chat_bubble_outline,
        'reaction' => Icons.favorite,
        'mission' => Icons.flag,
        'season' => Icons.emoji_events,
        'steps_milestone' || 'personal_record' || 'daily_goal' => Icons.bolt,
        'weight_entry_goal' || 'weight_change' => Icons.monitor_weight,
        _ => Icons.notifications,
      },
      size: 20,
      color: AppColors.primaryLight,
    );
  }

  String _timeLabel(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_none,
              size: 56,
              color: AppColors.primaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin notificaciones todavía',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Aquí aparecerán los adelantamientos, rondas, logros y '
              'publicaciones de tus amigos.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
