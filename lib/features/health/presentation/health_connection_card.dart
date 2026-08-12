import 'package:flutter/material.dart';

import '../../../shared/ui/app_theme.dart';

/// Empty state shown when today's aggregate has not been connected or read.
class HealthConnectionCard extends StatelessWidget {
  const HealthConnectionCard({required this.onConnect, super.key});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.darkSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.health_and_safety_outlined,
                    color: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conecta tu salud',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Apple Health o Health Connect enviarán tus datos automáticos al ranking privado del grupo.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onConnect,
                icon: const Icon(Icons.link),
                label: const Text('Conectar salud'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No se aceptan pasos ingresados manualmente.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
