import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/routing/app_routes.dart';
import '../disguise/faces/face_actions.dart';
import '../sos/services/sos_engine.dart';

/// Shared handler for an AI detection (Safety Ear or Visual Guard). Shows a
/// 10-second "Starting SOS — tap to cancel" screen, then fires a silent SOS
/// unless cancelled. This countdown is what makes auto-trigger safe to use:
/// a misread sound or object can be waved off before contacts are alerted.
class AiTrigger {
  const AiTrigger._();

  static bool _active = false;

  /// Called when an AI feature thinks it detected danger. [what] is a short
  /// translated description shown on the countdown ("a scream", "a weapon").
  static Future<void> raise(String what) async {
    if (_active) return; // one countdown at a time
    if (SosEngine.instance.isActive) return; // already in an SOS
    final nav = AppRoutes.navigatorKey.currentState;
    if (nav == null) return;
    _active = true;
    final cancelled = await nav.push<bool>(MaterialPageRoute(
      builder: (_) => _CountdownScreen(what: what),
      fullscreenDialog: true,
    ));
    _active = false;
    if (cancelled != true) {
      // Not cancelled: start a silent Level-3 SOS.
      await FaceActions.handleSos();
    }
  }
}

class _CountdownScreen extends StatefulWidget {
  const _CountdownScreen({required this.what});
  final String what;

  @override
  State<_CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<_CountdownScreen> {
  int _left = 10;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) {
        t.cancel();
        if (mounted) Navigator.pop(context, false); // fire
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.error,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              Text(
                context.trArgs('ai_detected', {'what': widget.what}),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                context.trArgs('ai_sos_in', {'n': '$_left'}),
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).colorScheme.error,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: Text(context.tr('ai_cancel'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              Text(context.tr('ai_false_alarm'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
