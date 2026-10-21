import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/local_store.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/sms_service.dart';

/// Handles a relay push that arrives while the guardian app is fully closed.
///
/// Firebase runs this in a separate isolate, so it has none of the app's
/// state and must set up what it needs itself. It stays small on purpose:
/// claim this phone's relay job and send its share of SMS.
///
/// Must be a top-level function annotated @pragma('vm:entry-point'), or
/// release builds strip it.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  final data = message.data;
  if (data['type'] != 'sms_relay') return;
  final jobId = data['job_id'];
  if (jobId == null || jobId.isEmpty) return;

  // Fresh isolate: load what we need.
  await LocalStore.init();
  if (!AppConfig.isConfigured) return;
  if (LocalStore.getBool(LocalKeys.smsRelayOptIn) != true) return;
  if (!SmsService.isSupported || !await SmsService.hasPermission()) return;

  await SupabaseService.init();
  if (SupabaseService.currentUser == null) return;

  try {
    final claimed = await SupabaseService.client
        .rpc('claim_relay_job', params: {'p_job': jobId});
    if (claimed == null) return; // another guardian's phone got it first

    final map = Map<String, dynamic>.from(claimed as Map);
    final recipients = (map['recipients'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final text = map['message'] as String;

    final phones = recipients.map((r) => r['phone'] as String).toList();
    final results = await SmsService.sendToAll(phones, text);
    final sent = results.where((r) => r.sent).length;

    await SupabaseService.client
        .rpc('finish_relay_job', params: {'p_job': jobId, 'p_sent': sent});
  } catch (_) {
    // The server reassigns jobs that no phone finishes.
  }
}
