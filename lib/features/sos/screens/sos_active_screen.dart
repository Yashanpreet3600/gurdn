import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../contacts/models/emergency_contact.dart';
import '../services/sos_engine.dart';
import '../sos_actions.dart';
import '../../../shared/widgets/helpline_row.dart';
import 'package:image_picker/image_picker.dart';
import '../../evidence/data/evidence_repository.dart';
import '../../../core/utils/helpers.dart';
import '../../deterrent/services/tactical_voice.dart';

/// Shows what the SOS is doing right now. Leaving this screen doesn't stop
/// the SOS; only the safety PIN does.
class SosActiveScreen extends StatefulWidget {
  const SosActiveScreen({super.key});

  @override
  State<SosActiveScreen> createState() => _SosActiveScreenState();
}

class _SosActiveScreenState extends State<SosActiveScreen> {
  final _engine = SosEngine.instance;
  Timer? _ticker;
  bool _seenActive = false;

  @override
  void initState() {
    super.initState();
    _seenActive = _engine.isActive;
    _engine.addListener(_changed);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _engine.removeListener(_changed);
    _ticker?.cancel();
    super.dispose();
  }

  void _changed() {
    if (_engine.isActive) _seenActive = true;
    if (_seenActive && !_engine.isActive) {
      // Stopped: go home after this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => SosActions.goHome());
      return;
    }
    if (mounted) setState(() {});
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  Future<void> _call112() => launchUrl(Uri(scheme: 'tel', path: '112'));

  bool _capturing = false;

  Future<void> _capture(ImageSource _, bool video) async {
    final eventId = _engine.session?.eventId;
    if (eventId == null) return;
    setState(() => _capturing = true);
    try {
      final picker = ImagePicker();
      final XFile? x = video
          ? await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 30))
          : await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (x != null) {
        await EvidenceRepository.instance.capture(
          localPath: x.path,
          kind: video ? 'video' : 'photo',
          eventId: eventId,
        );
        if (mounted) showMessage(context, context.tr('evidence_captured'));
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _engine.session;
    if (s == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final text = Theme.of(context).textTheme;
    final elapsed = DateTime.now().difference(s.startedAt);
    final clock = '${_two(elapsed.inMinutes)}:${_two(elapsed.inSeconds % 60)}';
    final shown = s.escalated ? _engine.contacts : _engine.primaryContacts;
    final p = _engine.position;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.sosRed,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_rounded, color: Colors.white, size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr(s.isTest ? 'sos_active_test' : 'sos_active_title'),
                          style: text.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        clock,
                        style: text.titleLarge?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('level_${s.level}_name'),
                    style: text.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (s.duress) ...[
              InfoCard(icon: Icons.privacy_tip_outlined, body: context.tr('sos_duress_running')),
              const SizedBox(height: 12),
            ],
            if (s.escalated) ...[
              InfoCard(
                icon: Icons.campaign_outlined,
                title: context.tr('sos_escalated_title'),
                body: context.tr('sos_escalated_body'),
              ),
              const SizedBox(height: 12),
            ],
            if (!_engine.locationAllowed) ...[
              InfoCard(icon: Icons.location_off_outlined, body: context.tr('sos_no_location_permission')),
              const SizedBox(height: 12),
            ],
            Text(context.tr('sos_alerts'), style: text.titleMedium),
            const SizedBox(height: 4),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(context.tr('sos_no_contacts')),
              )
            else
              for (final c in shown) _contactRow(c),
            const SizedBox(height: 12),
            Text(context.tr('sos_location'), style: text.titleMedium),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.my_location),
              title: Text(
                p == null
                    ? context.tr('sos_finding_location')
                    : context.trArgs('sos_location_value', {
                        'm': '${p.accuracy.round()}',
                        'time': '${_two(p.at.hour)}:${_two(p.at.minute)}:${_two(p.at.second)}',
                      }),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _engine.serverSynced ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
              ),
              title: Text(context.tr(_engine.serverSynced ? 'sos_synced' : 'sos_not_synced')),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.hiddenSos),
                    icon: const Icon(Icons.visibility_off_outlined),
                    label: Text(context.tr('hide_screen')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _call112,
                    icon: const Icon(Icons.call_outlined),
                    label: Text(context.tr('call_112')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => TacticalVoice.instance.speak(
                    LocaleController.instance.value.languageCode),
                icon: const Icon(Icons.campaign),
                label: Text(context.tr('tactical_button')),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _capturing ? null : () => _capture(ImageSource.camera, true),
                    icon: const Icon(Icons.videocam),
                    label: Text(context.tr('evidence_record_video')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _capturing ? null : () => _capture(ImageSource.camera, false),
                    icon: const Icon(Icons.photo_camera),
                    label: Text(context.tr('evidence_take_photo')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const HelplineRow(numbers: HelplineRow.withoutEmergency),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.sosRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.stopSos),
                child: Text(context.tr('stop_sos')),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('sos_leave_hint'),
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactRow(EmergencyContact c) {
    final scheme = Theme.of(context).colorScheme;
    final String label;
    final Color color;
    if (!_engine.smsStatus.containsKey(c.phone)) {
      label = context.tr('sms_not_yet');
      color = scheme.outline;
    } else {
      final result = _engine.smsStatus[c.phone];
      if (result == null) {
        label = context.tr('sms_sending');
        color = AppTheme.warningAmber;
      } else if (result.sent) {
        label = context.tr('sms_sent');
        color = AppTheme.safeGreen;
      } else {
        label = context.tr('sms_failed');
        color = scheme.error;
      }
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.person_outline),
      title: Text(c.name),
      subtitle: c.isBackup ? Text(context.tr('backup')) : null,
      trailing: StatusChip(label: label, color: color),
    );
  }
}
