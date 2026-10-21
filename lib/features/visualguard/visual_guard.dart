import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/localization/app_strings.dart';
import '../../core/services/local_store.dart';
import '../../core/utils/platform_support.dart';
import '../safetyear/ai_trigger.dart';

/// Visual Guard: the phone's camera watches for a weapon (or a persistent
/// follower) and raises the AI cancel-countdown, which starts a silent SOS
/// if you don't cancel.
///
/// ⚠️ EXPERIMENTAL and UNVERIFIED IN THE BUILD SANDBOX. Phone-based weapon
/// detection is unreliable and the model can't be run where this was
/// written. It is OFF by default, and every detection goes through the
/// 10-second cancel-countdown (never an instant SOS), so a misread object
/// can be waved off before anyone is alerted. Carried from the old
/// GuardianX 2.0 "weapons / follower_tracking" categories.
///
/// On-device test sign-off:
///   1. `flutter pub get` resolves the detection package.
///   2. A weapon-detection TFLite model is in assets/models/ (SETUP.md).
///   3. Pointing the camera at a test object raises the countdown.
///
/// This file keeps the wiring (enable/disable, the detection loop shape) but
/// leaves the actual per-frame inference call behind `_classifyFrame`, which
/// returns nothing until a real model is wired in on-device. That means the
/// feature is safe to ship disabled and does nothing until you add the model
/// and confirm it works.
class VisualGuard {
  VisualGuard._();
  static final instance = VisualGuard._();

  bool _running = false;
  Timer? _loop;

  static bool get enabled => LocalStore.getBool(LocalKeys.visualGuard);

  bool get isRunning => _running;

  Future<void> setEnabled(bool on) async {
    await LocalStore.setBool(LocalKeys.visualGuard, on);
    if (on) {
      await start();
    } else {
      await stop();
    }
  }

  /// Begin watching. Needs the camera; only runs during a session the app
  /// starts it in (e.g. an armed walk). No-op off-device or without a model.
  Future<void> start() async {
    if (_running || !isAndroidDevice) return;
    _running = true;
    // Sample a frame every second (cheap; weapon presence isn't instant).
    _loop = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    if (!_running) return;
    try {
      final hit = await _classifyFrame();
      if (hit != null) {
        // Pause so we don't raise repeatedly while the countdown shows.
        _running = false;
        _loop?.cancel();
        final lang = LocaleController.instance.value.languageCode;
        await AiTrigger.raise(AppStrings.get('vg_threat_$hit', lang));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('VisualGuard tick failed: $e');
    }
  }

  /// Returns a threat key ('weapon' | 'follower') or null.
  ///
  /// TODO (on-device): grab a camera frame and run the weapon/follower model.
  /// Until a model is wired in and tested on a phone, this returns null, so
  /// Visual Guard is inert rather than firing false alarms from nothing.
  Future<String?> _classifyFrame() async {
    return null;
  }

  Future<void> stop() async {
    _running = false;
    _loop?.cancel();
    _loop = null;
  }
}
