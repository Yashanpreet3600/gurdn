import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../shared/widgets/pin_pad.dart';
import '../../security/pin_service.dart';
import '../services/sos_engine.dart';
import '../sos_actions.dart';

/// Stopping the SOS needs the safety PIN, so an attacker can't end it.
/// The duress PIN looks exactly the same but keeps the SOS running.
class StopSosScreen extends StatefulWidget {
  const StopSosScreen({super.key});

  @override
  State<StopSosScreen> createState() => _StopSosScreenState();
}

class _StopSosScreenState extends State<StopSosScreen> {
  static const _maxTries = 5;

  String? _error;
  int _wrong = 0;
  int _lockRounds = 0;
  DateTime? _lockedUntil;
  Timer? _lockTimer;
  bool _working = false;

  bool get _locked => _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  Future<void> _onPin(String pin) async {
    if (_locked || _working) return;
    final stoppedLabel = context.tr('sos_stopped');
    final wrongLabel = context.tr('pin_wrong');
    final messenger = ScaffoldMessenger.of(context);

    final result = await PinService.hasPins() ? await PinService.check(pin) : PinCheck.safe;
    if (!mounted) return;

    switch (result) {
      case PinCheck.safe:
        setState(() => _working = true);
        await SosEngine.instance.stop();
        SosActions.goHome();
        messenger.showSnackBar(SnackBar(content: Text(stoppedLabel)));
      case PinCheck.duress:
        // Exactly the same as a real stop on screen. Alerts continue in secret.
        setState(() => _working = true);
        await SosEngine.instance.enterDuress();
        SosActions.goHome();
        messenger.showSnackBar(SnackBar(content: Text(stoppedLabel)));
      case PinCheck.wrong:
        _wrong++;
        if (_wrong >= _maxTries) _startLock();
        setState(() => _error = wrongLabel);
    }
  }

  /// After 5 wrong PINs, wait 30 s, then 60 s, then 90 s...
  void _startLock() {
    _wrong = 0;
    _lockRounds++;
    _lockedUntil = DateTime.now().add(Duration(seconds: 30 * _lockRounds));
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_locked) {
        t.cancel();
        _lockedUntil = null;
      }
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final secondsLeft = _locked ? _lockedUntil!.difference(DateTime.now()).inSeconds + 1 : 0;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Text(
              context.tr('stop_sos_title'),
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(context.tr('stop_sos_body')),
            const SizedBox(height: 28),
            if (_working)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              PinPad(
                length: PinService.pinLength,
                enabled: !_locked,
                errorText: _locked
                    ? context.trArgs('pin_locked', {'s': '$secondsLeft'})
                    : _error,
                onCompleted: _onPin,
              ),
          ],
        ),
      ),
    );
  }
}
