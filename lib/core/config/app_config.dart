/// Values passed in at build time, so no keys are written in the source code.
///
/// Run with:  flutter run --dart-define-from-file=env.json
/// (SETUP.md, step 5, explains what goes in env.json)
class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// The anon key, or the newer "publishable" key. Both work here.
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Base address of YOUR guardian web page on Cloudflare Pages (Phase 3).
  /// Leave it empty until that page exists: SMS then contain a Google Maps
  /// link instead, which works for every guardian.
  static const guardianWebBase = String.fromEnvironment('GUARDIAN_WEB_BASE');

  /// Cloudflare Worker base, e.g. https://guardianx-watchdog.<name>.workers.dev
  /// Used for evidence upload/download presigned URLs (Phase 5).
  static const workerBase = String.fromEnvironment('WORKER_BASE');

  static bool get hasWorker => workerBase.isNotEmpty;

  static bool get hasGuardianWeb => guardianWebBase.isNotEmpty;

  /// Live tracking link for one emergency, or null without the web page.
  static String? trackingLink(String sessionToken) =>
      hasGuardianWeb ? '$guardianWebBase/e/$sessionToken' : null;

  /// Must match "Email OTP length" in Supabase Auth settings.
  static const emailCodeLength = 6;

  static const minPrimaryContacts = 1;
  static const maxPrimaryContacts = 5;
  static const maxBackupContacts = 3;

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
