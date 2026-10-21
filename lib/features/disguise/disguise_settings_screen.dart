import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/utils/helpers.dart';
import '../security/pin_service.dart';
import 'disguise_controller.dart';
import 'power_trigger.dart';

/// Choose which ordinary-looking app GuardianX hides behind, and learn the
/// secret way back in. Requires PINs to be set first, since the unlock and
/// the hidden SOS both use the safety PIN.
class DisguiseSettingsScreen extends StatefulWidget {
  const DisguiseSettingsScreen({super.key});

  @override
  State<DisguiseSettingsScreen> createState() => _DisguiseSettingsScreenState();
}

class _DisguiseSettingsScreenState extends State<DisguiseSettingsScreen> {
  DisguiseKind _kind = DisguiseController.instance.kind;
  bool _hasPins = true;
  bool _power = PowerTrigger.enabled;

  @override
  void initState() {
    super.initState();
    PinService.hasPins().then((v) {
      if (mounted) setState(() => _hasPins = v);
    });
  }

  Future<void> _choose(DisguiseKind kind) async {
    if (kind != DisguiseKind.off && !_hasPins) {
      showMessage(context, context.tr('disguise_need_pins'), error: true);
      return;
    }
    await DisguiseController.instance.setKind(kind);
    setState(() => _kind = kind);
    if (mounted) {
      showMessage(context,
          kind == DisguiseKind.off ? context.tr('disguise_off_done') : context.tr('disguise_set_done'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('disguise_title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(context.tr('disguise_intro')),
          const SizedBox(height: 16),

          if (!_hasPins)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(context.tr('disguise_need_pins')),
              ),
            ),

          _option(DisguiseKind.off, Icons.visibility, context.tr('disguise_none'),
              context.tr('disguise_none_desc')),
          _option(DisguiseKind.calculator, Icons.calculate, context.tr('disguise_calculator'),
              context.tr('disguise_calculator_desc')),
          _option(DisguiseKind.notepad, Icons.edit_note, context.tr('disguise_notepad'),
              context.tr('disguise_notepad_desc')),
          _option(DisguiseKind.weather, Icons.wb_cloudy, context.tr('disguise_weather'),
              context.tr('disguise_weather_desc')),
          _option(DisguiseKind.gallery, Icons.photo_library, context.tr('disguise_gallery'),
              context.tr('disguise_gallery_desc')),

          const SizedBox(height: 16),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.power_settings_new),
              value: _power,
              onChanged: _hasPins
                  ? (v) async {
                      await PowerTrigger.instance.setEnabled(v);
                      setState(() => _power = v);
                      if (v && mounted) showMessage(context, context.tr('power_on'));
                    }
                  : null,
              title: Text(context.tr('power_title')),
              subtitle: Text(context.tr('power_desc')),
            ),
          ),

          const SizedBox(height: 20),
          Text(context.tr('disguise_how_title'), style: text.titleMedium),
          const SizedBox(height: 8),
          Text(context.tr('disguise_how_unlock')),
          const SizedBox(height: 6),
          Text(context.tr('disguise_how_sos')),

          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(context.tr('disguise_limits_title'),
                        style: text.titleSmall)),
                  ]),
                  const SizedBox(height: 8),
                  Text(context.tr('disguise_limit_sms')),
                  const SizedBox(height: 4),
                  Text(context.tr('disguise_limit_dot')),
                ],
              ),
            ),
          ),

          if (_kind != DisguiseKind.off) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                // Lock now so the chosen face shows; the user tests the unlock.
                DisguiseController.instance.relock();
                showMessage(context, context.tr('disguise_test_hint'));
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(context.tr('disguise_test')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _option(DisguiseKind kind, IconData icon, String title, String desc) {
    final selected = _kind == kind;
    return Card(
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(desc),
        trailing: selected ? const Icon(Icons.check_circle) : null,
        onTap: () => _choose(kind),
      ),
    );
  }
}
