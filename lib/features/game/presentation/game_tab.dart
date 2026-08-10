import 'package:flutter/material.dart';

import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';

class GameTab extends StatelessWidget {
  const GameTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JUEGO')),
      body: const AsyncStateView(
        status: AsyncViewStatus.empty(
          'Season standings, missions, streaks, achievements, and trophies '
          'will appear here.',
        ),
      ),
    );
  }
}
