import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/live_map.dart';
import '../data/incident_repository.dart';

/// The after-the-fact report for one SOS: a readable, shareable summary a
/// person can hand to police. Shows the timeline, the route, and every
/// evidence clip with its tamper-proof fingerprint.
class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key, required this.eventId});
  final String eventId;

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final _repo = IncidentRepository.instance;
  IncidentReport? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _repo.fetch(widget.eventId);
      if (mounted) setState(() => _report = r);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _dt(DateTime d) {
    two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  String _asText(IncidentReport r) {
    final b = StringBuffer();
    b.writeln('INCIDENT REPORT');
    b.writeln('Person: ${r.name}');
    b.writeln('Level: ${r.level}');
    b.writeln('Started: ${_dt(r.startedAt)}');
    if (r.endedAt != null) b.writeln('Ended: ${_dt(r.endedAt!)}');
    if (r.duressAt != null) b.writeln('Duress (forced cancel): ${_dt(r.duressAt!)}');
    if (r.startLat != null) {
      b.writeln('Start location: ${r.startLat}, ${r.startLng}');
      b.writeln('Map: https://maps.google.com/?q=${r.startLat},${r.startLng}');
    }
    b.writeln('');
    b.writeln('TIMELINE');
    for (final t in r.timeline) {
      b.writeln('${_dt(t.at)}  ${t.kind}');
    }
    b.writeln('');
    b.writeln('EVIDENCE (${r.evidence.length} files)');
    for (final e in r.evidence) {
      b.writeln('${_dt(e.capturedAt)}  ${e.kind}  ${e.uploadStatus}');
      if (e.sha256 != null) b.writeln('  SHA-256: ${e.sha256}');
      b.writeln('  file: ${e.storageKey}');
    }
    b.writeln('');
    b.writeln('The SHA-256 fingerprint of each file was recorded at the moment '
        'of capture. It can be used to prove the file has not been changed.');
    return b.toString();
  }

  Future<void> _play(EvidenceItem e) async {
    final url = await _repo.playUrl(e.storageKey);
    if (url == null) {
      if (mounted) showMessage(context, context.tr('evidence_unavailable'), error: true);
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('report_title')),
        actions: [
          if (r != null)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: context.tr('report_share'),
              onPressed: () => Share.share(_asText(r), subject: context.tr('report_title')),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : _body(context, r!),
    );
  }

  Widget _body(BuildContext context, IncidentReport r) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (r.isTest)
          Card(
            color: Colors.orange.withValues(alpha: 0.15),
            child: ListTile(
              leading: const Icon(Icons.science_outlined, color: Colors.orange),
              title: Text(context.tr('report_test_note')),
            ),
          ),
        Text(r.name, style: text.headlineSmall),
        const SizedBox(height: 4),
        Text('${context.tr('level_${r.level}_name')} · ${_dt(r.startedAt)}', style: text.bodySmall),
        if (r.duressAt != null) ...[
          const SizedBox(height: 8),
          Text(context.tr('report_duress_note'),
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 16),

        if (r.route.isNotEmpty || r.startLat != null) ...[
          Text(context.tr('report_route'), style: text.titleMedium),
          const SizedBox(height: 8),
          LiveMap(
            current: r.route.isNotEmpty
                ? LatLng(r.route.last[0], r.route.last[1])
                : LatLng(r.startLat!, r.startLng!),
            points: r.route.map((p) => LatLng(p[0], p[1])).toList(),
            height: 220,
          ),
          const SizedBox(height: 20),
        ],

        Text(context.tr('report_timeline'), style: text.titleMedium),
        const SizedBox(height: 8),
        for (final t in r.timeline)
          ListTile(
            dense: true,
            leading: const Icon(Icons.circle, size: 10),
            title: Text(context.tr('timeline_${t.kind}') == 'timeline_${t.kind}'
                ? t.kind
                : context.tr('timeline_${t.kind}')),
            subtitle: Text(_dt(t.at)),
          ),
        const SizedBox(height: 20),

        Text(context.trArgs('report_evidence_n', {'n': '${r.evidence.length}'}),
            style: text.titleMedium),
        const SizedBox(height: 8),
        if (r.evidence.isEmpty)
          Text(context.tr('report_no_evidence'), style: text.bodyMedium)
        else
          for (final e in r.evidence) _evidenceTile(context, e),
        const SizedBox(height: 16),
        Text(context.tr('report_fingerprint_note'), style: text.bodySmall),
      ],
    );
  }

  Widget _evidenceTile(BuildContext context, EvidenceItem e) {
    final icon = switch (e.kind) {
      'video' => Icons.videocam,
      'photo' => Icons.photo,
      _ => Icons.mic,
    };
    final uploaded = e.uploadStatus == 'uploaded';
    return Card(
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text('${context.tr('evidence_${e.kind}')} · ${_dt(e.capturedAt)}'),
        subtitle: Text(uploaded ? context.tr('evidence_saved') : context.tr('evidence_pending')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (e.sha256 != null) ...[
            Text(context.tr('evidence_fingerprint'), style: const TextStyle(fontWeight: FontWeight.w600)),
            SelectableText(e.sha256!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: 8),
          ],
          if (uploaded)
            FilledButton.icon(
              onPressed: () => _play(e),
              icon: const Icon(Icons.play_arrow),
              label: Text(context.tr('evidence_open')),
            ),
        ],
      ),
    );
  }
}
