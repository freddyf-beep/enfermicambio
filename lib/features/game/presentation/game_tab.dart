import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import '../data/supabase_game_repository.dart';
import '../domain/game_models.dart';

class GameTab extends StatefulWidget {
  const GameTab({super.key});

  @override
  State<GameTab> createState() => _GameTabState();
}

class _GameTabState extends State<GameTab> {
  late final SupabaseGameRepository _repository;
  Season? _season;
  List<SeasonStanding>? _standings;
  AsyncViewStatus? _status;

  @override
  void initState() {
    super.initState();
    _repository = SupabaseGameRepository(client: Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _status = null;
    });
    try {
      final season = await _repository.currentSeason();
      final standings = season == null
          ? <SeasonStanding>[]
          : await _repository.standingsFor(season);
      if (!mounted) return;
      setState(() {
        _season = season;
        _standings = standings;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _season == null
            ? AsyncViewStatus.backendError(error.toString())
            : AsyncViewStatus.offline('Could not refresh standings.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_season == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('JUEGO')),
        body: AsyncStateView(
          status: _status ?? const AsyncViewStatus.loading(),
          onRetry: _load,
          child: const SizedBox(),
        ),
      );
    }

    final standings = _standings ?? const <SeasonStanding>[];
    return Scaffold(
      appBar: AppBar(title: const Text('JUEGO')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _season!.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${_season!.status}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Standings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (standings.isEmpty)
              const AsyncStateView(
                status: AsyncViewStatus.empty(
                  'No season points yet. The first standings will appear '
                  'after the first round closes.',
                ),
              )
            else
              for (final standing in standings)
                _StandingTile(standing: standing),
          ],
        ),
      ),
    );
  }
}

class _StandingTile extends StatelessWidget {
  const _StandingTile({required this.standing});

  final SeasonStanding standing;

  @override
  Widget build(BuildContext context) {
    final highlight = standing.position == 1;
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: highlight
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        child: Text(
          '${standing.position}',
          style: TextStyle(
            color: highlight ? theme.colorScheme.onPrimary : null,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(standing.displayName),
      trailing: Text(
        '${standing.totalPoints.round()} pts',
        style: theme.textTheme.titleMedium,
      ),
    );
  }
}
