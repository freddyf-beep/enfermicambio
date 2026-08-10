import 'package:flutter/material.dart';

import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HOY')),
      body: const AsyncStateView(
        status: AsyncViewStatus.empty(
          'Your daily summary and the four-person ranking will appear here.',
        ),
      ),
    );
  }
}
