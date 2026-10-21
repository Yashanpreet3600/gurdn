/// The user's SOS choices, saved in Supabase and cached on the phone
/// so an SOS works without internet.
class SosSettings {
  const SosSettings({
    required this.defaultLevel,
    required this.level1Message,
    required this.level2Message,
    required this.level3Message,
    required this.countdownSeconds,
    required this.requireArming,
    required this.smsLanguage,
    required this.escalationSeconds,
    required this.remoteControls,
  });

  /// 1 = silent location ping, 2 = alert with tracking, 3 = full SOS.
  final int defaultLevel;
  final String level1Message;
  final String level2Message;
  final String level3Message;

  /// Seconds to cancel before the SOS goes out.
  final int countdownSeconds;

  /// Tap the button 3 times to arm it first, so it can't go off in a pocket.
  final bool requireArming;

  /// 'en', 'hi' or 'pa'. English SMS are shorter and cheaper.
  final String smsLanguage;

  /// Alert backup contacts if no guardian responds within this time.
  final int escalationSeconds;

  /// What guardians may control remotely (used from Phase 6, live video).
  final Map<String, bool> remoteControls;

  static const defaults = SosSettings(
    defaultLevel: 3,
    level1Message: 'I may need help. Sharing my location.',
    level2Message: 'I need help. Follow my location.',
    level3Message: 'EMERGENCY! I am in danger. Send help now.',
    countdownSeconds: 5,
    requireArming: true,
    smsLanguage: 'en',
    escalationSeconds: 120,
    remoteControls: {'camera_switch': true, 'zoom': true, 'flashlight': false},
  );

  String messageFor(int level) => switch (level) {
        1 => level1Message,
        2 => level2Message,
        _ => level3Message,
      };

  SosSettings copyWith({
    int? defaultLevel,
    String? level1Message,
    String? level2Message,
    String? level3Message,
    int? countdownSeconds,
    bool? requireArming,
    String? smsLanguage,
    int? escalationSeconds,
  }) =>
      SosSettings(
        defaultLevel: defaultLevel ?? this.defaultLevel,
        level1Message: level1Message ?? this.level1Message,
        level2Message: level2Message ?? this.level2Message,
        level3Message: level3Message ?? this.level3Message,
        countdownSeconds: countdownSeconds ?? this.countdownSeconds,
        requireArming: requireArming ?? this.requireArming,
        smsLanguage: smsLanguage ?? this.smsLanguage,
        escalationSeconds: escalationSeconds ?? this.escalationSeconds,
        remoteControls: remoteControls,
      );

  factory SosSettings.fromMap(Map<String, dynamic> m) {
    final d = SosSettings.defaults;
    final rawControls = m['remote_controls'];
    return SosSettings(
      defaultLevel: (m['default_level'] as num?)?.toInt() ?? d.defaultLevel,
      level1Message: (m['level1_message'] as String?) ?? d.level1Message,
      level2Message: (m['level2_message'] as String?) ?? d.level2Message,
      level3Message: (m['level3_message'] as String?) ?? d.level3Message,
      countdownSeconds: (m['countdown_seconds'] as num?)?.toInt() ?? d.countdownSeconds,
      requireArming: (m['require_arming'] as bool?) ?? d.requireArming,
      smsLanguage: (m['sms_language'] as String?) ?? d.smsLanguage,
      escalationSeconds: (m['escalation_seconds'] as num?)?.toInt() ?? d.escalationSeconds,
      remoteControls: rawControls is Map
          ? rawControls.map((k, v) => MapEntry(k.toString(), v == true))
          : d.remoteControls,
    );
  }

  /// Column names match the `sos_settings` table.
  Map<String, dynamic> toMap() => {
        'default_level': defaultLevel,
        'level1_message': level1Message,
        'level2_message': level2Message,
        'level3_message': level3Message,
        'countdown_seconds': countdownSeconds,
        'require_arming': requireArming,
        'sms_language': smsLanguage,
        'escalation_seconds': escalationSeconds,
        'remote_controls': remoteControls,
      };
}
