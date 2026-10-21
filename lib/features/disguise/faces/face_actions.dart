import 'package:flutter/material.dart';

import '../../sos/services/sos_engine.dart';
import '../disguise_controller.dart';
import 'secret_entry.dart';

/// Carries out the action a secret input resolved to. Shared by every face
/// so the behaviour is identical and tested once.
class FaceActions {
  const FaceActions._();

  static Future<void> handle(BuildContext context, SecretAction action) async {
    switch (action) {
      case SecretAction.unlock:
        DisguiseController.instance.unlock();
      case SecretAction.duressUnlock:
        // Reveal the real app, but the duress flavour: start a silent SOS
        // first so contacts are alerted, then show the app looking normal.
        await _silentSos();
        DisguiseController.instance.unlock();
      case SecretAction.sos:
        // Stay disguised; just fire the alert in the background.
        await _silentSos();
      case SecretAction.none:
        break;
    }
  }

  /// Public entry for triggers outside a face (e.g. the power button).
  static Future<void> handleSos() => _silentSos();

  static Future<void> _silentSos() async {
    try {
      // Level 3, straight to sending — no countdown, no screen change.
      await SosEngine.instance.start(level: 3);
    } catch (_) {
      // Even if the server is unreachable, SMS from the SIM still goes out
      // inside start(); nothing more to do here.
    }
  }
}
