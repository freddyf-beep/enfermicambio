import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../domain/workout_models.dart';

/// Creates a small branded route card for private feed storage. The full
/// route remains in the database and is rendered interactively in the detail.
class RoutePreviewService {
  const RoutePreviewService();

  Future<Uint8List> render(
    List<RoutePoint> points, {
    int width = 1200,
    int height = 675,
  }) async {
    if (points.isEmpty) {
      throw StateError('No se puede crear una preview sin puntos GPS.');
    }
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final size = ui.Size(width.toDouble(), height.toDouble());
    final background = ui.Paint()..color = const ui.Color(0xff07141f);
    canvas.drawRect(ui.Offset.zero & size, background);

    final minLat = points
        .map((p) => p.latitude)
        .reduce((a, b) => math.min(a, b).toDouble());
    final maxLat = points
        .map((p) => p.latitude)
        .reduce((a, b) => math.max(a, b).toDouble());
    final minLon = points
        .map((p) => p.longitude)
        .reduce((a, b) => math.min(a, b).toDouble());
    final maxLon = points
        .map((p) => p.longitude)
        .reduce((a, b) => math.max(a, b).toDouble());
    final latSpan = math.max(maxLat - minLat, 0.00001).toDouble();
    final lonSpan = math.max(maxLon - minLon, 0.00001).toDouble();
    const padding = 72.0;
    final drawableWidth = size.width - padding * 2;
    final drawableHeight = size.height - padding * 2;
    ui.Offset project(RoutePoint point) {
      final x = padding + (point.longitude - minLon) / lonSpan * drawableWidth;
      final y = padding + (maxLat - point.latitude) / latSpan * drawableHeight;
      return ui.Offset(x, y);
    }

    final grid = ui.Paint()
      ..color = const ui.Color(0xff12354a)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 1; i < 5; i++) {
      final x = padding + drawableWidth * i / 5;
      final y = padding + drawableHeight * i / 5;
      canvas.drawLine(
        ui.Offset(x, padding),
        ui.Offset(x, size.height - padding),
        grid,
      );
      canvas.drawLine(
        ui.Offset(padding, y),
        ui.Offset(size.width - padding, y),
        grid,
      );
    }

    final route = ui.Path();
    for (var i = 0; i < points.length; i++) {
      final position = project(points[i]);
      if (i == 0) {
        route.moveTo(position.dx, position.dy);
      } else {
        route.lineTo(position.dx, position.dy);
      }
    }
    final line = ui.Paint()
      ..color = const ui.Color(0xffd7ff00)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round;
    canvas.drawPath(route, line);
    canvas.drawCircle(
      project(points.first),
      18,
      ui.Paint()..color = const ui.Color(0xff2ecc71),
    );
    canvas.drawCircle(
      project(points.last),
      18,
      ui.Paint()..color = const ui.Color(0xffff5c5c),
    );

    final image = await recorder.endRecording().toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('No se pudo codificar la preview.');
    return data.buffer.asUint8List();
  }
}
