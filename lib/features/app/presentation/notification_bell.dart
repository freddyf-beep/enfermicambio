import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/app_theme.dart';
import '../../notifications/data/supabase_notification_repository.dart';
import '../../notifications/presentation/notifications_screen.dart';

/// Bell icon with an unread badge, live via Realtime. Opens the
/// notifications center.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, this.repository});

  final SupabaseNotificationRepository? repository;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  late final SupabaseNotificationRepository _repository;
  StreamSubscription<int>? _subscription;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        SupabaseNotificationRepository(client: Supabase.instance.client);
    _subscription = _repository.watchUnreadCount().listen((count) {
      if (mounted) {
        setState(() {
          _unread = count;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notificaciones',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NotificationsScreen(repository: _repository),
          ),
        );
      },
      icon: Badge(
        isLabelVisible: _unread > 0,
        backgroundColor: AppColors.streakOrange,
        label: Text(
          _unread > 99 ? '99+' : '$_unread',
          style: const TextStyle(fontSize: 10),
        ),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
