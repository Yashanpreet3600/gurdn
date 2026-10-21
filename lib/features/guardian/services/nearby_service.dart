import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// Finds the nearest police station and hospital to a location, so a
/// guardian knows who to call near the person in trouble.
///
/// Uses OpenStreetMap's Overpass API (free, no key). It can be slow or
/// rate-limited, so this is best-effort: a failure just means no pins.
class NearbyService {
  NearbyService._();
  static final instance = NearbyService._();

  // Public Overpass endpoints; we try them in order.
  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  List<NearbyPlace>? _cache;
  double? _cacheLat, _cacheLng;

  /// Nearest police and hospital within ~5 km. Returns at most one of each.
  Future<List<NearbyPlace>> nearest(double lat, double lng) async {
    // Reuse the last result if the location barely moved.
    if (_cache != null &&
        _cacheLat != null &&
        _haversine(lat, lng, _cacheLat!, _cacheLng!) < 300) {
      return _cache!;
    }

    // One query for both, within 5000 m.
    final query = '''
[out:json][timeout:20];
(
  node["amenity"="police"](around:5000,$lat,$lng);
  way["amenity"="police"](around:5000,$lat,$lng);
  node["amenity"="hospital"](around:5000,$lat,$lng);
  way["amenity"="hospital"](around:5000,$lat,$lng);
);
out center tags 30;
''';

    for (final url in _endpoints) {
      try {
        final res = await http
            .post(Uri.parse(url), body: {'data': query})
            .timeout(const Duration(seconds: 20));
        if (res.statusCode != 200) continue;
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final elements = (data['elements'] as List?) ?? [];
        final places = <NearbyPlace>[];
        for (final e in elements.cast<Map<String, dynamic>>()) {
          final tags = (e['tags'] as Map?)?.cast<String, dynamic>() ?? {};
          final amenity = tags['amenity'] as String?;
          if (amenity != 'police' && amenity != 'hospital') continue;
          final plat = (e['lat'] ?? e['center']?['lat']) as num?;
          final plng = (e['lon'] ?? e['center']?['lon']) as num?;
          if (plat == null || plng == null) continue;
          places.add(NearbyPlace(
            kind: amenity == 'police' ? 'police' : 'hospital',
            name: (tags['name'] as String?) ??
                (amenity == 'police' ? 'Police station' : 'Hospital'),
            lat: plat.toDouble(),
            lng: plng.toDouble(),
            phone: (tags['phone'] ?? tags['contact:phone']) as String?,
            distanceMeters: _haversine(lat, lng, plat.toDouble(), plng.toDouble()).round(),
          ));
        }
        // Closest police + closest hospital.
        final result = <NearbyPlace>[];
        for (final kind in ['police', 'hospital']) {
          final of = places.where((p) => p.kind == kind).toList()
            ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
          if (of.isNotEmpty) result.add(of.first);
        }
        _cache = result;
        _cacheLat = lat;
        _cacheLng = lng;
        return result;
      } catch (_) {
        // try the next endpoint
      }
    }
    return const [];
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }
}

class NearbyPlace {
  const NearbyPlace({
    required this.kind,
    required this.name,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    this.phone,
  });

  final String kind; // 'police' | 'hospital'
  final String name;
  final double lat;
  final double lng;
  final int distanceMeters;
  final String? phone;
}
