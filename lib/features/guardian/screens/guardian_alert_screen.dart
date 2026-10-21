import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/helpline_row.dart';
import '../../../shared/widgets/live_map.dart';
import '../data/guardian_repository.dart';
import '../services/nearby_service.dart';
import '../../../core/routing/app_routes.dart';

/// What a guardian sees when someone they protect has an active SOS.
/// Opened from the push notification or from the guardian home list.
class GuardianAlertScreen extends StatefulWidget {
  const GuardianAlertScreen({
    super.key,
    required this.eventId,
    this.ownerUserId,
    this.ownerName,
    this.ownerPhone,
  });

  final String eventId;
  final String? ownerUserId;
  final String? ownerName;
  final String? ownerPhone;

  @override
  State<GuardianAlertScreen> createState() => _GuardianAlertScreenState();
}

class _GuardianAlertScreenState extends State<GuardianAlertScreen> {
  final _repo = GuardianRepository.instance;

  GuardianAlert? _alert;
  List<TrackPoint> _points = [];
  String? _myResponse;
  Map<String, int> _tally = {};
  List<NearbyPlace> _nearby = [];
  Timer? _poll;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
    _markViewed();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _markViewed() async {
    // Opening the alert counts as a view (stops escalation to backups).
    try {
      await _repo.respond(widget.eventId, null);
    } catch (_) {}
  }

  Future<void> _refresh() async {
    try {
      final owner = widget.ownerUserId;
      final alert = owner != null
          ? await _repo.activeAlertFor(owner)
          : (await _repo.allActiveAlerts())
              .cast<GuardianAlert?>()
              .firstWhere((a) => a?.eventId == widget.eventId, orElse: () => null);

      if (alert == null) {
        if (mounted) setState(() {
          _alert = null;
          _loading = false;
        });
        return;
      }

      final results = await Future.wait([
        _repo.route(alert.eventId),
        _repo.myResponse(alert.eventId),
        _repo.responderTally(alert.eventId),
      ]);

      // Nearest help: fetch once, when we first have a location.
      if (_nearby.isEmpty && alert.lat != null && alert.lng != null) {
        NearbyService.instance
            .nearest(alert.lat!, alert.lng!)
            .then((list) {
          if (mounted) setState(() => _nearby = list);
        }).catchError((_) => <NearbyPlace>[]);
      }

      if (!mounted) return;
      setState(() {
        _alert = alert;
        _points = results[0] as List<TrackPoint>;
        _myResponse = results[1] as String?;
        _tally = results[2] as Map<String, int>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(String response) async {
    final newValue = _myResponse == response ? null : response;
    setState(() => _myResponse = newValue);
    try {
      await _repo.respond(widget.eventId, newValue);
      await _refresh();
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    }
  }

  Future<void> _callOwner() async {
    // We only have the owner's phone if it was passed in; otherwise prompt 112.
    final phone = widget.ownerPhone;
    if (phone != null && phone.isNotEmpty) {
      await launchUrl(Uri(scheme: 'tel', path: phone));
    } else {
      await launchUrl(Uri(scheme: 'tel', path: '112'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = _alert;
    final name = alert?.ownerName.isNotEmpty == true
        ? alert!.ownerName
        : (widget.ownerName ?? '');

    return Scaffold(
      appBar: AppBar(title: Text(name.isEmpty ? context.tr('guardian_alert_title') : name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : alert == null
              ? _ended(context)
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    children: [
                      _statusBanner(context, alert),
                      LiveMap(
                        current: alert.lat != null && alert.lng != null
                            ? LatLng(alert.lat!, alert.lng!)
                            : null,
                        points: _points.map((p) => LatLng(p.lat, p.lng)).toList(),
                        accuracyMeters: alert.accuracyM,
                        height: 300,
                        extraMarkers: [
                          for (final p in _nearby)
                            MapPin(
                              point: LatLng(p.lat, p.lng),
                              label: p.name,
                              icon: p.kind == 'police' ? Icons.local_police : Icons.local_hospital,
                              color: p.kind == 'police' ? Colors.indigo : Colors.teal,
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _responseButtons(context),
                            const SizedBox(height: 20),
                            _facts(context, alert),
                            if (_nearby.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Text(context.tr('nearest_help'),
                                  style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              for (final p in _nearby) _nearbyTile(context, p),
                            ],
                            const SizedBox(height: 20),
                            const HelplineRow(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _statusBanner(BuildContext context, GuardianAlert alert) {
    final scheme = Theme.of(context).colorScheme;
    final (text, color) = alert.isTest
        ? (context.tr('guardian_test_banner'), Colors.orange)
        : alert.phoneOffline
            ? (context.tr('guardian_offline_banner'), scheme.error)
            : alert.isDuress
                ? (context.tr('guardian_duress_banner'), scheme.error)
                : alert.source == 'trip'
                    ? (context.tr('guardian_trip_banner'), scheme.error)
                    : alert.source == 'walk_home'
                        ? (context.tr('guardian_walk_banner'), scheme.error)
                        : (context.tr('guardian_live_banner'), scheme.error);
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }

  Widget _responseButtons(BuildContext context) {
    Widget btn(String value, IconData icon, String label, Color color) {
      final selected = _myResponse == value;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: selected
              ? FilledButton.icon(
                  onPressed: () => _respond(value),
                  icon: Icon(icon, size: 18),
                  label: Text(label, textAlign: TextAlign.center),
                  style: FilledButton.styleFrom(backgroundColor: color),
                )
              : OutlinedButton.icon(
                  onPressed: () => _respond(value),
                  icon: Icon(icon, size: 18),
                  label: Text(label, textAlign: TextAlign.center),
                ),
        ),
      );
    }

    final coming = (_tally['on_my_way'] ?? 0) + (_tally['calling_police'] ?? 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('guardian_respond_q'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Row(children: [
          btn('on_my_way', Icons.directions_run, context.tr('resp_on_my_way'), Colors.green),
          btn('calling_police', Icons.local_police, context.tr('resp_calling_police'), Colors.indigo),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          btn('cant_help', Icons.block, context.tr('resp_cant_help'), Colors.grey),
          const Expanded(child: SizedBox()),
        ]),
        if (coming > 0) ...[
          const SizedBox(height: 10),
          Text(context.trArgs('guardian_responding_count', {'n': '$coming'}),
              style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }

  Widget _facts(BuildContext context, GuardianAlert alert) {
    final text = Theme.of(context).textTheme;
    final dest = alert.reasonMeta?['destination'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!alert.phoneOffline && alert.level >= 3) ...[
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.liveViewer,
                arguments: {'eventId': alert.eventId, 'ownerName': alert.ownerName}),
            icon: const Icon(Icons.videocam),
            label: Text(context.tr('guardian_watch_live')),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          onPressed: _callOwner,
          icon: const Icon(Icons.call),
          label: Text(context.tr('guardian_call_now')),
        ),
        const SizedBox(height: 12),
        if (alert.battery != null)
          Text('${context.tr('battery_label')}: ${alert.battery}%', style: text.bodyMedium),
        if (dest != null && dest.isNotEmpty)
          Text('${context.tr('trip_destination')}: $dest', style: text.bodyMedium),
        Text(
          context.trArgs('started_ago', {'t': _ago(context, alert.startedAt)}),
          style: text.bodySmall,
        ),
      ],
    );
  }

  Widget _nearbyTile(BuildContext context, NearbyPlace p) {
    return Card(
      child: ListTile(
        leading: Icon(p.kind == 'police' ? Icons.local_police : Icons.local_hospital,
            color: p.kind == 'police' ? Colors.indigo : Colors.teal),
        title: Text(p.name),
        subtitle: Text('${p.distanceMeters ~/ 100 / 10} km'),
        trailing: p.phone != null
            ? IconButton(
                icon: const Icon(Icons.call),
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: p.phone!)),
              )
            : IconButton(
                icon: const Icon(Icons.directions),
                onPressed: () => launchUrl(
                    Uri.parse('https://www.openstreetmap.org/?mlat=${p.lat}&mlon=${p.lng}#map=17/${p.lat}/${p.lng}')),
              ),
      ),
    );
  }

  Widget _ended(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 56),
            const SizedBox(height: 12),
            Text(context.tr('guardian_alert_ended'), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  String _ago(BuildContext context, DateTime t) {
    final mins = DateTime.now().difference(t).inMinutes;
    if (mins < 1) return context.tr('just_now');
    if (mins < 60) return context.trArgs('minutes_short', {'n': '$mins'});
    return context.trArgs('hours_short', {'n': '${mins ~/ 60}'});
  }
}
