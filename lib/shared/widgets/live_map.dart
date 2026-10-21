import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A small map showing where someone is now, their recent trail, and a
/// circle for GPS accuracy. Uses OpenStreetMap raster tiles (free, no key).
///
/// Marker colours and the camera follow [current]; pass [points] for the
/// trail. When [current] is null it shows "no location yet".
class LiveMap extends StatefulWidget {
  const LiveMap({
    super.key,
    required this.current,
    this.points = const [],
    this.accuracyMeters,
    this.markerColor,
    this.height = 260,
    this.extraMarkers = const [],
    this.hazards = const [],
  });

  final LatLng? current;
  final List<LatLng> points;
  final double? accuracyMeters;
  final Color? markerColor;
  final double height;

  /// Optional pins, e.g. the nearest police station and hospital.
  final List<MapPin> extraMarkers;

  /// Optional hazard areas (Safety Radar unsafe spots), drawn as circles.
  final List<MapHazard> hazards;

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> {
  final _controller = MapController();
  LatLng? _lastCentered;

  // OpenStreetMap standard tiles. userAgentPackageName is required by their
  // usage policy so the traffic is identifiable.
  static const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _userAgent = 'com.dailytools.app';

  @override
  void didUpdateWidget(LiveMap old) {
    super.didUpdateWidget(old);
    final c = widget.current;
    // Re-centre only when the point actually moved, so the user can still pan.
    if (c != null && (_lastCentered == null || _distance(c, _lastCentered!) > 20)) {
      _lastCentered = c;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _controller.move(c, _controller.camera.zoom.clamp(14, 18));
        } catch (_) {}
      });
    }
  }

  double _distance(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180, lat2 = b.latitude * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    final color = widget.markerColor ?? Theme.of(context).colorScheme.error;

    if (current == null) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(MaterialLocalizations.of(context).searchFieldLabel == ''
            ? 'No location yet'
            : 'No location yet'),
      );
    }

    return SizedBox(
      height: widget.height,
      child: FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter: current,
          initialZoom: 16,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
          ),
        ),
        children: [
          TileLayer(urlTemplate: _tileUrl, userAgentPackageName: _userAgent, maxZoom: 19),
          if (widget.hazards.isNotEmpty)
            CircleLayer(circles: [
              for (final h in widget.hazards)
                CircleMarker(
                  point: h.point,
                  radius: 70,
                  useRadiusInMeter: true,
                  color: h.color.withValues(alpha: 0.22),
                  borderColor: h.color.withValues(alpha: 0.6),
                  borderStrokeWidth: 1,
                ),
            ]),
          if (widget.accuracyMeters != null)
            CircleLayer(circles: [
              CircleMarker(
                point: current,
                radius: widget.accuracyMeters!.clamp(15, 500),
                useRadiusInMeter: true,
                color: color.withValues(alpha: 0.12),
                borderColor: color.withValues(alpha: 0.4),
                borderStrokeWidth: 1,
              ),
            ]),
          if (widget.points.length > 1)
            PolylineLayer(polylines: [
              Polyline(points: widget.points, strokeWidth: 4, color: color.withValues(alpha: 0.6)),
            ]),
          MarkerLayer(markers: [
            for (final pin in widget.extraMarkers)
              Marker(
                point: pin.point,
                width: 36,
                height: 36,
                child: Tooltip(message: pin.label, child: Icon(pin.icon, color: pin.color, size: 30)),
              ),
            Marker(
              point: current,
              width: 24,
              height: 24,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                ),
              ),
            ),
          ]),
          const RichAttributionWidget(attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ]),
        ],
      ),
    );
  }
}

class MapHazard {
  const MapHazard({required this.point, required this.color});
  final LatLng point;
  final Color color;
}

class MapPin {
  const MapPin({required this.point, required this.label, required this.icon, required this.color});
  final LatLng point;
  final String label;
  final IconData icon;
  final Color color;
}
