import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/live_map.dart';
import '../../sos/services/location_service.dart';
import '../data/radar_repository.dart';

/// Shows places near you that others have flagged as unsafe, and lets you
/// add your own flag. Spots appear only once several different people have
/// reported them, so the map reflects real patterns, not one-off grudges.
class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  final _repo = RadarRepository.instance;
  LatLng? _me;
  List<UnsafeSpot> _spots = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pos = LocationService.instance.lastKnown ??
          await LocationService.instance.precise(timeout: const Duration(seconds: 10));
      if (pos == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final me = LatLng(pos.lat, pos.lng);
      final spots = await _repo.nearby(pos.lat, pos.lng);
      if (mounted) setState(() {
        _me = me;
        _spots = spots;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isNight {
    final h = DateTime.now().hour;
    return h >= 19 || h < 6;
  }

  Future<void> _report() async {
    final me = _me;
    if (me == null) {
      showMessage(context, context.tr('radar_need_location'), error: true);
      return;
    }
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.tr('radar_report_q'),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final r in RadarRepository.reasons)
              ListTile(
                leading: Icon(_reasonIcon(r)),
                title: Text(context.tr('radar_reason_$r')),
                onTap: () => Navigator.pop(context, r),
              ),
          ],
        ),
      ),
    );
    if (reason == null) return;
    try {
      await _repo.report(lat: me.latitude, lng: me.longitude, reason: reason, night: _isNight);
      if (mounted) showMessage(context, context.tr('radar_reported'));
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    }
  }

  IconData _reasonIcon(String r) => switch (r) {
        'dark' => Icons.dark_mode,
        'harassment' => Icons.report,
        'isolated' => Icons.location_off,
        'traffic' => Icons.traffic,
        'animals' => Icons.pets,
        _ => Icons.warning_amber,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('radar_title')),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _report,
        icon: const Icon(Icons.add_location_alt),
        label: Text(context.tr('radar_report')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _me == null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(context.tr('radar_need_location'), textAlign: TextAlign.center)))
              : Column(
                  children: [
                    Expanded(
                      child: LiveMap(
                        current: _me,
                        markerColor: Colors.blue,
                        height: double.infinity,
                        hazards: [
                          for (final s in _spots)
                            MapHazard(
                              point: LatLng(s.lat, s.lng),
                              color: s.mostlyNight ? Colors.deepOrange : Colors.amber,
                            ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Text(
                        _spots.isEmpty
                            ? context.tr('radar_none')
                            : context.trArgs('radar_count', {'n': '${_spots.length}'}),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
    );
  }
}
