import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import '../data/supabase_profile_repository.dart';
import '../domain/profile_models.dart';

class AboutTab extends StatefulWidget {
  const AboutTab({super.key});

  @override
  State<AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends State<AboutTab> {
  late final SupabaseProfileRepository _repository;
  List<UserProfile>? _profiles;
  AsyncViewStatus? _status;

  @override
  void initState() {
    super.initState();
    _repository = SupabaseProfileRepository(client: Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _status = null;
    });
    try {
      final profiles = await _repository.fetchAll();
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _profiles == null
            ? AsyncViewStatus.backendError(error.toString())
            : AsyncViewStatus.offline('Could not refresh profiles.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_profiles == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('NOSOTROS')),
        body: AsyncStateView(
          status: _status ?? const AsyncViewStatus.loading(),
          onRetry: _load,
          child: const SizedBox(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('NOSOTROS')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _profiles!.length,
          itemBuilder: (context, index) {
            return _ProfileTile(profile: _profiles![index]);
          },
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          profile.displayName.isEmpty
              ? '?'
              : profile.displayName[0].toUpperCase(),
        ),
      ),
      title: Text(profile.displayName),
      subtitle: Text(
        'Step goal ${profile.dailyStepTarget} - '
        'Calorie target ${profile.dailyCalorieTarget}',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
