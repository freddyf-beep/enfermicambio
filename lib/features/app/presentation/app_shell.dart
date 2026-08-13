import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/app_logo.dart';
import '../../../shared/ui/app_tab_navigator.dart';
import '../../activity/presentation/home_tab.dart';
import '../../game/presentation/game_tab.dart';
import '../../nutrition/presentation/register_tab.dart';
import '../../profiles/presentation/about_tab.dart';
import '../../ranking/presentation/ranking_tab.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.tabs, this.onResume});

  /// The five product tabs. Overridable for tests and dependency injection.
  final List<Widget>? tabs;

  /// Called when the app returns to the foreground (resume). Used to trigger
  /// health sync without blocking the shell.
  final VoidCallback? onResume;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppTabNavigator.requests.addListener(_onTabRequest);
    final userId = _currentUserIdOrNull();
    if (userId != null) {
      AppLogoSelection.loadForUser(userId);
    }
  }

  String? _currentUserIdOrNull() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } on AssertionError {
      // Widget tests inject only tabs and intentionally do not initialize
      // Supabase. Production reaches this shell after the authenticated gate.
      return null;
    }
  }

  @override
  void dispose() {
    AppTabNavigator.requests.removeListener(_onTabRequest);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onTabRequest() {
    final tab = AppTabNavigator.requests.value;
    if (tab == null || !mounted || tab == _selectedIndex) return;
    setState(() {
      _selectedIndex = tab;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.onResume?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs =
        widget.tabs ??
        const <Widget>[
          HomeTab(),
          RankingTab(),
          RegisterTab(),
          GameTab(),
          AboutTab(),
        ];
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'HOY',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: 'RANKING',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'REGISTRAR',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'JUEGO',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'NOSOTROS',
          ),
        ],
      ),
    );
  }
}
