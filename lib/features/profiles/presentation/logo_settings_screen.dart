import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/app_logo.dart';
import '../../../shared/ui/app_theme.dart';
import '../../../shared/platform/launcher_icon_service.dart';

class LogoSettingsScreen extends StatelessWidget {
  const LogoSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Personalizar logo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Elige el logo que quieres ver dentro de EnfermiCambio. La elección se guarda por usuario en este dispositivo.',
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<String>(
            valueListenable: AppLogoSelection.current,
            builder: (context, selectedId, _) {
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.86,
                ),
                itemCount: AppLogos.options.length,
                itemBuilder: (context, index) {
                  final option = AppLogos.options[index];
                  final selected = selectedId == option.id;
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    color: selected
                        ? AppColors.primaryLight.withValues(alpha: 0.16)
                        : null,
                    child: InkWell(
                      onTap: () async {
                        if (userId == null) return;
                        await AppLogoSelection.save(option.id, userId: userId);
                        final result = await const LauncherIconService()
                            .setLogo(option.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Logo cambiado a ${option.label}. ${result.message}',
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  option.assetPath,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Icon(
                                  selected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: selected
                                      ? AppColors.fitnessGreen
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'El cambio se guarda para tu usuario y también intenta actualizar el icono de inicio. En iPhone aparecerá una confirmación del sistema.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
