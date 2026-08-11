import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../feed/data/supabase_post_repository.dart';
import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';

class RegisterTab extends StatefulWidget {
  const RegisterTab({super.key});

  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<RegisterTab> {
  late final SupabasePostRepository _posts;

  @override
  void initState() {
    super.initState();
    _posts = SupabasePostRepository(client: Supabase.instance.client);
  }

  Future<void> _createTextPost() async {
    final controller = TextEditingController();
    final caption = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New post'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(
            hintText: 'What is happening?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Post'),
          ),
        ],
      ),
    );

    if (caption == null || caption.isEmpty) return;
    final userId = Supabase.instance.client.auth.currentSession?.user.id;
    if (userId == null) return;

    try {
      await _posts.createTextPost(authorId: userId, caption: caption);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post published.')));
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not publish: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('REGISTRAR')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ActionCard(
            icon: Icons.qr_code_scanner,
            title: 'Scan a barcode',
            subtitle: 'Resolve a food product to log.',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Barcode scanning is coming in Phase 5.'),
                ),
              );
            },
          ),
          _ActionCard(
            icon: Icons.camera_alt_outlined,
            title: 'Photograph a meal',
            subtitle: 'Log a meal with a photo.',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Meal photos are coming in Phase 5.'),
                ),
              );
            },
          ),
          _ActionCard(
            icon: Icons.edit_outlined,
            title: 'Write a post',
            subtitle: 'Share something with the group.',
            onTap: _createTextPost,
          ),
          const SizedBox(height: 8),
          const AsyncStateView(
            status: AsyncViewStatus.empty(
              'There is no manual step entry. Steps come from your health '
              'source only.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
