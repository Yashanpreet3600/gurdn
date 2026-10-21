import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';

/// Carries the small WebRTC setup messages (offer, answer, ICE candidates,
/// and remote-control commands) between the two phones, over the
/// rtc_signals table + Supabase Realtime. No signaling server to run.
class RtcSignaling {
  RtcSignaling({required this.eventId, required this.role});

  final String eventId;
  final String role; // 'broadcaster' | 'viewer'

  SupabaseClient get _db => SupabaseService.client;
  RealtimeChannel? _channel;
  final _incoming = StreamController<RtcSignal>.broadcast();
  int _lastId = 0;

  /// Signals addressed to us (i.e. from the other role).
  Stream<RtcSignal> get signals => _incoming.stream;

  String get _otherRole => role == 'broadcaster' ? 'viewer' : 'broadcaster';

  /// Start listening. Picks up anything already waiting, then live updates.
  Future<void> connect() async {
    // Catch up on messages sent before we joined.
    final existing = await _db
        .from('rtc_signals')
        .select()
        .eq('event_id', eventId)
        .eq('role', _otherRole)
        .order('id', ascending: true);
    for (final row in existing) {
      _emit(Map<String, dynamic>.from(row));
    }

    _channel = _db
        .channel('rtc:$eventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'rtc_signals',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: eventId,
          ),
          callback: (payload) => _emit(payload.newRecord),
        )
        .subscribe();
  }

  void _emit(Map<String, dynamic> row) {
    final id = (row['id'] as num?)?.toInt() ?? 0;
    if (row['role'] == role) return; // ignore our own
    if (id != 0 && id <= _lastId) return; // de-dupe
    if (id != 0) _lastId = id;
    _incoming.add(RtcSignal(
      kind: row['kind'] as String,
      payload: (row['payload'] as Map).cast<String, dynamic>(),
    ));
  }

  /// Send one signal to the other side.
  Future<void> send(String kind, Map<String, dynamic> payload) async {
    try {
      await _db.from('rtc_signals').insert({
        'event_id': eventId,
        'sender': SupabaseService.uid,
        'role': role,
        'kind': kind,
        'payload': payload,
      });
    } catch (_) {
      // A dropped signal just slows connection; the peer retries ICE.
    }
  }

  /// Fetch ICE servers (TURN) from the Worker, falling back to public STUN.
  Future<List<Map<String, dynamic>>> iceServers() async {
    const fallback = [
      {'urls': 'stun:stun.cloudflare.com:3478'},
      {'urls': 'stun:stun.l.google.com:19302'},
    ];
    if (!AppConfig.hasWorker) return fallback;
    final token = _db.auth.currentSession?.accessToken;
    if (token == null) return fallback;
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.workerBase}/turn'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return fallback;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final ice = data['iceServers'];
      // Cloudflare returns a single object with urls+username+credential.
      if (ice is Map) return [Map<String, dynamic>.from(ice)];
      if (ice is List) return ice.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> dispose() async {
    await send('bye', {});
    if (_channel != null) await _db.removeChannel(_channel!);
    await _incoming.close();
  }
}

class RtcSignal {
  RtcSignal({required this.kind, required this.payload});
  final String kind; // offer | answer | ice | bye | control
  final Map<String, dynamic> payload;
}
