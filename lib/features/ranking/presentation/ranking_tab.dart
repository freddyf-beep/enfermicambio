import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import '../domain/ranking_models.dart';

class RankingTab extends StatelessWidget {
  const RankingTab({super.key, this.rows = const []});

  final List<RankingRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('RANKING')),
        body: const AsyncStateView(
          status: AsyncViewStatus.empty(
            'Today, week, and season rankings will appear here once the '
            'group syncs their activity.',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('RANKING')),
      body: ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          return _RankingTile(row: row, highlight: row.rank == 1);
        },
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({required this.row, required this.highlight});

  final RankingRow row;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: highlight
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        child: Text(
          '${row.rank}',
          style: TextStyle(
            color: highlight ? theme.colorScheme.onPrimary : null,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(row.displayName),
      subtitle: Text(_subtitle(), style: theme.textTheme.bodySmall),
      trailing: Text(
        NumberFormat.decimalPattern().format(row.value),
        style: theme.textTheme.titleMedium,
      ),
    );
  }

  String _subtitle() {
    final freshness = switch (row.freshness) {
      UserFreshness.fresh => 'synced just now',
      UserFreshness.stale =>
        'stale - last sync '
            '${_ago(row.lastSyncedAt!)}',
      UserFreshness.missing => 'no data yet',
      UserFreshness.denied => 'permission denied',
      UserFreshness.unavailable => 'source unavailable',
    };
    return freshness;
  }

  String _ago(DateTime time) {
    final diff = DateTime.now().toUtc().difference(time);
    if (diff.inHours >= 1) return '${diff.inHours} h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} min ago';
    return 'moments ago';
  }
}
