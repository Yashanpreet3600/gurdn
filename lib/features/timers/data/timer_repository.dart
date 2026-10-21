import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../sos/services/location_service.dart';

/// Walk-home ("home in 20 min") and Trip mode (cab) timers. If the person
/// doesn't check in by the deadline plus a grace period, the SERVER starts
/// an SOS (see run_timer_watchdog). That's why a timer still protects you
/// even if your phone is dead when it expires.
class TimerRepository {
  TimerRepository._();
  static final instance = TimerRepository._();

  SupabaseClient get _db => SupabaseService.client;

  /// Start a timer. [minutes] is how long until the deadline; [graceSeconds]
  /// is the extra wait after that before an SOS fires.
  Future<SafetyTimer> start({
    required String kind, // 'walk_home' | 'trip'
    required int minutes,
    String? label,
    String? destination,
    String? evidencePath,
    int graceSeconds = 300,
  }) async {
    // A start location helps guardians and seeds the SOS if the phone dies.
    GxPosition? pos;
    try {
      pos = LocationService.instance.lastKnown ?? await LocationService.instance.precise(timeout: const Duration(seconds: 8));
    } catch (_) {}

    final due = DateTime.now().toUtc().add(Duration(minutes: minutes));
    final row = await _db
        .from('safety_timers')
        .insert({
          'user_id': SupabaseService.uid,
          'kind': kind,
          if (label != null && label.isNotEmpty) 'label': label,
          if (destination != null && destination.isNotEmpty) 'destination': destination,
          if (evidencePath != null) 'evidence_path': evidencePath,
          if (pos != null) 'start_lat': pos.lat,
          if (pos != null) 'start_lng': pos.lng,
          'due_at': due.toIso8601String(),
          'grace_seconds': graceSeconds,
        })
        .select()
        .single();
    return SafetyTimer.fromMap(row);
  }

  /// The one running timer, if any.
  Future<SafetyTimer?> active() async {
    final rows = await _db
        .from('safety_timers')
        .select()
        .eq('user_id', SupabaseService.uid)
        .eq('status', 'running')
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return SafetyTimer.fromMap(rows.first);
  }

  /// "I'm home / I arrived safely." Stops the timer.
  Future<void> checkIn(String id) async {
    await _db.from('safety_timers').update({
      'status': 'arrived',
      'resolved_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).eq('user_id', SupabaseService.uid);
  }

  /// Cancel without arriving (changed plans). Also stops the timer.
  Future<void> cancel(String id) async {
    await _db.from('safety_timers').update({
      'status': 'cancelled',
      'resolved_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).eq('user_id', SupabaseService.uid);
  }

  /// Add more time to a running timer (still walking / cab is slow).
  Future<SafetyTimer> extend(String id, int extraMinutes) async {
    final current = await active();
    final base = current?.dueAt ?? DateTime.now().toUtc();
    final newDue = base.add(Duration(minutes: extraMinutes));
    final row = await _db
        .from('safety_timers')
        .update({'due_at': newDue.toIso8601String()})
        .eq('id', id)
        .eq('user_id', SupabaseService.uid)
        .select()
        .single();
    return SafetyTimer.fromMap(row);
  }
}

class SafetyTimer {
  const SafetyTimer({
    required this.id,
    required this.kind,
    required this.dueAt,
    required this.graceSeconds,
    required this.status,
    this.label,
    this.destination,
    this.evidencePath,
  });

  final String id;
  final String kind;
  final DateTime dueAt;
  final int graceSeconds;
  final String status;
  final String? label;
  final String? destination;
  final String? evidencePath;

  bool get isTrip => kind == 'trip';

  /// Time left until the deadline (can be negative inside the grace period).
  Duration get remaining => dueAt.difference(DateTime.now().toUtc());

  factory SafetyTimer.fromMap(Map<String, dynamic> m) => SafetyTimer(
        id: m['id'] as String,
        kind: m['kind'] as String,
        dueAt: DateTime.parse(m['due_at'] as String),
        graceSeconds: (m['grace_seconds'] as num?)?.toInt() ?? 300,
        status: m['status'] as String? ?? 'running',
        label: m['label'] as String?,
        destination: m['destination'] as String?,
        evidencePath: m['evidence_path'] as String?,
      );
}
