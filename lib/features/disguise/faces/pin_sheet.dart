import 'package:flutter/material.dart';

import 'face_actions.dart';
import 'secret_entry.dart';

/// A small keypad shown by the Weather and Gallery faces from a hidden
/// gesture. Entering the safety PIN (or 112 + PIN) triggers the action.
/// Looks like an ordinary "enter passcode" dialog, with no app branding.
class PinSheet extends StatefulWidget {
  const PinSheet({super.key});

  static Future<void> show(BuildContext context) =>
      showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const PinSheet());

  @override
  State<PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<PinSheet> {
  String _entry = '';

  Future<void> _press(String d) async {
    setState(() => _entry += d);
    final action = await SecretEntry.evaluate(_entry);
    if (action != SecretAction.none) {
      if (mounted) Navigator.pop(context);
      if (mounted) await FaceActions.handle(context, action);
    } else if (_entry.length >= 7) {
      // Too long to be anything valid: reset quietly.
      setState(() => _entry = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom + 24, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter passcode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _entry.isEmpty ? 4 : _entry.length,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _entry.length ? Theme.of(context).colorScheme.primary : Colors.grey.shade400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          for (final row in const [['1','2','3'],['4','5','6'],['7','8','9'],['','0','⌫']])
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final k in row)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: 64, height: 64,
                      child: k.isEmpty
                          ? const SizedBox()
                          : OutlinedButton(
                              onPressed: k == '⌫'
                                  ? () => setState(() => _entry = _entry.isEmpty ? '' : _entry.substring(0, _entry.length - 1))
                                  : () => _press(k),
                              style: OutlinedButton.styleFrom(shape: const CircleBorder()),
                              child: Text(k, style: const TextStyle(fontSize: 22)),
                            ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
