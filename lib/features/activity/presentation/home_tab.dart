import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/data/dashboard_cache.dart';
import '../../feed/domain/feed_models.dart';
import '../../feed/presentation/feed_list.dart';
import '../../health/domain/health_models.dart';
import '../../ranking/domain/ranking_models.dart';
import '../../../shared/ui/async_view_status.dart';
import '../../../shared/ui/async_state_view.dart';
import '../../app/data/dashboard_repository.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final DashboardRepository _repository;
  AppDashboardData? _data;
  AsyncViewStatus? _status;
  DashboardCache? _cache;
  bool _showingCache = false;

  @override
  void initState() {
    super.initState();
    _repository = DashboardRepository(client: Supabase.instance.client);
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _cache = DashboardCache(prefs);
    final cached = _cache!.readRanking();
    if (cached != null && mounted) {
      setState(() {
        _data ??= AppDashboardData(
          ranking: cached,
          feedPage: const FeedPage(posts: [], nextCursor: null),
          me: null,
        );
        _showingCache = true;
      });
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _status = null;
    });
    try {
      final data = await _repository.load(now: DateTime.now().toUtc());
      if (!mounted) return;
      await _cache?.writeRanking(data.ranking);
      await _cache?.writeLastSync(DateTime.now().toUtc());
      setState(() {
        _data = data;
        _showingCache = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _data == null
            ? AsyncViewStatus.backendError(error.toString())
            : AsyncViewStatus.offline(
                'Could not refresh. Showing the last saved data.',
              );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('HOY')),
        body: AsyncStateView(
          status: _status ?? const AsyncViewStatus.loading(),
          onRetry: _load,
          child: const SizedBox(),
        ),
      );
    }

    final data = _data!;
    return Scaffold(
      appBar: AppBar(title: const Text('HOY')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_showingCache) ...[
              Text(
                'Showing cached data',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text('Today', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _SummaryCard(aggregate: data.me),
            const SizedBox(height: 24),
            Text('Ranking', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final row in data.ranking) _RankingRowTile(row: row),
            const SizedBox(height: 24),
            Text('Feed', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            FeedList(posts: data.feedPage.posts),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.aggregate});

  final DailyActivityAggregate? aggregate;

  @override
  Widget build(BuildContext context) {
    if (aggregate == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Connect a health source to see your daily summary.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Metric(label: 'Steps', value: aggregate!.dailySteps),
            _Metric(label: 'Active kcal', value: aggregate!.activeCalories),
            _Metric(
              label: 'Distance',
              value: aggregate!.distanceMeters,
              unit: 'm',
            ),
            _Metric(label: 'Exercise min', value: aggregate!.exerciseMinutes),
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
            '${_format(value)} $suffix',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  String _format(num value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
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
        _format(row.value),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  String _format(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }
}
