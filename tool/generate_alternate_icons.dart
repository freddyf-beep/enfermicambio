import 'dart:io';

import 'package:image/image.dart' as image;

const _variants = <String, String>{
  'red_transparent': 'assets/logos/logo-red-transparent.png',
  'red_cropped': 'assets/logos/logo-red-cropped.png',
  'medical_cropped': 'assets/logos/logo-medical-cropped.png',
};

const _iosNames = <String, String>{
  'red_transparent': 'AppIconRedTransparent',
  'red_cropped': 'AppIconRedCropped',
  'medical_cropped': 'AppIconMedicalCropped',
};

Future<void> main() async {
  final iosTemplate = Directory(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset',
  );
  final androidTemplate = Directory('android/app/src/main/res');
  for (final variant in _variants.entries) {
    final source = image.decodeImage(await File(variant.value).readAsBytes());
    if (source == null) throw StateError('No se pudo leer ${variant.value}');

    final iosName = _iosNames[variant.key]!;
    final destination = Directory(
      'ios/Runner/Assets.xcassets/$iosName.appiconset',
    );
    await destination.create(recursive: true);
    await File('${destination.path}/Contents.json').writeAsBytes(
      await File('${iosTemplate.path}/Contents.json').readAsBytes(),
    );
    await for (final file in iosTemplate.list()) {
      if (file is! File || !file.path.endsWith('.png')) continue;
      final original = image.decodeImage(await file.readAsBytes());
      if (original == null) continue;
      final scaled = image.copyResize(
        source,
        width: original.width,
        height: original.height,
      );
      await File(
        '${destination.path}/${file.uri.pathSegments.last}',
      ).writeAsBytes(image.encodePng(scaled));
    }

    await for (final folder in androidTemplate.list()) {
      if (folder is! Directory || !folder.path.contains('mipmap-')) continue;
      final template = File(
        '${folder.path}${Platform.pathSeparator}ic_launcher.png',
      );
      if (!await template.exists()) continue;
      final original = image.decodeImage(await template.readAsBytes());
      if (original == null) continue;
      final scaled = image.copyResize(
        source,
        width: original.width,
        height: original.height,
      );
      await File(
        '${folder.path}${Platform.pathSeparator}ic_launcher_${variant.key}.png',
      ).writeAsBytes(image.encodePng(scaled));
    }
  }
}
