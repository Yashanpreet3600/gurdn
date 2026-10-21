import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_strings.dart';

/// India's emergency numbers, one tap each. Opens the phone dialer, so the
/// person still confirms the call (no accidental calls).
///
/// 112 all emergencies · 1091 women (police) · 181 women (support) · 108 ambulance
class HelplineRow extends StatelessWidget {
  const HelplineRow({super.key, this.numbers = all});

  static const all = ['112', '1091', '181', '108'];

  /// The SOS screen shows the others (112 already has its own big button).
  static const withoutEmergency = ['1091', '181', '108'];

  final List<String> numbers;

  Future<void> _call(BuildContext context, String number) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: number));
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('err_generic'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final n in numbers)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: OutlinedButton(
                onPressed: () => _call(context, n),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(n, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('helpline_$n'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
