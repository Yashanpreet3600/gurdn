import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/localization/app_strings.dart';

/// A realistic incoming call, to give you a reason to step away from an
/// uncomfortable situation. Looks like the system dialer; answering plays a
/// short one-sided spoken "conversation". Everything is on-device.
class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key, this.caller});
  final String? caller;

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  final _tts = FlutterTts();
  bool _answered = false;
  Timer? _vibrate;
  Timer? _autoEnd;

  @override
  void initState() {
    super.initState();
    // Ring feel: repeat a vibration pattern until answered/dismissed.
    _vibrate = Timer.periodic(const Duration(seconds: 2), (_) {
      HapticFeedback.heavyImpact();
    });
  }

  @override
  void dispose() {
    _vibrate?.cancel();
    _autoEnd?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _answer() async {
    _vibrate?.cancel();
    setState(() => _answered = true);
    final lang = LocaleController.instance.value.languageCode;
    try {
      await _tts.setLanguage(switch (lang) { 'hi' => 'hi-IN', 'pa' => 'pa-IN', _ => 'en-IN' });
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      for (final key in ['fake_line_1', 'fake_line_2', 'fake_line_3']) {
        await _tts.speak(AppStrings.get(key, lang));
        await Future.delayed(const Duration(seconds: 3));
      }
    } catch (_) {}
    // End by itself after the lines, if still open.
    if (mounted) _hangUp();
  }

  void _hangUp() {
    _vibrate?.cancel();
    _tts.stop();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final caller = widget.caller ?? AppStrings.get('fake_caller', LocaleController.instance.value.languageCode);
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            const CircleAvatar(radius: 56, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 64, color: Colors.white70)),
            const SizedBox(height: 20),
            Text(caller, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              _answered
                  ? AppStrings.get('fake_ongoing', LocaleController.instance.value.languageCode)
                  : AppStrings.get('fake_incoming', LocaleController.instance.value.languageCode),
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: _answered
                  ? _round(Icons.call_end, Colors.red, _hangUp)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _round(Icons.call_end, Colors.red, _hangUp),
                        _round(Icons.call, Colors.green, _answer),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _round(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
      );
}
