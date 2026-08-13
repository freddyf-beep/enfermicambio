import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLogoOption {
  const AppLogoOption({
    required this.id,
    required this.label,
    required this.assetPath,
  });

  final String id;
  final String label;
  final String assetPath;
}

class AppLogos {
  AppLogos._();

  static const options = <AppLogoOption>[
    AppLogoOption(
      id: 'default',
      label: 'EnfermiCambio',
      assetPath: 'assets/logos/logo-default.png',
    ),
    AppLogoOption(
      id: 'red-transparent',
      label: 'Atleta',
      assetPath: 'assets/logos/logo-red-transparent.png',
    ),
    AppLogoOption(
      id: 'red-cropped',
      label: 'Enfermero rojo',
      assetPath: 'assets/logos/logo-red-cropped.png',
    ),
    AppLogoOption(
      id: 'medical-cropped',
      label: 'Enfermero clínico',
      assetPath: 'assets/logos/logo-medical-cropped.png',
    ),
  ];

  static AppLogoOption byId(String id) {
    return options.firstWhere(
      (option) => option.id == id,
      orElse: () => options.first,
    );
  }
}

class AppLogoSelection {
  AppLogoSelection._();

  static final ValueNotifier<String> current = ValueNotifier<String>(
    AppLogos.options.first.id,
  );

  static Future<void> loadForUser(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _keyFor(userId);
    final selected = preferences.getString(key);
    current.value = selected == null
        ? AppLogos.options.first.id
        : AppLogos.byId(selected).id;
  }

  static Future<void> save(String id, {required String userId}) async {
    final selected = AppLogos.byId(id).id;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_keyFor(userId), selected);
    current.value = selected;
  }

  static String _keyFor(String userId) => 'enfermicambio_logo_$userId';
}

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 56, this.borderRadius = 16});

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLogoSelection.current,
      builder: (context, selectedId, _) {
        final option = AppLogos.byId(selectedId);
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.asset(
            option.assetPath,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: size,
              height: size,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.health_and_safety_outlined),
            ),
          ),
        );
      },
    );
  }
}
