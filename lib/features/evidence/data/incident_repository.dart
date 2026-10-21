import '../../../core/services/supabase_service.dart';
import 'evidence_repository.dart';

/// Reads the after-the-fact incident report for one SOS (event + timeline +
/// route + evidence with fingerprints), from the incident_report() RPC.
class IncidentRepository {
  IncidentRepository._();
  static final instance = IncidentRepository._();

  Future<IncidentReport> fetch(String eventId) async {
    final data = await SupabaseService.client
        .rpc('incident_report', params: {'p_event': eventId});
    return IncidentReport.fromMap(Map<String, dynamic>.from(data as Map));
  }

  /// A short-lived URL to play/download one clip.
  Future<String?> playUrl(String storageKey) =>
      EvidenceRepository.instance.downloadUrl(storageKey);
}

class IncidentReport {
  IncidentReport({
    required this.name,
    required this.level,
    required this.status,
    required this.isTest,
    required this.startedAt,
    this.endedAt,
    this.duressAt,
    this.startLat,
    this.startLng,
    this.reasonMeta,
    required this.timeline,
    required this.route,
    required this.evidence,
  });

  final String name;
  final int level;
  final String status;
  final bool isTest;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime? duressAt;
  final double? startLat;
  final double? startLng;
  final Map<String, dynamic>? reasonMeta;
  final List<TimelineEntry> timeline;
  final List<List<double>> route;
  final List<EvidenceItem> evidence;

  factory IncidentReport.fromMap(Map<String, dynamic> m) {
    final e = Map<String, dynamic>.from(m['event'] as Map);
    DateTime? d(String? s) => s == null ? null : DateTime.parse(s);
    return IncidentReport(
      name: (e['name'] as String?) ?? '',
      level: (e['level'] as num?)?.toInt() ?? 3,
      status: e['status'] as String? ?? '',
      isTest: (e['is_test'] as bool?) ?? false,
      startedAt: DateTime.parse(e['started_at'] as String),
      endedAt: d(e['ended_at'] as String?),
      duressAt: d(e['duress_at'] as String?),
      startLat: (e['start_lat'] as num?)?.toDouble(),
      startLng: (e['start_lng'] as num?)?.toDouble(),
      reasonMeta: (e['reason_meta'] as Map?)?.cast<String, dynamic>(),
      timeline: ((m['timeline'] as List?) ?? [])
          .map((x) => TimelineEntry.fromMap(Map<String, dynamic>.from(x as Map)))
          .toList(),
      route: ((m['route'] as List?) ?? [])
          .map((x) => [
                ((x as Map)['lat'] as num).toDouble(),
                (x['lng'] as num).toDouble(),
              ])
          .toList(),
      evidence: ((m['evidence'] as List?) ?? [])
          .map((x) => EvidenceItem.fromMap(Map<String, dynamic>.from(x as Map)))
          .toList(),
    );
  }
}

class TimelineEntry {
  TimelineEntry(this.kind, this.detail, this.at);
  final String kind;
  final Map<String, dynamic> detail;
  final DateTime at;
  factory TimelineEntry.fromMap(Map<String, dynamic> m) => TimelineEntry(
        m['kind'] as String,
        (m['detail'] as Map?)?.cast<String, dynamic>() ?? const {},
        DateTime.parse(m['at'] as String),
      );
}

class EvidenceItem {
  EvidenceItem({
    required this.kind,
    required this.storageKey,
    required this.capturedAt,
    required this.uploadStatus,
    this.sha256,
    this.bytes,
    this.durationMs,
  });
  final String kind;
  final String storageKey;
  final DateTime capturedAt;
  final String uploadStatus;
  final String? sha256;
  final int? bytes;
  final int? durationMs;

  factory EvidenceItem.fromMap(Map<String, dynamic> m) => EvidenceItem(
        kind: m['kind'] as String,
        storageKey: m['storage_key'] as String,
        capturedAt: DateTime.parse(m['captured_at'] as String),
        uploadStatus: m['upload_status'] as String? ?? 'pending',
        sha256: m['sha256'] as String?,
        bytes: (m['bytes'] as num?)?.toInt(),
        durationMs: (m['duration_ms'] as num?)?.toInt(),
      );
}
