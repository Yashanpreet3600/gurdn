import 'package:shared_preferences/shared_preferences.dart';

/// Keys for small values kept on the phone.
class LocalKeys {
  LocalKeys._();

  static const language = 'app_language';

  // Onboarding progress, so setup resumes where it stopped.
  static const obProfileDone = 'ob_profile_done';
  static const obPermissionsDone = 'ob_permissions_done';

  // Cached profile, so the home screen opens without internet.
  static const cachedRole = 'cached_role';
  static const cachedName = 'cached_name';
  static const cachedOnboardingDone = 'cached_onboarding_done';

  // SOS: everything an SOS needs is kept on the phone, so it works offline.
  static const activeSos = 'sos_active_session';
  static const sosQueue = 'sos_offline_queue';
  static const cachedContacts = 'cached_contacts';
  static const cachedSosSettings = 'cached_sos_settings';
  static const lastPosition = 'last_position';

  // Guardian setting: let this phone relay alert SMS from its SIM (Phase 2).
  static const smsRelayOptIn = 'sms_relay_opt_in';

  // When a test alert last reached at least one contact (Readiness check).
  static const lastTestAt = 'last_test_at';

  // The Safety check has opened by itself once after setup.
  static const readinessShown = 'readiness_shown';

  // Phase 4 disguise mode.
  static const disguise = 'disguise_kind';        // off|calculator|notepad|weather|gallery
  static const disguiseNotes = 'disguise_notes';  // the fake notepad's real notes
  static const powerTrigger = 'power_trigger';    // triple-press power -> SOS

  // Phase 5: evidence waiting to upload (captured offline).
  static const evidenceQueue = 'evidence_queue';

  // Phase 7: on-device AI features (experimental, off by default).
  static const safetyEar = 'safety_ear';       // listen for screams/glass
  static const visualGuard = 'visual_guard';   // camera watches for a weapon

  // Phase 8: extra SOS triggers.
  static const bluetoothTrigger = 'bluetooth_trigger'; // a paired BLE button
  static const bluetoothDeviceId = 'bluetooth_device_id';
  static const voiceTrigger = 'voice_trigger';         // say the safe word
}

/// Small wrapper around SharedPreferences, loaded once at startup.
class LocalStore {
  LocalStore._();

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String? getString(String key) => _prefs.getString(key);

  static Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  static bool getBool(String key) => _prefs.getBool(key) ?? false;

  static Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  static Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  /// Clears everything tied to the signed-in user but keeps the language.
  static Future<void> clearUserData() async {
    final language = getString(LocalKeys.language);
    await _prefs.clear();
    if (language != null) await setString(LocalKeys.language, language);
  }
}
