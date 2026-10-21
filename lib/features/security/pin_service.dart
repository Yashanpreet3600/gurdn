import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum PinCheck { safe, duress, wrong }

/// Stores the safety PIN and duress PIN on this phone only, as salted hashes
/// in encrypted storage. They work offline, which matters during an SOS.
///
/// Safety PIN: really stops the SOS.
/// Duress PIN: looks like it stops the SOS, but alerts keep going.
class PinService {
  PinService._();

  static const pinLength = 4;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _saltKey = 'pin_salt';
  static const _safeKey = 'pin_safe_hash';
  static const _duressKey = 'pin_duress_hash';

  static Future<bool> hasPins() async {
    final safe = await _storage.read(key: _safeKey);
    final duress = await _storage.read(key: _duressKey);
    return safe != null && duress != null;
  }

  // PBKDF2 rounds. High enough to make a stolen-storage brute force of a
  // 4-digit PIN slow, low enough to feel instant on an old phone.
  static const _rounds = 120000;

  static Future<void> savePins({required String safePin, required String duressPin}) async {
    if (safePin == duressPin) throw ArgumentError('The two PINs must be different');
    final salt = _newSalt();
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _safeKey, value: _hash(safePin, salt));
    await _storage.write(key: _duressKey, value: _hash(duressPin, salt));
  }

  static Future<PinCheck> check(String pin) async {
    final salt = await _storage.read(key: _saltKey);
    if (salt == null) return PinCheck.wrong;
    final safeStored = await _storage.read(key: _safeKey);
    final duressStored = await _storage.read(key: _duressKey);

    for (final entry in [(safeStored, PinCheck.safe), (duressStored, PinCheck.duress)]) {
      final stored = entry.$1;
      if (stored == null) continue;
      if (_matches(pin, salt, stored)) {
        // Upgrade an old sha256 hash to pbkdf2 on first correct use.
        if (!stored.startsWith(_tag)) {
          await _storage.write(
            key: entry.$2 == PinCheck.safe ? _safeKey : _duressKey,
            value: _hash(pin, salt),
          );
        }
        return entry.$2;
      }
    }
    return PinCheck.wrong;
  }

  /// Constant-time-ish compare against whichever scheme produced [stored].
  static bool _matches(String pin, String salt, String stored) {
    final computed = stored.startsWith(_tag) ? _hash(pin, salt) : _legacyHash(pin, salt);
    return _constantTimeEquals(computed, stored);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Rejects PINs an attacker would try first: 1111, 1234, 9876 and so on.
  static bool isWeak(String pin) {
    if (pin.split('').toSet().length == 1) return true;
    const ascending = '01234567890';
    const descending = '09876543210';
    return ascending.contains(pin) || descending.contains(pin);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _safeKey);
    await _storage.delete(key: _duressKey);
  }

  /// Marks a PBKDF2 hash, so check() can tell it from an old SHA-256 one.
  static const _tag = 'pbkdf2:';

  /// PBKDF2-HMAC-SHA256 (one 32-byte block), stored as "pbkdf2:<base64>".
  static String _hash(String pin, String salt) {
    final mac = Hmac(sha256, utf8.encode(pin));
    var block = mac.convert([...utf8.encode(salt), 0, 0, 0, 1]).bytes;
    final result = List<int>.from(block);
    for (var i = 1; i < _rounds; i++) {
      block = mac.convert(block).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= block[j];
      }
    }
    return '$_tag${base64Url.encode(result)}';
  }

  /// The old scheme, kept only to accept PINs saved before the upgrade.
  static String _legacyHash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static String _newSalt() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
  }
}
