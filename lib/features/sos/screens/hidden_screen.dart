import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_strings.dart';

/// A black screen, so anyone looking at the phone doesn't see "SOS".
/// The SOS keeps running. Hold anywhere for 3 seconds to come back.
///
/// Honest limit: Android still shows its small green camera/mic dot and the
/// notification can't be removed, so this hides the SOS from a casual look only.
class HiddenScreen extends StatefulWidget {
  const HiddenScreen({super.key});

  @override
  State<HiddenScreen> createState() => _HiddenScreenState();
}

class _HiddenScreenState extends State<HiddenScreen> {
  bool _showHint = true;
  Timer? _hintTimer;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _hintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showHint = false);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _holdTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _exit() {
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // A long press starts after about half a second; 2.5 s more makes it 3 s.
        onLongPressStart: (_) {
          _holdTimer?.cancel();
          _holdTimer = Timer(const Duration(milliseconds: 2500), _exit);
        },
        onLongPressEnd: (_) => _holdTimer?.cancel(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: AnimatedOpacity(
              opacity: _showHint ? 0.6 : 0,
              duration: const Duration(milliseconds: 800),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.tr('hidden_hint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
