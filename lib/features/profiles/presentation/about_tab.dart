import 'package:flutter/material.dart';

import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';

class AboutTab extends StatelessWidget {
  const AboutTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NOSOTROS')),
      body: const AsyncStateView(
        status: AsyncViewStatus.empty(
          'The four profiles, season rank, and lifetime stats will appear '
          'here.',
        ),
      ),
    );
  }
}
