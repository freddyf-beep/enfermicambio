import 'package:flutter/material.dart';

import '../../activity/presentation/home_tab.dart';
import '../../game/presentation/game_tab.dart';
import '../../nutrition/presentation/register_tab.dart';
import '../../profiles/presentation/about_tab.dart';
import '../../ranking/presentation/ranking_tab.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.tabs});

  /// The five product tabs. Overridable for tests and dependency injection.
  final List<Widget>? tabs;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

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
