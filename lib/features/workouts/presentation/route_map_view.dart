import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import '../domain/workout_models.dart';

class RouteMapView extends StatelessWidget {
  const RouteMapView({super.key, required this.points, this.height = 240});

  final List<RoutePoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: const AsyncStateView(
          status: AsyncViewStatus.empty(
            'La ruta aparecerá cuando el GPS obtenga una señal precisa.',
          ),
        ),
      );
    }

    final latLngs = points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);

    final bounds = LatLngBounds.fromPoints(latLngs);

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: latLngs.first,
            initialZoom: 14,
            initialCameraFit: latLngs.length > 1
                ? CameraFit.bounds(bounds: bounds)
                : null,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.enfermicambio.enfermicambio',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: latLngs,
                  strokeWidth: 4,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: latLngs.first,
                  width: 28,
                  height: 28,
                  child: const Icon(
                    Icons.circle,
                    color: Color(0xff2e7d32),
                    size: 18,
                  ),
                ),
                Marker(
                  point: latLngs.last,
                  width: 28,
                  height: 28,
                  child: const Icon(
                    Icons.flag,
                    color: Color(0xffc62828),
                    size: 20,
                  ),
                ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
