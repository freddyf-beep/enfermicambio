import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import '../../app/data/dashboard_repository.dart';
import '../domain/ranking_models.dart';

class RankingTab extends StatefulWidget {
  const RankingTab({
    super.key,
    this.rows = const [],
    this.loadFromBackend = true,
  });

  final List<RankingRow> rows;

  /// When false, renders [rows] directly without touching Supabase (tests).
  final bool loadFromBackend;

  @override
  State<RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<RankingTab> {
  late final DashboardRepository _repository;
  List<RankingRow>? _rows;
  AsyncViewStatus? _status;

  @override
  void initState() {
    super.initState();
    if (!widget.loadFromBackend) {
      _rows = widget.rows;
      return;
    }
    _repository = DashboardRepository(client: Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _status = null;
    });
    try {
      final data = await _repository.load(now: DateTime.now().toUtc());
      if (!mounted) return;
      setState(() {
        _rows = data.ranking;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _rows == null
            ? AsyncViewStatus.backendError(error.toString())
            : AsyncViewStatus.offline('Could not refresh rankings.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_rows == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('RANKING')),
        body: AsyncStateView(
          status: _status ?? const AsyncViewStatus.loading(),
          onRetry: _load,
          child: const SizedBox(),
        ),
      );
    }
    if (_rows!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('RANKING')),
        body: AsyncStateView(
          status: AsyncViewStatus.empty(
            'Today, week, and season rankings will appear here once the '
            'group syncs their activity.',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('RANKING')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _rows!.length,
          itemBuilder: (context, index) {
            final row = _rows![index];
            return _RankingTile(row: row, highlight: row.rank == 1);
          },
        ),
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
      trailing: Text(_format(row.value), style: theme.textTheme.titleMedium),
    );
  }

  String _subtitle() {
    return switch (row.freshness) {
      UserFreshness.fresh => 'synced',
      UserFreshness.stale => 'stale - last sync a while ago',
      UserFreshness.missing => 'no data yet',
      UserFreshness.denied => 'permission denied',
      UserFreshness.unavailable => 'source unavailable',
    };
  }

  String _format(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(0);
  }
}
