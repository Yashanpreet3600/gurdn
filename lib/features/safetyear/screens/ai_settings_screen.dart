import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/utils/helpers.dart';
import '../../visualguard/visual_guard.dart';
import '../safety_ear.dart';

/// Turn the experimental on-device AI features on or off. Both are off by
/// default and clearly marked experimental. A detection never fires an SOS
/// instantly — it always goes through a 10-second cancel-countdown first.
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  bool _ear = SafetyEar.enabled;
  bool _visual = VisualGuard.enabled;

  Future<void> _setEar(bool on) async {
    if (on && !await Permission.microphone.request().isGranted) {
      if (mounted) showMessage(context, context.tr('ai_need_mic'), error: true);
      return;
    }
    await SafetyEar.instance.setEnabled(on);
    if (mounted) setState(() => _ear = on);
  }

  Future<void> _setVisual(bool on) async {
    if (on && !await Permission.camera.request().isGranted) {
      if (mounted) showMessage(context, context.tr('ai_need_camera'), error: true);
      return;
    }
    await VisualGuard.instance.setEnabled(on);
    if (mounted) setState(() => _visual = on);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('ai_title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.science_outlined),
                const SizedBox(width: 10),
                Expanded(child: Text(context.tr('ai_experimental'), style: text.bodyMedium)),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.hearing),
              value: _ear,
              onChanged: _setEar,
              title: Text(context.tr('ai_safety_ear')),
              subtitle: Text(context.tr('ai_safety_ear_desc')),
            ),
          ),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.visibility),
              value: _visual,
              onChanged: _setVisual,
              title: Text(context.tr('ai_visual_guard')),
              subtitle: Text(context.tr('ai_visual_guard_desc')),
            ),
          ),
          const SizedBox(height: 12),
          Text(context.tr('ai_countdown_note'), style: text.bodySmall),
        ],
      ),
    );
  }
}
