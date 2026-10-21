import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/localization/app_strings.dart';
import 'core/routing/app_routes.dart';
import 'features/guardian/services/push_service.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/disguise/disguise_gate.dart';

class GuardianXApp extends StatefulWidget {
  const GuardianXApp({super.key});

  @override
  State<GuardianXApp> createState() => _GuardianXAppState();
}

class _GuardianXAppState extends State<GuardianXApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    if (AppConfig.isConfigured) {
      // Whenever the session ends (sign out, account deleted, session expired),
      // go back to the welcome screen.
      _authSub = SupabaseService.client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.signedOut) {
          PushService.instance.unregister();
          AppRoutes.navigatorKey.currentState
              ?.pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
        } else if (state.session != null) {
          // Signed in (or restored): keep this phone's push token registered.
          PushService.instance.start();
        }
      });
      // Already signed in at launch.
      if (SupabaseService.currentUser != null) {
        PushService.instance.start();
      }
      // When a guardian taps an alert push, open the alert screen.
      PushService.instance.onOpenAlert = (eventId, ownerName) {
        AppRoutes.navigatorKey.currentState?.pushNamed(
          AppRoutes.guardianAlert,
          arguments: {'eventId': eventId, 'ownerName': ownerName},
        );
      };
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DisguiseGate(
      realApp: ValueListenableBuilder<Locale>(
      valueListenable: LocaleController.instance,
      builder: (context, locale, _) => MaterialApp(
        title: 'GuardianX',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        locale: locale,
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        navigatorKey: AppRoutes.navigatorKey,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        initialRoute:
            AppConfig.isConfigured ? AppRoutes.splash : AppRoutes.configMissing,
      ),
    ),
    );
  }
}
