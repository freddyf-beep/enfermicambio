import 'dart:async';
import 'dart:math' as math;

import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;

import '../../../shared/ui/async_state_view.dart';
import '../../../shared/ui/async_view_status.dart';
import '../domain/workout_models.dart';

/// Native route map abstraction. iOS uses MapKit through apple_maps_flutter;
/// Android uses Google Maps. The public API stays deliberately small so the
/// recorder and workout detail never depend on a platform map package.
class RouteMapView extends StatefulWidget {
  const RouteMapView({super.key, required this.points, this.height = 240});

  final List<RoutePoint> points;
  final double height;

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  google.GoogleMapController? _googleController;
  apple.AppleMapController? _appleController;

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void didUpdateWidget(covariant RouteMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.points.length == oldWidget.points.length ||
        widget.points.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recenterOnLatest();
    });
  }

  List<List<RoutePoint>> get _segments {
    final grouped = <int, List<RoutePoint>>{};
    for (final point in widget.points) {
      grouped.putIfAbsent(point.segmentIndex, () => []).add(point);
    }
    return grouped.values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const AsyncStateView(
          status: AsyncViewStatus.empty(
            'La ruta aparecerá cuando el GPS obtenga una señal precisa.',
          ),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _isIOS ? _buildAppleMap() : _buildGoogleMap(),
      ),
    );
  }

  Widget _buildGoogleMap() {
    final points = widget.points
        .map((point) => google.LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    final last = points.last;
    final polylines = <google.Polyline>{};
    for (var i = 0; i < _segments.length; i++) {
      final segment = _segments[i]
          .map((point) => google.LatLng(point.latitude, point.longitude))
          .toList(growable: false);
      if (segment.length < 2) continue;
      polylines.add(
        google.Polyline(
          polylineId: google.PolylineId('route-segment-$i'),
          points: segment,
          color: const Color(0xffd7ff00),
          width: 5,
          jointType: google.JointType.round,
          startCap: google.Cap.roundCap,
          endCap: google.Cap.roundCap,
        ),
      );
    }

    return google.GoogleMap(
      initialCameraPosition: google.CameraPosition(
        target: _googleCenter(points),
        zoom: _zoomForSpan(widget.points),
      ),
      mapType: google.MapType.normal,
      style: _darkGoogleMapStyle,
      compassEnabled: true,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      markers: {
        google.Marker(
          markerId: const google.MarkerId('route-start'),
          position: points.first,
          icon: google.BitmapDescriptor.defaultMarkerWithHue(
            google.BitmapDescriptor.hueGreen,
          ),
          infoWindow: const google.InfoWindow(title: 'Inicio'),
        ),
        google.Marker(
          markerId: const google.MarkerId('route-end'),
          position: last,
          icon: google.BitmapDescriptor.defaultMarkerWithHue(
            google.BitmapDescriptor.hueRed,
          ),
          infoWindow: const google.InfoWindow(title: 'Fin'),
        ),
      },
      polylines: polylines,
      onMapCreated: (controller) {
        _googleController = controller;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitGoogleMap();
        });
      },
    );
  }

  Widget _buildAppleMap() {
    final points = widget.points
        .map((point) => apple.LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    final polylines = <apple.Polyline>{};
    for (var i = 0; i < _segments.length; i++) {
      final segment = _segments[i]
          .map((point) => apple.LatLng(point.latitude, point.longitude))
          .toList(growable: false);
      if (segment.length < 2) continue;
      polylines.add(
        apple.Polyline(
          polylineId: apple.PolylineId('route-segment-$i'),
          points: segment,
          color: const Color(0xffd7ff00),
          width: 8,
          polylineCap: apple.Cap.roundCap,
        ),
      );
    }

    return apple.AppleMap(
      initialCameraPosition: apple.CameraPosition(
        target: _appleCenter(points),
        zoom: _zoomForSpan(widget.points),
      ),
      mapType: apple.MapType.standard,
      compassEnabled: true,
      annotations: {
        apple.Annotation(
          annotationId: apple.AnnotationId('route-start'),
          position: points.first,
          infoWindow: const apple.InfoWindow(title: 'Inicio'),
        ),
        apple.Annotation(
          annotationId: apple.AnnotationId('route-end'),
          position: points.last,
          infoWindow: const apple.InfoWindow(title: 'Fin'),
        ),
      },
      polylines: polylines,
      onMapCreated: (controller) {
        _appleController = controller;
      },
    );
  }

  void _recenterOnLatest() {
    if (_isIOS) {
      final controller = _appleController;
      if (controller == null) return;
      final points = widget.points;
      final last = points.last;
      unawaited(
        controller.animateCamera(
          apple.CameraUpdate.newLatLngZoom(
            apple.LatLng(last.latitude, last.longitude),
            _zoomForSpan(points),
          ),
        ),
      );
      return;
    }
    _fitGoogleMap();
  }

  Future<void> _fitGoogleMap() async {
    final controller = _googleController;
    if (controller == null || widget.points.isEmpty) return;
    final points = widget.points
        .map((point) => google.LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    try {
      if (points.length < 2 || _samePoint(points.first, points.last)) {
        await controller.animateCamera(
          google.CameraUpdate.newLatLngZoom(
            points.last,
            _zoomForSpan(widget.points),
          ),
        );
        return;
      }
      await controller.animateCamera(
        google.CameraUpdate.newLatLngBounds(_googleBounds(points), 48),
      );
    } on Object {
      // The native map can reject bounds while it is still laying out. The
      // latest point remains a safe fallback and will be used on the next GPS
      // sample.
      await controller.animateCamera(
        google.CameraUpdate.newLatLngZoom(
          points.last,
          _zoomForSpan(widget.points),
        ),
      );
    }
  }

  google.LatLng _googleCenter(List<google.LatLng> points) {
    final bounds = _googleBounds(points);
    return google.LatLng(
      (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
      (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
    );
  }

  google.LatLngBounds _googleBounds(List<google.LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLon = points.first.longitude;
    var maxLon = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLon = math.min(minLon, point.longitude);
      maxLon = math.max(maxLon, point.longitude);
    }
    return google.LatLngBounds(
      southwest: google.LatLng(minLat, minLon),
      northeast: google.LatLng(maxLat, maxLon),
    );
  }

  apple.LatLng _appleCenter(List<apple.LatLng> points) {
    var latitude = 0.0;
    var longitude = 0.0;
    for (final point in points) {
      latitude += point.latitude;
      longitude += point.longitude;
    }
    return apple.LatLng(latitude / points.length, longitude / points.length);
  }

  double _zoomForSpan(List<RoutePoint> points) {
    if (points.length < 2) return 16;
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLon = points.first.longitude;
    var maxLon = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLon = math.min(minLon, point.longitude);
      maxLon = math.max(maxLon, point.longitude);
    }
    final span = math.max(maxLat - minLat, maxLon - minLon);
    if (span < 0.0001) return 16;
    return (14 - math.log(span * 10000) / math.ln2).clamp(8, 17).toDouble();
  }

  bool _samePoint(google.LatLng first, google.LatLng second) =>
      (first.latitude - second.latitude).abs() < 0.0000001 &&
      (first.longitude - second.longitude).abs() < 0.0000001;
}

const _darkGoogleMapStyle = '''[
  {"elementType":"geometry","stylers":[{"color":"#18232b"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#c5d1d8"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#18232b"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2e414d"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0a2433"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#21333d"}]}
]''';
