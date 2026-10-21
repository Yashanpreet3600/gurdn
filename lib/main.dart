import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/localization/app_strings.dart';
import 'core/services/local_store.dart';
import 'core/services/supabase_service.dart';
import 'core/utils/platform_support.dart';
import 'features/guardian/services/push_background.dart';
import 'features/sos/services/sos_engine.dart';
import 'shared/widgets/unsupported_platform_app.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'features/disguise/disguise_controller.dart';
import 'features/disguise/power_trigger.dart';
import 'features/safetyear/safety_ear.dart';
import 'features/safetyear/ai_trigger.dart';
import 'features/visualguard/visual_guard.dart';
import 'features/triggers/services/bluetooth_trigger.dart';
import 'features/triggers/services/voice_trigger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await LocalStore.init();
  LocaleController.instance.load();
  DisguiseController.instance.load();

  // Chrome or a computer: SMS, GPS and background SOS don't exist there.
  if (!isAndroidDevice) {
    runApp(UnsupportedPlatformApp(
      // Debug builds only: let the developer look at the screens anyway.
      onPreview: kDebugMode
          ? () async {
              if (AppConfig.isConfigured) await SupabaseService.init();
              runApp(const GuardianXApp());
            }
          : null,
    ));
    return;
  }

  if (AppConfig.isConfigured) {
    await SupabaseService.init();

    // Firebase powers guardian push alerts (Phase 2). If the app isn't set
    // up with Firebase yet, this fails quietly and the rest still works.
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    } catch (_) {}

    // Power-button triple-press trigger, if the user turned it on (Phase 4).
    if (PowerTrigger.enabled) {
      try { await PowerTrigger.instance.start(); } catch (_) {}
    }

    // On-device AI features, if turned on (Phase 7). Safety Ear routes a
    // detection through the cancel-countdown before any SOS.
    SafetyEar.instance.onDanger = (label, _) {
      final lang = LocaleController.instance.value.languageCode;
      AiTrigger.raise(AppStrings.get('se_threat_sound', lang));
    };
    if (SafetyEar.enabled) { try { await SafetyEar.instance.start(); } catch (_) {} }
    if (VisualGuard.enabled) { try { await VisualGuard.instance.start(); } catch (_) {} }

    // Extra triggers (Phase 8): Bluetooth button + voice safe word.
    if (BluetoothTrigger.enabled) { try { await BluetoothTrigger.instance.arm(); } catch (_) {} }
    if (VoiceTrigger.enabled) { try { await VoiceTrigger.instance.start(); } catch (_) {} }

    // If an SOS was running when the app closed, start it again right away.
    if (SupabaseService.currentUser != null) {
      try {
        await SosEngine.instance.restore();
      } catch (_) {}
    }
  }

  runApp(const GuardianXApp());
}
