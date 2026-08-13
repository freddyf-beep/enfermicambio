import 'dart:io';

import 'package:flutter/services.dart';

class LauncherIconResult {
  const LauncherIconResult({required this.changed, required this.message});

  final bool changed;
  final String message;
}

/// Bridges the in-app logo choice to platform launcher icon facilities.
/// iOS presents its system confirmation itself; Android refreshes the alias.
class LauncherIconService {
  const LauncherIconService();

  static const _channel = MethodChannel('enfermicambio/launcher_icon');

  Future<LauncherIconResult> setLogo(String logoId) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return const LauncherIconResult(
        changed: false,
        message: 'Este dispositivo no permite cambiar el icono de inicio.',
      );
    }
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'setLauncherIcon',
        {'logoId': logoId},
      );
      return LauncherIconResult(
        changed: response?['changed'] == true,
        message: (response?['message'] as String?) ?? 'Icono actualizado.',
      );
    } on PlatformException catch (error) {
      return LauncherIconResult(
        changed: false,
        message: error.message ?? 'No se pudo cambiar el icono de inicio.',
      );
    } on MissingPluginException {
      return const LauncherIconResult(
        changed: false,
        message:
            'Esta versión instalada todavía no incluye iconos alternativos.',
      );
    }
  }
}
