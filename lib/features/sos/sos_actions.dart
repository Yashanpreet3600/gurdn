import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/routing/app_routes.dart';
import 'data/sos_settings_repository.dart';
import 'services/sos_engine.dart';
import 'widgets/countdown_sheet.dart';

/// What happens when SOS is pressed anywhere in the app.
class SosActions {
  SosActions._();

  static Future<void> trigger(BuildContext context, {required int level, bool isTest = false}) async {
    final engine = SosEngine.instance;
    if (engine.isActive) {
      Navigator.pushNamed(context, AppRoutes.sosActive);
      return;
    }

    final settings = SosSettingsRepository.instance.cached;
    final go = await showSosCountdown(context, seconds: settings.countdownSeconds, level: level);
    if (!go || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    if (level == 1) {
      // Silent ping: no big screen, just a short confirmation.
      final sendingLabel = context.tr('ping_sending');
      final noContactsLabel = context.tr('sos_no_contacts');
      final failedLabel = context.tr('ping_failed');
      final sentTemplate = context.tr('ping_sent');
      messenger.showSnackBar(SnackBar(content: Text(sendingLabel)));
      final result = await engine.start(level: 1, isTest: isTest);
      messenger.hideCurrentSnackBar();
      final message = result.noContacts
          ? noContactsLabel
          : result.contacted == 0
              ? failedLabel
              : sentTemplate.replaceAll('{n}', '${result.contacted}');
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    unawaited(engine.start(level: level, isTest: isTest));
    Navigator.pushNamed(context, AppRoutes.sosActive);
  }

  /// Back to the home screen from anywhere. Safe to call twice.
  static void goHome() => AppRoutes.navigatorKey.currentState?.popUntil((r) => r.isFirst);
}
