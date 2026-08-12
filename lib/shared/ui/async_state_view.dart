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
          title: 'Sin datos aún',
          message:
              status.message ?? 'No hay datos para mostrar en este momento.',
          onRetry: onRetry,
        );
      case AsyncState.offline:
        return _Message(
          icon: Icons.cloud_off_outlined,
          title: 'Sin conexión',
          message: status.message ?? 'Mostrando los últimos datos guardados.',
          onRetry: onRetry,
        );
      case AsyncState.permissionDenied:
        return _Message(
          icon: Icons.lock_outline,
          title: 'Permiso requerido',
          message:
              status.message ?? 'Concede el acceso para ver este contenido.',
          onRetry: onRetry,
        );
      case AsyncState.backendError:
        return _Message(
          icon: Icons.cloud_off_outlined,
          title: 'Error de servidor',
          message:
              status.message ??
              'No se pudo conectar con el servidor. Inténtalo de nuevo.',
          onRetry: onRetry,
        );
      case AsyncState.stale:
        return _Message(
          icon: Icons.schedule,
          title: 'Datos desactualizados',
          message:
              status.message ?? 'La última sincronización fue hace un tiempo.',
          onRetry: onRetry,
        );
      case AsyncState.retryableFailure:
        return _Message(
          icon: Icons.refresh,
          title: 'No se pudo cargar',
          message: status.message ?? 'Por favor intenta nuevamente.',
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
                child: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
