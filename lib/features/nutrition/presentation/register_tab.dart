import 'package:flutter/material.dart';

import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';

class RegisterTab extends StatelessWidget {
  const RegisterTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('REGISTRAR')),
      body: const AsyncStateView(
        status: AsyncViewStatus.empty(
          'Food logging, posts, and photos will appear here. There is no '
          'manual step entry.',
        ),
      ),
    );
  }
}
