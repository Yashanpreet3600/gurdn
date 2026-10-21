import 'package:flutter/services.dart';

import '../../core/services/local_store.dart';
import '../../core/utils/platform_support.dart';
import 'faces/face_actions.dart';

/// Triple-press the power button -> silent SOS, even over a lock screen or a
/// disguise. The press detection runs in a native foreground service
/// (PowerButtonService.kt); this class starts/stops it and handles the
/// "fire" callback.
class PowerTrigger {
  PowerTrigger._();
  static final instance = PowerTrigger._();

  static const _channel = MethodChannel('gx/power');

  static bool get enabled => LocalStore.getBool(LocalKeys.powerTrigger);

  /// Turn the feature on or off (a user setting).
  Future<void> setEnabled(bool on) async {
    await LocalStore.setBool(LocalKeys.powerTrigger, on);
    if (on) {
      await start();
    } else {
      await stop();
    }
  }

  /// Call at launch if [enabled]. Safe to call repeatedly.
  Future<void> start() async {
    if (!isAndroidDevice) return;
    _channel.setMethodCallHandler(_onCall);
    try {
      await _channel.invokeMethod('start');
    } catch (_) {}
  }

  Future<void> stop() async {
    if (!isAndroidDevice) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method == 'powerTriple') {
      // Native already confirmed three presses; fire the silent SOS.
      await FaceActions.handleSos();
    }
  }
}
