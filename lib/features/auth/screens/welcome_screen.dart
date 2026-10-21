import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/common_widgets.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(actions: const [LanguageToggle(), SizedBox(width: 8)]),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            const SizedBox(height: 16),
            const Center(child: AppLogo(size: 96)),
            const SizedBox(height: 24),
            Text(
              'GuardianX',
              textAlign: TextAlign.center,
              style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('welcome_tagline'),
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            InfoCard(
              icon: Icons.lock_outline,
              title: context.tr('privacy_title'),
              body: context.tr('privacy_body'),
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: context.tr('get_started'),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.roleChoice),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: context.tr('have_account'),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
            ),
          ],
        ),
      ),
    );
  }
}
