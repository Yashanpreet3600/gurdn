import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/local_store.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/sms_service.dart';

/// Push alerts for guardians, and the SMS relay they power.
///
/// When the server's watchdog sees a protected person's phone go silent,
/// it pushes to their guardians' phones. This service:
///   1. keeps this phone's FCM token registered on the server, and
///   2. when a relay push arrives, sends the share of SMS the server
///      assigned to this phone, from this phone's own SIM.
///
/// All of this is for the GUARDIAN side. A phone can be both a protected
/// person and someone's guardian, so every phone runs this.
class PushService {
  PushService._();
  static final instance = PushService._();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  SupabaseClient get _db => SupabaseService.client;

  bool _started = false;

  /// Call once after sign-in. Safe to call again.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    await _fcm.requestPermission();

    // Register now, and again whenever the token rotates.
    await _registerToken();
    _fcm.onTokenRefresh.listen((_) => _registerToken());

    // A relay push while the app is open.
    FirebaseMessaging.onMessage.listen(_onPush);
    // A relay push that opened the app from the background.
    FirebaseMessaging.onMessageOpenedApp.listen(_onPush);
    // One that arrived while the app was fully closed (handled at startup).
    final initial = await _fcm.getInitialMessage();
    if (initial != null) await _onPush(initial);
  }

  /// Whether this phone is allowed to relay alert SMS from its SIM.
  static bool get smsRelayEnabled => LocalStore.getBool(LocalKeys.smsRelayOptIn);

  /// Turn the SMS relay on or off (a guardian setting).
  Future<void> setSmsRelay(bool on) async {
    await LocalStore.setBool(LocalKeys.smsRelayOptIn, on);
    await _registerToken();
  }

  Future<void> _registerToken() async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      await _db.rpc('register_device', params: {
        'p_fcm_token': token,
        'p_platform': 'android',
        'p_sms_relay_ready': smsRelayEnabled,
      });
    } catch (_) {
      // Best effort: a failed registration just means no push until next try.
    }
  }

  /// A relay push: claim this phone's job and send its share of SMS.
  Future<void> _onPush(RemoteMessage message) async {
    final data = message.data;

    // A relay push also carries work: send this phone's share of SMS.
    if (data['type'] == 'sms_relay') {
      final jobId = data['job_id'] as String?;
      if (jobId != null && jobId.isNotEmpty) await _runRelayJob(jobId);
    }

    // Any alert push (relay or not) should open the alert screen, but only
    // when the user brought the app forward by tapping it — not silently.
    final eventId = data['event_id'] as String?;
    if (eventId != null && eventId.isNotEmpty && _openAlert != null) {
      _openAlert!(eventId, data['owner'] as String?);
    }
  }

  /// Set by the app once the navigator exists, so a tapped alert opens the
  /// alert screen. Kept as a callback so this service has no UI imports.
  void Function(String eventId, String? ownerName)? _openAlert;
  set onOpenAlert(void Function(String eventId, String? ownerName) fn) => _openAlert = fn;

  /// Claims one relay job, sends its SMS, and reports the result.
  /// If another guardian's phone already claimed it, this does nothing.
  Future<void> _runRelayJob(String jobId) async {
    if (!smsRelayEnabled || !SmsService.isSupported) return;
    if (!await SmsService.hasPermission()) return;

    try {
      final claimed = await _db.rpc('claim_relay_job', params: {'p_job': jobId});
      if (claimed == null) return; // already taken

      final map = Map<String, dynamic>.from(claimed as Map);
      final recipients = (map['recipients'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final text = map['message'] as String;

      final phones = recipients.map((r) => r['phone'] as String).toList();
      final results = await SmsService.sendToAll(phones, text);
      final sent = results.where((r) => r.sent).length;

      await _db.rpc('finish_relay_job', params: {'p_job': jobId, 'p_sent': sent});
    } catch (_) {
      // Leave the job unclaimed/claimed; the server reassigns stuck jobs.
    }
  }

  /// Remove this phone's token on sign-out, so a stranger who signs in next
  /// doesn't inherit the alerts.
  Future<void> unregister() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _db.from('guardian_devices').delete().eq('fcm_token', token);
      }
    } catch (_) {}
    _started = false;
  }
}
