import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/routing/app_routes.dart';
import '../../core/utils/helpers.dart';
import '../../shared/widgets/common_widgets.dart';
import '../auth/data/auth_repository.dart';
import '../onboarding/onboarding_flow.dart';

/// First screen. Sends the user to welcome, setup, or home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    if (_error != null) setState(() => _error = null);

    if (!AuthRepository.instance.isSignedIn) {
      Navigator.pushReplacementNamed(context, AppRoutes.welcome);
      return;
    }
    try {
      await OnboardingFlow.goNext(context);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 88),
                const SizedBox(height: 16),
                Text(
                  'GuardianX',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 32),
                if (_error == null)
                  const CircularProgressIndicator()
                else ...[
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _route, child: Text(context.tr('retry'))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when the app was started without the Supabase keys.
class ConfigMissingScreen extends StatelessWidget {
  const ConfigMissingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.settings_outlined, size: 48),
              const SizedBox(height: 16),
              Text(context.tr('config_missing_title'), style: text.headlineSmall),
              const SizedBox(height: 8),
              Text(context.tr('config_missing_body'), style: text.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
