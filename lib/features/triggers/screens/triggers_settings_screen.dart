import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/utils/helpers.dart';
import '../services/bluetooth_trigger.dart';
import '../services/voice_trigger.dart';

/// Set up the two extra SOS triggers: a Bluetooth panic button and a spoken
/// safe word. Both are off by default and both need their permission.
class TriggersSettingsScreen extends StatefulWidget {
  const TriggersSettingsScreen({super.key});

  @override
  State<TriggersSettingsScreen> createState() => _TriggersSettingsScreenState();
}

class _TriggersSettingsScreenState extends State<TriggersSettingsScreen> {
  bool _btOn = BluetoothTrigger.enabled;
  bool _voiceOn = VoiceTrigger.enabled;
  late final _word = TextEditingController(text: VoiceTrigger.safeWord);

  @override
  void dispose() {
    _word.dispose();
    super.dispose();
  }

  Future<void> _pairButton() async {
    // Bluetooth scanning needs these on Android 12+.
    final ok = await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.locationWhenInUse]
        .request();
    if (ok.values.any((s) => !s.isGranted)) {
      if (mounted) showMessage(context, context.tr('bt_need_permission'), error: true);
      return;
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<ScanResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ScanSheet(),
    );
    if (picked != null) {
      await BluetoothTrigger.instance.pair(picked.device.remoteId.str);
      if (mounted) setState(() => _btOn = true);
      if (mounted) showMessage(context, context.tr('bt_paired'));
    }
  }

  Future<void> _toggleVoice(bool on) async {
    if (on && !await Permission.microphone.request().isGranted) {
      if (mounted) showMessage(context, context.tr('voice_need_mic'), error: true);
      return;
    }
    await VoiceTrigger.setSafeWord(_word.text);
    await VoiceTrigger.instance.setEnabled(on);
    if (mounted) setState(() => _voiceOn = on);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final paired = BluetoothTrigger.pairedId != null;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('triggers_title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bluetooth button
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.bluetooth),
                    const SizedBox(width: 8),
                    Text(context.tr('bt_title'), style: text.titleMedium),
                  ]),
                  const SizedBox(height: 6),
                  Text(context.tr('bt_desc'), style: text.bodySmall),
                  const SizedBox(height: 12),
                  if (paired)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _btOn,
                      onChanged: (v) async {
                        await BluetoothTrigger.instance.setEnabled(v);
                        setState(() => _btOn = v);
                      },
                      title: Text(context.tr('bt_enabled')),
                    ),
                  Wrap(spacing: 8, children: [
                    FilledButton.icon(
                      onPressed: _pairButton,
                      icon: const Icon(Icons.add),
                      label: Text(paired ? context.tr('bt_repair') : context.tr('bt_pair')),
                    ),
                    if (paired)
                      TextButton(
                        onPressed: () async {
                          await BluetoothTrigger.instance.unpair();
                          setState(() => _btOn = false);
                        },
                        child: Text(context.tr('bt_forget')),
                      ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Voice safe word
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.record_voice_over),
                    const SizedBox(width: 8),
                    Text(context.tr('voice_title'), style: text.titleMedium),
                  ]),
                  const SizedBox(height: 6),
                  Text(context.tr('voice_desc'), style: text.bodySmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _word,
                    enabled: !_voiceOn,
                    decoration: InputDecoration(
                      labelText: context.tr('voice_safe_word'),
                      hintText: 'bachao',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _voiceOn,
                    onChanged: _toggleVoice,
                    title: Text(context.tr('voice_enabled')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(context.tr('triggers_note'), style: text.bodySmall),
        ],
      ),
    );
  }
}

class _ScanSheet extends StatefulWidget {
  const _ScanSheet();
  @override
  State<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<_ScanSheet> {
  List<ScanResult> _results = [];

  @override
  void initState() {
    super.initState();
    BluetoothTrigger.instance.scan().listen((r) {
      if (mounted) setState(() => _results = r.where((x) => x.device.platformName.isNotEmpty).toList());
    });
  }

  @override
  void dispose() {
    BluetoothTrigger.instance.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text(context.tr('bt_scanning'), style: Theme.of(context).textTheme.titleMedium),
            ]),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final r in _results)
                  ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: Text(r.device.platformName),
                    subtitle: Text(r.device.remoteId.str),
                    onTap: () => Navigator.pop(context, r),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
