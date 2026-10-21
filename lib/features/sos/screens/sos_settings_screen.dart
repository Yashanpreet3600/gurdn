import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../data/sos_settings_repository.dart';
import '../models/sos_settings.dart';
import '../sos_actions.dart';

/// SOS levels, messages, countdown, arming, SMS language, escalation, test mode.
class SosSettingsScreen extends StatefulWidget {
  const SosSettingsScreen({super.key});

  @override
  State<SosSettingsScreen> createState() => _SosSettingsScreenState();
}

class _SosSettingsScreenState extends State<SosSettingsScreen> {
  final _repo = SosSettingsRepository.instance;
  final _messages = [TextEditingController(), TextEditingController(), TextEditingController()];

  SosSettings _s = SosSettings.defaults;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _messages) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final s = await _repo.load();
    if (!mounted) return;
    setState(() {
      _s = s;
      _messages[0].text = s.level1Message;
      _messages[1].text = s.level2Message;
      _messages[2].text = s.level3Message;
      _loading = false;
    });
  }

  SosSettings get _edited => _s.copyWith(
        level1Message: _messages[0].text.trim().isEmpty ? null : _messages[0].text.trim(),
        level2Message: _messages[1].text.trim().isEmpty ? null : _messages[1].text.trim(),
        level3Message: _messages[2].text.trim().isEmpty ? null : _messages[2].text.trim(),
      );

  Future<bool> _save({bool quiet = false}) async {
    setState(() => _saving = true);
    try {
      _s = _edited;
      await _repo.save(_s);
      if (mounted && !quiet) showMessage(context, context.tr('saved'));
      return true;
    } catch (e) {
      // The phone copy is already updated, so SOS uses the new settings anyway.
      if (mounted) showMessage(context, context.tr('sos_saved_offline'), error: true);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runTest() async {
    final ok = await confirmDialog(
      context,
      title: context.tr('test_sos_title'),
      body: context.tr('test_sos_body'),
      confirmLabel: context.tr('test_sos_start'),
    );
    if (!ok || !mounted) return;
    await _save(quiet: true);
    if (!mounted) return;
    await SosActions.trigger(context, level: 2, isTest: true);
  }

  Widget _section(String key) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text(context.tr(key), style: Theme.of(context).textTheme.titleMedium),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('sos_settings'))),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  _section('sos_default_level'),
                  SegmentedButton<int>(
                    segments: [
                      for (final l in const [1, 2, 3])
                        ButtonSegment(value: l, label: Text(context.tr('level_${l}_short'))),
                    ],
                    selected: {_s.defaultLevel},
                    onSelectionChanged: (v) => setState(() => _s = _s.copyWith(defaultLevel: v.first)),
                  ),
                  const SizedBox(height: 8),
                  Text(context.tr('level_${_s.defaultLevel}_desc'), style: text.bodySmall),

                  _section('sos_messages'),
                  for (var i = 0; i < 3; i++)
                    AppTextField(
                      controller: _messages[i],
                      label: context.tr('level_${i + 1}_name'),
                      maxLines: 2,
                    ),
                  Text(context.tr('sos_messages_hint'), style: text.bodySmall),

                  _section('sos_countdown'),
                  SegmentedButton<int>(
                    segments: [
                      for (final sec in const [3, 5, 10])
                        ButtonSegment(value: sec, label: Text(context.trArgs('seconds_short', {'n': '$sec'}))),
                    ],
                    selected: {_s.countdownSeconds},
                    onSelectionChanged: (v) => setState(() => _s = _s.copyWith(countdownSeconds: v.first)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _s.requireArming,
                    onChanged: (v) => setState(() => _s = _s.copyWith(requireArming: v)),
                    title: Text(context.tr('sos_arming')),
                    subtitle: Text(context.tr('sos_arming_desc')),
                  ),

                  _section('sms_language'),
                  SegmentedButton<String>(
                    segments: [
                      for (final e in AppStrings.languageNames.entries)
                        ButtonSegment(value: e.key, label: Text(e.value)),
                    ],
                    selected: {_s.smsLanguage},
                    onSelectionChanged: (v) => setState(() => _s = _s.copyWith(smsLanguage: v.first)),
                  ),
                  const SizedBox(height: 8),
                  Text(context.tr('sms_language_hint'), style: text.bodySmall),

                  _section('escalation_after'),
                  SegmentedButton<int>(
                    segments: [
                      for (final sec in const [60, 120, 180])
                        ButtonSegment(value: sec, label: Text(context.trArgs('minutes_short', {'n': '${sec ~/ 60}'}))),
                    ],
                    selected: {_s.escalationSeconds},
                    onSelectionChanged: (v) => setState(() => _s = _s.copyWith(escalationSeconds: v.first)),
                  ),
                  const SizedBox(height: 8),
                  Text(context.tr('escalation_hint'), style: text.bodySmall),

                  const SizedBox(height: 28),
                  PrimaryButton(label: context.tr('save'), onPressed: () => _save(), loading: _saving),
                  const SizedBox(height: 12),
                  SecondaryButton(
                    label: context.tr('test_sos_start'),
                    icon: Icons.science_outlined,
                    onPressed: _saving ? null : _runTest,
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.sosHistory),
                    child: Text(context.tr('sos_history')),
                  ),
                ],
              ),
      ),
    );
  }
}
