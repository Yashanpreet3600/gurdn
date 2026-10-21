import 'package:flutter/material.dart';

import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/role_choice_screen.dart';
import '../../features/auth/screens/sign_up_screen.dart';
import '../../features/auth/screens/verify_email_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/contacts/screens/contacts_setup_screen.dart';
import '../../features/home/guardian_home_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/screens/permissions_screen.dart';
import '../../features/onboarding/screens/test_alert_screen.dart';
import '../../features/profile/models/user_profile.dart';
import '../../features/profile/screens/safety_profile_screen.dart';
import '../../features/security/screens/pin_setup_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/sos/screens/hidden_screen.dart';
import '../../features/sos/screens/sos_active_screen.dart';
import '../../features/sos/screens/sos_history_screen.dart';
import '../../features/sos/screens/sos_settings_screen.dart';
import '../../features/sos/screens/stop_sos_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/readiness/readiness_screen.dart';
import '../../features/guardian/screens/guardian_alert_screen.dart';
import '../../features/timers/screens/safety_timer_screen.dart';
import '../../features/disguise/disguise_settings_screen.dart';
import '../../features/evidence/screens/incident_report_screen.dart';
import '../../features/livevideo/screens/live_viewer_screen.dart';
import '../../features/radar/screens/radar_screen.dart';
import '../../features/deterrent/screens/fake_call_screen.dart';
import '../../features/safetyear/screens/ai_settings_screen.dart';
import '../../features/triggers/screens/triggers_settings_screen.dart';

class AppRoutes {
  AppRoutes._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  static const splash = '/';
  static const configMissing = '/config-missing';
  static const welcome = '/welcome';
  static const roleChoice = '/role';
  static const signUp = '/sign-up';
  static const verifyEmail = '/verify-email';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const safetyProfile = '/setup/profile';
  static const contactsSetup = '/setup/contacts';
  static const permissions = '/setup/permissions';
  static const pinSetup = '/setup/pins';
  static const testAlert = '/setup/test-alert';
  static const home = '/home';
  static const guardianHome = '/guardian';
  static const guardianAlert = '/guardian/alert';
  static const settings = '/settings';
  static const sosActive = '/sos';
  static const stopSos = '/sos/stop';
  static const hiddenSos = '/sos/hidden';
  static const sosSettings = '/sos/settings';
  static const sosHistory = '/sos/history';
  static const readiness = '/readiness';
  static const safetyTimer = '/safety-timer';
  static const disguise = '/disguise';
  static const incidentReport = '/incident-report';
  static const liveViewer = '/live-viewer';
  static const safetyRadar = '/radar';
  static const fakeCall = '/fake-call';
  static const aiSettings = '/ai-settings';
  static const triggers = '/triggers';

  /// Setup screens accept `true` as their argument to open in edit mode
  /// (from Settings) instead of continuing the setup flow.
  static Route<dynamic> onGenerateRoute(RouteSettings route) {
    final args = route.arguments;
    final editMode = args == true;

    final Widget page = switch (route.name) {
      AppRoutes.splash => const SplashScreen(),
      AppRoutes.configMissing => const ConfigMissingScreen(),
      AppRoutes.welcome => const WelcomeScreen(),
      AppRoutes.roleChoice => const RoleChoiceScreen(),
      AppRoutes.signUp => SignUpScreen(role: args is UserRole ? args : UserRole.protected),
      AppRoutes.verifyEmail => VerifyEmailScreen(email: args as String),
      AppRoutes.login => const LoginScreen(),
      AppRoutes.forgotPassword => const ForgotPasswordScreen(),
      AppRoutes.safetyProfile => SafetyProfileScreen(editMode: editMode),
      AppRoutes.contactsSetup => ContactsSetupScreen(editMode: editMode),
      AppRoutes.permissions => PermissionsScreen(editMode: editMode),
      AppRoutes.pinSetup => PinSetupScreen(editMode: editMode),
      AppRoutes.testAlert => const TestAlertScreen(),
      AppRoutes.home => const HomeScreen(),
      AppRoutes.guardianHome => const GuardianHomeScreen(),
      AppRoutes.guardianAlert => GuardianAlertScreen(
          eventId: (args as Map)['eventId'] as String,
          ownerUserId: args['ownerUserId'] as String?,
          ownerName: args['ownerName'] as String?,
          ownerPhone: args['ownerPhone'] as String?,
        ),
      AppRoutes.settings => const SettingsScreen(),
      AppRoutes.sosActive => const SosActiveScreen(),
      AppRoutes.stopSos => const StopSosScreen(),
      AppRoutes.hiddenSos => const HiddenScreen(),
      AppRoutes.sosSettings => const SosSettingsScreen(),
      AppRoutes.sosHistory => const SosHistoryScreen(),
      AppRoutes.readiness => const ReadinessScreen(),
      AppRoutes.safetyTimer => const SafetyTimerScreen(),
      AppRoutes.disguise => const DisguiseSettingsScreen(),
      AppRoutes.incidentReport => IncidentReportScreen(eventId: args as String),
      AppRoutes.liveViewer => LiveViewerScreen(
          eventId: (args as Map)['eventId'] as String,
          ownerName: args['ownerName'] as String?,
        ),
      AppRoutes.safetyRadar => const RadarScreen(),
      AppRoutes.fakeCall => const FakeCallScreen(),
      AppRoutes.aiSettings => const AiSettingsScreen(),
      AppRoutes.triggers => const TriggersSettingsScreen(),
      _ => const SplashScreen(),
    };

    return MaterialPageRoute(builder: (_) => page, settings: route);
  }
}
