import 'package:flutter/material.dart';

import 'async_view_status.dart';

class AsyncStateView extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.status,
    this.child,
    this.onRetry,
  });

  final AsyncViewStatus status;
  final Widget? child;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    switch (status.state) {
      case AsyncState.loading:
        return const Center(child: CircularProgressIndicator());
      case AsyncState.ready:
        return child ?? const SizedBox.shrink();
      case AsyncState.empty:
        return _Message(
          icon: Icons.inbox_outlined,
          title: 'Nothing here yet',
          message: status.message ?? 'There is no data to show.',
          onRetry: onRetry,
        );
      case AsyncState.offline:
        return _Message(
          icon: Icons.cloud_off_outlined,
          title: 'You are offline',
          message: status.message ?? 'Showing the last saved data.',
          onRetry: onRetry,
        );
      case AsyncState.permissionDenied:
        return _Message(
          icon: Icons.lock_outline,
          title: 'Permission needed',
          message: status.message ?? 'Allow access to see this content.',
          onRetry: onRetry,
        );
      case AsyncState.backendError:
        return _Message(
          icon: Icons.cloud_off_outlined,
          title: 'Something went wrong',
          message:
              status.message ?? 'We could not reach the server. Try again.',
          onRetry: onRetry,
        );
      case AsyncState.stale:
        return _Message(
          icon: Icons.schedule,
          title: 'Data may be out of date',
          message: status.message ?? 'The last sync was a while ago.',
          onRetry: onRetry,
        );
      case AsyncState.retryableFailure:
        return _Message(
          icon: Icons.refresh,
          title: 'Could not load',
          message: status.message ?? 'Please try again.',
          onRetry: onRetry,
        );
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
