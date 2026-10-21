import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/common_widgets.dart';
import '../contacts/data/contacts_repository.dart';
import '../contacts/models/emergency_contact.dart';
import '../profile/data/profile_repository.dart';
import '../profile/models/user_profile.dart';
import '../sos/data/sos_settings_repository.dart';
import '../sos/models/sos_settings.dart';
import '../sos/services/location_service.dart';
import '../sos/services/sos_engine.dart';
import '../sos/sos_actions.dart';
import '../sos/widgets/sos_button.dart';
import '../readiness/readiness_service.dart';
import '../../core/services/local_store.dart';
import '../../shared/widgets/helpline_row.dart';

/// Home for people who want protection: the SOS button, level choice,
/// setup status and helplines.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _engine = SosEngine.instance;

  UserProfile? _profile;
  List<EmergencyContact> _contacts = ContactsRepository.instance.cachedContacts;
  SosSettings _settings = SosSettingsRepository.instance.cached;
  late int _level = _settings.defaultLevel;
  int _readinessIssues = 0;

  @override
  void initState() {
    super.initState();
    _engine.addListener(_refresh);
    LocationService.instance.warmUp();
    _load();
  }

  @override
  void dispose() {
    _engine.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final settings = await SosSettingsRepository.instance.load();
    if (mounted) {
      setState(() {
        _level = settings.defaultLevel == _settings.defaultLevel ? _level : settings.defaultLevel;
        _settings = settings;
      });
    }
    try {
      final results = await Future.wait([
        ProfileRepository.instance.fetchMine(),
        ContactsRepository.instance.fetchMine(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as UserProfile?;
        _contacts = results[1] as List<EmergencyContact>;
      });
    } catch (_) {
      // Offline: cached name and contacts stay. SOS still works.
    }
    await _checkReadiness();
  }

  /// Counts safety problems for the banner. The first time anything is
  /// wrong after setup, opens the Safety check by itself once.
  Future<void> _checkReadiness() async {
    final results = await ReadinessService.runAll();
    if (!mounted) return;
    final issues = ReadinessService.issues(results);
    setState(() => _readinessIssues = issues);
    if (issues > 0 && !LocalStore.getBool(LocalKeys.readinessShown)) {
      await LocalStore.setBool(LocalKeys.readinessShown, true);
      if (mounted) await _open(AppRoutes.readiness);
    }
  }


  Future<void> _open(String route, {Object? arguments}) async {
    await Navigator.pushNamed(context, route, arguments: arguments);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final name = _profile?.firstName ?? (ProfileRepository.cachedName ?? '').split(' ').first;
    final role = _profile?.role ?? ProfileRepository.cachedRole ?? UserRole.protected;
    final accepted = _contacts.where((c) => c.inviteStatus == InviteStatus.accepted).length;
    final bloodGroup = _profile?.bloodGroup;
    final active = _engine.isVisiblyActive;

    return Scaffold(
      appBar: AppBar(
        title: Text(name.isEmpty ? 'GuardianX' : context.trArgs('hello', {'name': name})),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: context.tr('settings'),
            onPressed: () => _open(AppRoutes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (active) ...[
              Material(
                color: AppTheme.sosRed,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.sosActive),
                  leading: const Icon(Icons.warning_rounded, color: Colors.white),
                  title: Text(
                    context.tr('sos_running_banner'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_readinessIssues > 0) ...[
              Card(
                color: scheme.errorContainer,
                child: ListTile(
                  onTap: () => _open(AppRoutes.readiness),
                  leading: Icon(Icons.health_and_safety_outlined, color: scheme.error),
                  title: Text(context.trArgs('ready_banner', {'n': '$_readinessIssues'})),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (!active) ...[
              SegmentedButton<int>(
                segments: [
                  for (final l in const [1, 2, 3])
                    ButtonSegment(value: l, label: Text(context.tr('level_${l}_short'))),
                ],
                selected: {_level},
                onSelectionChanged: (v) => setState(() => _level = v.first),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('level_${_level}_desc'),
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
            ],
            Center(
              child: SosButton(
                requireArming: _settings.requireArming,
                active: _engine.isActive,
                onSend: () => SosActions.trigger(context, level: _level),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _engine.isActive
                  ? context.tr('sos_running_hint')
                  : _settings.requireArming
                      ? context.tr('sos_hint_arming')
                      : context.trArgs('sos_hint_direct', {'n': '${_settings.countdownSeconds}'}),
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.group_outlined),
                    title: Text(context.tr('emergency_contacts')),
                    subtitle: Text(context.trArgs('contacts_accepted_count', {
                      'accepted': '$accepted',
                      'total': '${_contacts.length}',
                    })),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(AppRoutes.contactsSetup, arguments: true),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(context.tr('safety_profile')),
                    subtitle: Text(
                      bloodGroup != null
                          ? '${context.tr('blood_group')}: $bloodGroup'
                          : context.tr('profile_incomplete'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(AppRoutes.safetyProfile, arguments: true),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: Text(context.tr('sos_settings')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(AppRoutes.sosSettings),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(context.tr('helplines'), style: text.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(context.tr('timer_home_tile')),
                subtitle: Text(context.tr('timer_home_tile_sub')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(AppRoutes.safetyTimer),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.map_outlined),
                title: Text(context.tr('radar_title')),
                subtitle: Text(context.tr('radar_home_sub')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(AppRoutes.safetyRadar),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone_in_talk_outlined),
                title: Text(context.tr('fake_call_title')),
                subtitle: Text(context.tr('fake_call_sub')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(AppRoutes.fakeCall),
              ),
            ),
            const SizedBox(height: 16),
            const HelplineRow(),
            if (role == UserRole.both) ...[
              const SizedBox(height: 24),
              SecondaryButton(
                label: context.tr('people_i_protect'),
                icon: Icons.visibility_outlined,
                onPressed: () => _open(AppRoutes.guardianHome),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
