import 'package:flutter/material.dart';

import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';

class RankingTab extends StatelessWidget {
  const RankingTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RANKING')),
      body: const AsyncStateView(
        status: AsyncViewStatus.empty(
          'Today, week, and season rankings will appear here.',
        ),
      ),
    );
  }
}
