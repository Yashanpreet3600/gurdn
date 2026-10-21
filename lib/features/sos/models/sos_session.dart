/// The SOS that is running right now. Saved on the phone so it survives
/// the app being closed or the phone restarting the app.
class SosSession {
  SosSession({
    required this.eventId,
    required this.token,
    required this.level,
    required this.isTest,
    required this.startedAt,
    this.duress = false,
    this.escalated = false,
  });

  final String eventId;

  /// Secret code for the guardian web link.
  final String token;
  final int level;
  final bool isTest;
  final DateTime startedAt;

  /// The duress PIN was used: the screen pretends the SOS stopped.
  bool duress;

  /// Backup contacts were alerted because no one responded.
  bool escalated;

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'token': token,
        'level': level,
        'isTest': isTest,
        'startedAt': startedAt.toIso8601String(),
        'duress': duress,
        'escalated': escalated,
      };

  factory SosSession.fromJson(Map<String, dynamic> m) => SosSession(
        eventId: m['eventId'] as String,
        token: m['token'] as String,
        level: (m['level'] as num).toInt(),
        isTest: m['isTest'] as bool? ?? false,
        startedAt: DateTime.parse(m['startedAt'] as String),
        duress: m['duress'] as bool? ?? false,
        escalated: m['escalated'] as bool? ?? false,
      );
}
