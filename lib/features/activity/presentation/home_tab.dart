import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../health/domain/health_models.dart';
import '../../ranking/domain/ranking_models.dart';
import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, this.aggregate, this.ranking = const []});

  final DailyActivityAggregate? aggregate;
  final List<RankingRow> ranking;

  @override
  Widget build(BuildContext context) {
    if (aggregate == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('HOY')),
        body: const AsyncStateView(
          status: AsyncViewStatus.empty(
            'Your daily summary and the four-person ranking will appear here.',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('HOY')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Today', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _SummaryCard(aggregate: aggregate!),
          const SizedBox(height: 24),
          Text('Ranking', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final row in ranking) _RankingRowTile(row: row),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.aggregate});

  final DailyActivityAggregate aggregate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Metric(label: 'Steps', value: aggregate.dailySteps),
            _Metric(label: 'Active kcal', value: aggregate.activeCalories),
            _Metric(
              label: 'Distance',
              value: aggregate.distanceMeters,
              unit: 'm',
            ),
            _Metric(label: 'Exercise min', value: aggregate.exerciseMinutes),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.unit});

  final String label;
  final num value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final suffix = unit ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '${NumberFormat.decimalPattern().format(value)} $suffix',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RankingRowTile extends StatelessWidget {
  const _RankingRowTile({required this.row});

  final RankingRow row;

  @override
  Widget build(BuildContext context) {
    final freshness = switch (row.freshness) {
      UserFreshness.fresh => '',
      UserFreshness.stale => ' (stale)',
      UserFreshness.missing => ' (no data)',
      UserFreshness.denied => ' (permission denied)',
      UserFreshness.unavailable => ' (unavailable)',
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text('${row.rank}')),
      title: Text('${row.displayName}$freshness'),
      trailing: Text(
        NumberFormat.decimalPattern().format(row.value),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
