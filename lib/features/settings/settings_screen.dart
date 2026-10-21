import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/routing/app_routes.dart';
import '../../core/utils/helpers.dart';
import '../auth/data/auth_repository.dart';
import '../profile/data/profile_repository.dart';
import '../profile/models/user_profile.dart';
import '../sos/services/sos_engine.dart';
import '../../core/services/sms_service.dart';
import '../guardian/services/push_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserRole _role = ProfileRepository.cachedRole ?? UserRole.protected;
  bool _working = false;
  bool _relay = PushService.smsRelayEnabled;

  /// Guardian opt-in: let this phone text alerts from its SIM when someone
  /// they protect loses their phone during an SOS.
  Future<void> _setRelay(bool on) async {
    if (on && !await SmsService.ensurePermission()) {
      if (mounted) showMessage(context, context.tr('relay_needs_sms'), error: true);
      return;
    }
    await PushService.instance.setSmsRelay(on);
    if (!mounted) return;
    setState(() => _relay = on);
    if (on) showMessage(context, context.tr('relay_on'));
  }

  Future<void> _setLanguage(String code) async {
    await LocaleController.instance.setLanguage(code);
    try {
      await ProfileRepository.instance.updateLanguage(code);
    } catch (_) {
      // Saved on the phone already; the server copy can update later.
    }
  }

  /// Signing out or deleting the account mid-SOS would stop the alerts.
  bool _blockedBySos() {
    if (!SosEngine.instance.isActive) return false;
    showMessage(context, context.tr('stop_sos_first'), error: true);
    return true;
  }

  Future<void> _signOut() async {
    if (_blockedBySos()) return;
    final ok = await confirmDialog(
      context,
      title: context.tr('sign_out'),
      body: context.tr('sign_out_body'),
      confirmLabel: context.tr('sign_out'),
    );
    if (!ok) return;
    setState(() => _working = true);
    // The app listens for sign-out and returns to the welcome screen.
    await AuthRepository.instance.signOut();
  }

  Future<void> _deleteAccount() async {
    if (_blockedBySos()) return;
    final ok = await confirmDialog(
      context,
      title: context.tr('delete_account'),
      body: context.tr('delete_account_body'),
      confirmLabel: context.tr('delete'),
      danger: true,
    );
    if (!ok) return;
    setState(() => _working = true);
    try {
      await AuthRepository.instance.deleteAccount();
    } catch (e) {
      if (!mounted) return;
      showMessage(context, friendlyError(context, e), error: true);
      setState(() => _working = false);
    }
  }

  void _open(String route) => Navigator.pushNamed(context, route, arguments: true);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget section(String key) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(context.tr(key), style: text.titleSmall?.copyWith(color: scheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: AbsorbPointer(
        absorbing: _working,
        child: ListView(
          children: [
            if (_working) const LinearProgressIndicator(),
            section('settings_language'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder<Locale>(
                valueListenable: LocaleController.instance,
                builder: (context, locale, _) => SegmentedButton<String>(
                  segments: [
                    for (final e in AppStrings.languageNames.entries)
                      ButtonSegment(value: e.key, label: Text(e.value)),
                  ],
                  selected: {locale.languageCode},
                  onSelectionChanged: (s) => _setLanguage(s.first),
                ),
              ),
            ),
            section('settings_safety'),
            ListTile(
              leading: const Icon(Icons.health_and_safety_outlined),
              title: Text(context.tr('readiness_title')),
              onTap: () => Navigator.pushNamed(context, AppRoutes.readiness),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(context.tr('safety_profile')),
              onTap: () => _open(AppRoutes.safetyProfile),
            ),
            if (_role.isProtected) ...[
              ListTile(
                leading: const Icon(Icons.tune),
                title: Text(context.tr('sos_settings')),
                onTap: () => Navigator.pushNamed(context, AppRoutes.sosSettings),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(context.tr('sos_history')),
                onTap: () => Navigator.pushNamed(context, AppRoutes.sosHistory),
              ),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: Text(context.tr('emergency_contacts')),
                onTap: () => _open(AppRoutes.contactsSetup),
              ),
              ListTile(
                leading: const Icon(Icons.dialpad),
                title: Text(context.tr('change_pins')),
                onTap: () => _open(AppRoutes.pinSetup),
              ),
              ListTile(
                leading: const Icon(Icons.sensors),
                title: Text(context.tr('triggers_title')),
                subtitle: Text(context.tr('triggers_sub')),
                onTap: () => Navigator.pushNamed(context, AppRoutes.triggers),
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: Text(context.tr('ai_title')),
                subtitle: Text(context.tr('ai_settings_sub')),
                onTap: () => Navigator.pushNamed(context, AppRoutes.aiSettings),
              ),
              ListTile(
                leading: const Icon(Icons.theater_comedy_outlined),
                title: Text(context.tr('disguise_title')),
                subtitle: Text(context.tr('disguise_settings_sub')),
                onTap: () => Navigator.pushNamed(context, AppRoutes.disguise),
              ),
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(context.tr('permissions_settings')),
                onTap: () => _open(AppRoutes.permissions),
              ),
            ],
            if (_role.isGuardian) ...[
              section('settings_guardian'),
              SwitchListTile(
                secondary: const Icon(Icons.sms_outlined),
                value: _relay,
                onChanged: _setRelay,
                title: Text(context.tr('relay_title')),
                subtitle: Text(context.tr('relay_desc')),
              ),
            ],
            section('settings_account'),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(context.tr('sign_out')),
              onTap: _signOut,
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
              title: Text(context.tr('delete_account'), style: TextStyle(color: scheme.error)),
              onTap: _deleteAccount,
            ),
            const SizedBox(height: 24),
            Center(child: Text('GuardianX 2.0', style: text.bodySmall)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
