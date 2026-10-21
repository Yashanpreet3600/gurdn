import '../../../core/services/supabase_service.dart';

/// Safety Radar: the places other people have flagged as unsafe near you,
/// and a way to add your own flag. The raw reports are never readable — the
/// map comes from an aggregate that only shows a spot once several different
/// people have reported it (see the unsafe_spots SQL function).
class RadarRepository {
  RadarRepository._();
  static final instance = RadarRepository._();

  /// Hot-spots within [radiusKm] of a point. Each is a rough ~110 m cell
  /// with a reporter count and the most common reason — never user ids.
  Future<List<UnsafeSpot>> nearby(double lat, double lng, {double radiusKm = 3}) async {
    final data = await SupabaseService.client.rpc('unsafe_spots', params: {
      'p_lat': lat,
      'p_lng': lng,
      'p_radius_km': radiusKm,
    });
    return (data as List)
        .map((e) => UnsafeSpot.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Flag a place as unsafe. The location is rounded to ~110 m before it's
  /// stored, so a report can't pinpoint an exact address.
  Future<void> report({
    required double lat,
    required double lng,
    required String reason,
    bool night = true,
  }) async {
    double round3(double v) => (v * 1000).roundToDouble() / 1000;
    try {
      await SupabaseService.client.from('unsafe_reports').insert({
        'user_id': SupabaseService.uid,
        'lat': round3(lat),
        'lng': round3(lng),
        'reason': reason,
        'time_of_day': night ? 'night' : 'day',
      });
    } catch (e) {
      // A duplicate (same user, same cell, same reason) is fine — already flagged.
      if (!e.toString().contains('duplicate')) rethrow;
    }
  }

  /// Report reasons the user can choose from (match the DB check).
  static const reasons = ['dark', 'harassment', 'isolated', 'traffic', 'animals', 'other'];
}

class UnsafeSpot {
  const UnsafeSpot({
    required this.lat,
    required this.lng,
    required this.reporters,
    required this.reason,
    required this.mostlyNight,
  });

  final double lat;
  final double lng;
  final int reporters;
  final String reason;
  final bool mostlyNight;

  factory UnsafeSpot.fromMap(Map<String, dynamic> m) => UnsafeSpot(
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        reporters: (m['reporters'] as num).toInt(),
        reason: m['reason'] as String? ?? 'other',
        mostlyNight: (m['mostly_night'] as bool?) ?? false,
      );
}
