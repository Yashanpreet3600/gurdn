/// A past SOS, shown in the history screen.
class SosEventSummary {
  const SosEventSummary({
    required this.id,
    required this.level,
    required this.status,
    required this.isTest,
    required this.startedAt,
    this.endedAt,
    this.escalatedAt,
    this.duressAt,
  });

  final String id;
  final int level;

  /// active, ended, cancelled or duress
  final String status;
  final bool isTest;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime? escalatedAt;
  final DateTime? duressAt;

  static DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

  factory SosEventSummary.fromMap(Map<String, dynamic> m) => SosEventSummary(
        id: m['id'] as String,
        level: (m['level'] as num).toInt(),
        status: m['status'] as String,
        isTest: m['is_test'] as bool? ?? false,
        startedAt: _date(m['started_at'])!,
        endedAt: _date(m['ended_at']),
        escalatedAt: _date(m['escalated_at']),
        duressAt: _date(m['duress_at']),
      );
}
