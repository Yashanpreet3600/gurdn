import '../../security/pin_service.dart';

/// What a secret input should do.
enum SecretAction { none, unlock, duressUnlock, sos }

/// Works out what a typed string means for a disguise face, without any UI.
/// Kept pure so it can be unit-tested and shared by every face.
///
/// Rules (checked against the user's real PINs):
///   * the safety PIN            -> unlock to the real app
///   * the duress PIN            -> unlock, but as a duress session
///   * "112" + the safety PIN    -> start a SILENT SOS, stay disguised
///
/// The SOS prefix is deliberately the universal emergency number, so it's
/// easy to remember under stress. Only the digits are considered, so a
/// calculator entry like "112*2580" or "1122580" both work (the face
/// strips operators before calling this).
class SecretEntry {
  const SecretEntry._();

  /// Returns the action for [digits] (a PIN, or 112+PIN), after checking
  /// against the stored PINs. [digits] must already be operator-free.
  static Future<SecretAction> evaluate(String digits) async {
    if (digits.length < PinService.pinLength) return SecretAction.none;

    // SOS: starts with 112 and ends with the safety PIN.
    if (digits.length == 3 + PinService.pinLength && digits.startsWith('112')) {
      final pin = digits.substring(3);
      if (await PinService.check(pin) == PinCheck.safe) return SecretAction.sos;
    }

    // Unlock: exactly a PIN.
    if (digits.length == PinService.pinLength) {
      switch (await PinService.check(digits)) {
        case PinCheck.safe:
          return SecretAction.unlock;
        case PinCheck.duress:
          return SecretAction.duressUnlock;
        case PinCheck.wrong:
          return SecretAction.none;
      }
    }
    return SecretAction.none;
  }
}
