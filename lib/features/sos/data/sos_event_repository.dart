import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/local_store.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/id_utils.dart';
import '../models/sos_event.dart';
import '../models/sos_session.dart';
import '../services/location_service.dart';

/// Saves SOS events to Supabase. Without internet, every change is kept in
/// an offline queue on the phone and uploaded in order when the network returns.
class SosEventRepository {
  SosEventRepository._();
  static final instance = SosEventRepository._();

  static const _timeout = Duration(seconds: 8);

  SupabaseClient get _db => SupabaseService.client;

  static String _now() => DateTime.now().toUtc().toIso8601String();

  // ---- Writes (queued when offline) ----

  Future<bool> create(SosSession s, GxPosition? p, int? battery) => _run({
        'op': 'upsert',
        'table': 'sos_events',
        'data': {
          'id': s.eventId,
          'user_id': SupabaseService.uid,
          'level': s.level,
          'status': 'active',
          'is_test': s.isTest,
          'session_token': s.token,
          'start_lat': p?.lat,
          'start_lng': p?.lng,
          'last_lat': p?.lat,
          'last_lng': p?.lng,
          'last_accuracy_m': p?.accuracy,
          'battery_percent': battery,
          'started_at': s.startedAt.toUtc().toIso8601String(),
        },
      });

  Future<bool> update(String eventId, Map<String, dynamic> data) =>
      _run({'op': 'update', 'table': 'sos_events', 'id': eventId, 'data': data});

  Future<bool> markEnded(String eventId) => update(eventId, {'status': 'ended', 'ended_at': _now()});

  Future<bool> markDuress(String eventId) => update(eventId, {'status': 'duress', 'duress_at': _now()});

  Future<bool> markEscalated(String eventId) => update(eventId, {'escalated_at': _now()});

  /// One step of the response timeline (used for the incident report in Phase 5).
  Future<bool> addTimeline(String eventId, String kind, [Map<String, dynamic>? detail]) => _run({
        'op': 'upsert',
        'table': 'sos_timeline',
        'data': {
          'id': Ids.uuid(),
          'event_id': eventId,
          'user_id': SupabaseService.uid,
          'kind': kind,
          'detail': detail ?? <String, dynamic>{},
          'at': _now(),
        },
      });

  // ---- Check-in signal ----

  /// Tells the server the phone is still alive. If these stop for 90 seconds,
  /// the server marks the SOS as "phone offline".
  Future<bool> heartbeat(String eventId, GxPosition? p, int? battery) async {
    try {
      // False while the event is still waiting in the offline queue.
      final found = await _db.rpc('sos_heartbeat', params: {
        'p_event': eventId,
        'p_lat': p?.lat,
        'p_lng': p?.lng,
        'p_accuracy': p?.accuracy,
        'p_battery': battery,
      }).timeout(_timeout);
      return found == true;
    } catch (_) {
      return false;
    }
  }

  /// True if any guardian opened the alert page (written by the guardian app and web page from Phase 3).
  Future<bool> anyGuardianResponded(String eventId) async {
    try {
      final rows = await _db
          .from('guardian_views')
          .select('id')
          .eq('event_id', eventId)
          .limit(1)
          .timeout(_timeout);
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ---- History ----

  Future<List<SosEventSummary>> history() async {
    final rows = await _db
        .from('sos_events')
        .select('id, level, status, is_test, started_at, ended_at, escalated_at, duress_at')
        .eq('user_id', SupabaseService.uid)
        .order('started_at', ascending: false)
        .limit(50);
    return rows.map(SosEventSummary.fromMap).toList();
  }

  // ---- Offline queue ----

  bool get hasPending => _queue.isNotEmpty;

  /// Runs now if possible, otherwise queues. Returns true if it reached the server.
  Future<bool> _run(Map<String, dynamic> op) async {
    if (_queue.isNotEmpty) {
      // Keep the order: anything new waits behind what's already queued.
      await _enqueue(op);
      return flushQueue();
    }
    try {
      await _apply(op).timeout(_timeout);
      return true;
    } on PostgrestException {
      // The server answered but refused (bad data). Retrying won't help.
      return false;
    } catch (_) {
      await _enqueue(op);
      return false;
    }
  }

  bool _flushing = false;

  /// Uploads queued changes in order. Returns true when nothing is left.
  Future<bool> flushQueue() async {
    if (_flushing) return false;
    _flushing = true;
    try {
      final queue = _queue;
      while (queue.isNotEmpty) {
        try {
          await _apply(queue.first).timeout(_timeout);
        } on PostgrestException {
          // Refused by the server: drop it so it can't block the rest.
        } catch (_) {
          return false; // still offline
        }
        queue.removeAt(0);
        await _saveQueue(queue);
      }
      return true;
    } finally {
      _flushing = false;
    }
  }

  Future<void> _apply(Map<String, dynamic> op) async {
    final table = op['table'] as String;
    final data = Map<String, dynamic>.from(op['data'] as Map);
    switch (op['op']) {
      case 'upsert':
        await _db.from(table).upsert(data);
      case 'update':
        await _db.from(table).update(data).eq('id', op['id'] as String);
    }
  }

  List<Map<String, dynamic>> get _queue {
    final raw = LocalStore.getString(LocalKeys.sosQueue);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _enqueue(Map<String, dynamic> op) async {
    final queue = _queue..add(op);
    await _saveQueue(queue);
  }

  Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    await LocalStore.setString(LocalKeys.sosQueue, jsonEncode(queue));
  }
}
