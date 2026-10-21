import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

/// What a guardian can do: watch a protected person's active SOS and say
/// what they're doing about it.
class GuardianRepository {
  GuardianRepository._();
  static final instance = GuardianRepository._();

  SupabaseClient get _db => SupabaseService.client;

  /// The most recent still-active SOS for one of the people this guardian
  /// protects, or null if none is running. Guardians can read these rows
  /// because of the Phase 1 "is_guardian_of" policy.
  Future<GuardianAlert?> activeAlertFor(String ownerUserId) async {
    final rows = await _db
        .from('sos_events')
        .select('id, user_id, level, status, is_test, started_at, '
            'last_lat, last_lng, last_accuracy_m, battery_percent, '
            'last_heartbeat_at, reason_meta')
        .eq('user_id', ownerUserId)
        .inFilter('status', ['active', 'duress', 'phone_offline'])
        .order('started_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return GuardianAlert.fromMap(rows.first);
  }

  /// Any active SOS among all the people this guardian protects.
  Future<List<GuardianAlert>> allActiveAlerts() async {
    final rows = await _db
        .from('sos_events')
        .select('id, user_id, level, status, is_test, started_at, '
            'last_lat, last_lng, last_accuracy_m, battery_percent, '
            'last_heartbeat_at, reason_meta, profiles(full_name)')
        .inFilter('status', ['active', 'duress', 'phone_offline'])
        .order('started_at', ascending: false);
    return rows.map(GuardianAlert.fromMap).toList();
  }

  /// The route so far, oldest first, for drawing a trail on the map.
  Future<List<TrackPoint>> route(String eventId) async {
    final rows = await _db
        .from('sos_locations')
        .select('lat, lng, at')
        .eq('event_id', eventId)
        .order('at', ascending: true)
        .limit(500);
    return rows.map(TrackPoint.fromMap).toList();
  }

  /// "I'm on my way" / "Calling police" / "Can't help right now".
  Future<void> respond(String eventId, String? response) async {
    await _db.rpc('set_guardian_response',
        params: {'p_event': eventId, 'p_response': response});
  }

  /// This guardian's own current response to an event, if any.
  Future<String?> myResponse(String eventId) async {
    final rows = await _db
        .from('guardian_views')
        .select('response')
        .eq('event_id', eventId)
        .eq('guardian_user_id', SupabaseService.uid)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first['response'] as String?;
  }

  /// Everyone's responses (for "2 responding"), without names.
  Future<Map<String, int>> responderTally(String eventId) async {
    final rows = await _db
        .from('guardian_views')
        .select('response')
        .eq('event_id', eventId)
        .not('response', 'is', null);
    final tally = <String, int>{};
    for (final r in rows) {
      final key = r['response'] as String;
      tally[key] = (tally[key] ?? 0) + 1;
    }
    return tally;
  }
}

/// A live SOS as a guardian sees it.
class GuardianAlert {
  const GuardianAlert({
    required this.eventId,
    required this.ownerUserId,
    required this.ownerName,
    required this.level,
    required this.status,
    required this.isTest,
    required this.startedAt,
    this.lat,
    this.lng,
    this.accuracyM,
    this.battery,
    this.lastHeartbeatAt,
    this.reasonMeta,
  });

  final String eventId;
  final String ownerUserId;
  final String ownerName;
  final int level;
  final String status;
  final bool isTest;
  final DateTime startedAt;
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final int? battery;
  final DateTime? lastHeartbeatAt;
  final Map<String, dynamic>? reasonMeta;

  bool get phoneOffline => status == 'phone_offline';
  bool get isDuress => status == 'duress';

  /// Why the alert fired, if a safety timer caused it.
  String? get source => reasonMeta?['source'] as String?;

  factory GuardianAlert.fromMap(Map<String, dynamic> m) {
    final owner = (m['profiles'] as Map<String, dynamic>?) ?? const {};
    return GuardianAlert(
      eventId: m['id'] as String,
      ownerUserId: m['user_id'] as String,
      ownerName: (owner['full_name'] as String?) ?? '',
      level: (m['level'] as num?)?.toInt() ?? 3,
      status: m['status'] as String? ?? 'active',
      isTest: (m['is_test'] as bool?) ?? false,
      startedAt: DateTime.parse(m['started_at'] as String),
      lat: (m['last_lat'] as num?)?.toDouble(),
      lng: (m['last_lng'] as num?)?.toDouble(),
      accuracyM: (m['last_accuracy_m'] as num?)?.toDouble(),
      battery: (m['battery_percent'] as num?)?.toInt(),
      lastHeartbeatAt: m['last_heartbeat_at'] == null
          ? null
          : DateTime.parse(m['last_heartbeat_at'] as String),
      reasonMeta: (m['reason_meta'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

class TrackPoint {
  const TrackPoint(this.lat, this.lng, this.at);
  final double lat;
  final double lng;
  final DateTime at;

  factory TrackPoint.fromMap(Map<String, dynamic> m) => TrackPoint(
        (m['lat'] as num).toDouble(),
        (m['lng'] as num).toDouble(),
        DateTime.parse(m['at'] as String),
      );
}

/// Guardian response options (keys match the database check + the SMS).
const guardianResponses = ['on_my_way', 'calling_police', 'cant_help'];
