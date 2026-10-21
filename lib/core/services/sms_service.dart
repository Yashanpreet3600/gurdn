import 'dart:async';

import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/platform_support.dart';

class SmsResult {
  const SmsResult(this.phone, {required this.sent, this.note});

  final String phone;
  final bool sent;
  final String? note;
}

/// Sends SMS straight from the user's SIM: no taps and no internet needed.
///
/// Android only. iOS doesn't let apps send SMS by themselves.
/// Google Play restricts this permission, so publishing there needs an
/// exception request. A sideloaded APK works fully.
class SmsService {
  SmsService._();

  static final Telephony _telephony = Telephony.instance;

  static bool get isSupported => isAndroidDevice;

  static Future<bool> hasPermission() async =>
      isSupported && await Permission.sms.isGranted;

  static Future<bool> ensurePermission() async {
    if (!isSupported) return false;
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  static Future<SmsResult> send(String phone, String message) async {
    if (!await hasPermission()) {
      return SmsResult(phone, sent: false, note: 'SMS permission is off');
    }

    final done = Completer<SmsResult>();
    try {
      await _telephony.sendSms(
        to: phone,
        message: message,
        // Multipart also handles Hindi text, which fits only 70 characters per SMS.
        isMultipart: true,
        statusListener: (status) {
          if (!done.isCompleted && status == SendStatus.SENT) {
            done.complete(SmsResult(phone, sent: true));
          }
        },
      );
    } catch (e) {
      return SmsResult(phone, sent: false, note: e.toString());
    }

    // Some phones never report back. After 20 seconds, treat the message
    // as handed to the network.
    return done.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => SmsResult(phone, sent: true, note: 'No report from network'),
    );
  }

  /// Sends to everyone at the same time.
  static Future<List<SmsResult>> sendToAll(List<String> phones, String message) {
    return Future.wait(phones.map((phone) => send(phone, message)));
  }
}
