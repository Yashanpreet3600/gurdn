import 'dart:math';

/// Random ids made on the phone, so an SOS created without internet
/// keeps the same id and secret link when it's uploaded later.
class Ids {
  Ids._();

  static final _random = Random.secure();

  /// Random hex string, e.g. for the secret guardian link.
  static String hex(int length) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(_random.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }

  /// Random UUID (version 4), the format the database uses for ids.
  static String uuid() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }
}
