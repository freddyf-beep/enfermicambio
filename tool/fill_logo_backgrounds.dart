import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

const _targets = <String>[
  'assets/logos/logo-red-cropped.png',
  'assets/logos/logo-medical-cropped.png',
];

Future<void> main() async {
  for (final path in _targets) {
    final source = image.decodeImage(await File(path).readAsBytes());
    if (source == null) throw StateError('No se pudo leer $path');

    final output = image.Image(
      width: source.width,
      height: source.height,
      numChannels: 4,
    );
    final exterior = _exteriorBlackMask(source);
    for (var y = 0; y < source.height; y++) {
      final vertical = source.height <= 1 ? 0.0 : y / (source.height - 1);
      for (var x = 0; x < source.width; x++) {
        final horizontal = source.width <= 1 ? 0.0 : x / (source.width - 1);
        final original = source.getPixel(x, y);
        final alpha = original.a.toInt().clamp(0, 255);

        // Teal on the upper-left and a stronger blue on the lower-right,
        // matching the primary EnfermiCambio launcher icon.
        final mix = (horizontal * 0.62 + vertical * 0.38).clamp(0.0, 1.0);
        final blueR = _lerp(7, 0, mix);
        final blueG = _lerp(188, 112, mix);
        final blueB = _lerp(193, 244, mix);

        if (exterior[y * source.width + x] != 0) {
          output.setPixelRgba(x, y, blueR, blueG, blueB, 255);
          continue;
        }
        if (alpha == 255) {
          output.setPixelRgba(
            x,
            y,
            original.r.toInt(),
            original.g.toInt(),
            original.b.toInt(),
            255,
          );
          continue;
        }

        final foreground = alpha / 255.0;
        output.setPixelRgba(
          x,
          y,
          _blend(original.r.toInt(), blueR, foreground),
          _blend(original.g.toInt(), blueG, foreground),
          _blend(original.b.toInt(), blueB, foreground),
          255,
        );
      }
    }

    await File(path).writeAsBytes(image.encodePng(output));
  }
}

Uint8List _exteriorBlackMask(image.Image source) {
  final width = source.width;
  final height = source.height;
  final mask = Uint8List(width * height);
  final queue = Queue<int>();

  bool isBackground(int x, int y) {
    final pixel = source.getPixel(x, y);
    if (pixel.a.toInt() < 8) return true;
    return pixel.r.toInt() <= 12 &&
        pixel.g.toInt() <= 12 &&
        pixel.b.toInt() <= 12;
  }

  void add(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    final index = y * width + x;
    if (mask[index] != 0 || !isBackground(x, y)) return;
    mask[index] = 1;
    queue.add(index);
  }

  for (var x = 0; x < width; x++) {
    add(x, 0);
    add(x, height - 1);
  }
  for (var y = 1; y < height - 1; y++) {
    add(0, y);
    add(width - 1, y);
  }

  while (queue.isNotEmpty) {
    final index = queue.removeFirst();
    final x = index % width;
    final y = index ~/ width;
    add(x - 1, y);
    add(x + 1, y);
    add(x, y - 1);
    add(x, y + 1);
  }
  return mask;
}

int _lerp(int start, int end, double amount) {
  return (start + (end - start) * amount).round().clamp(0, 255);
}

int _blend(int foreground, int background, double alpha) {
  return (foreground * alpha + background * (1 - alpha)).round().clamp(0, 255);
}
