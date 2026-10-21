import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_strings.dart';
import '../../core/routing/app_routes.dart';
import '../../core/utils/helpers.dart';
import '../../shared/widgets/common_widgets.dart';
import '../contacts/data/contacts_repository.dart';
import '../contacts/models/emergency_contact.dart';
import '../../core/services/sms_service.dart';
import '../guardian/services/push_service.dart';
import '../guardian/data/guardian_repository.dart';

/// Home for guardians: accept invites and see who you protect.
/// Live alerts arrive by SMS link (push alerts and the web page come in Phase 3).
class GuardianHomeScreen extends StatefulWidget {
  const GuardianHomeScreen({super.key});

  @override
  State<GuardianHomeScreen> createState() => _GuardianHomeScreenState();
}

class _GuardianHomeScreenState extends State<GuardianHomeScreen> {
  bool _relay = PushService.smsRelayEnabled;

  Future<void> _enableRelay() async {
    if (!await SmsService.ensurePermission()) {
      if (mounted) showMessage(context, context.tr('relay_needs_sms'), error: true);
      return;
    }
    await PushService.instance.setSmsRelay(true);
    if (!mounted) return;
    setState(() => _relay = true);
    showMessage(context, context.tr('relay_on'));
  }

  final _code = TextEditingController();
  List<ProtectedPerson> _people = [];
  Map<String, GuardianAlert> _alerts = {};
  bool _loading = true;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await ContactsRepository.instance.fetchPeopleIProtect();
      if (mounted) setState(() => _people = list);
      try {
        final active = await GuardianRepository.instance.allActiveAlerts();
        if (mounted) setState(() => _alerts = {for (final a in active) a.ownerUserId: a});
      } catch (_) {}
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    final token = ContactsRepository.extractToken(_code.text);
    if (token == null) {
      showMessage(context, context.tr('invite_invalid'), error: true);
      return;
    }
    setState(() => _accepting = true);
    try {
      final name = await ContactsRepository.instance.acceptInvite(token);
      if (!mounted) return;
      _code.clear();
      FocusScope.of(context).unfocus();
      showMessage(context, context.trArgs('invite_accepted', {'name': name}));
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('guardian_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: context.tr('settings'),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            InfoCard(icon: Icons.shield_outlined, body: context.tr('guardian_info')),
            if (!_relay) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('relay_title'),
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(context.tr('relay_desc')),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _enableRelay,
                        icon: const Icon(Icons.sms_outlined),
                        label: Text(context.tr('relay_enable')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(context.tr('accept_invite_title'), style: text.titleMedium),
            const SizedBox(height: 10),
            AppTextField(
              controller: _code,
              label: context.tr('invite_code_label'),
              icon: Icons.link,
              onSubmitted: (_) => _accept(),
            ),
            PrimaryButton(
              label: context.tr('accept_invite'),
              onPressed: _accept,
              loading: _accepting,
            ),
            const SizedBox(height: 28),
            Text(context.tr('people_i_protect'), style: text.titleMedium),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_people.isEmpty)
              Text(context.tr('no_people_yet'), style: text.bodyMedium)
            else
              for (final p in _people)
                Builder(builder: (context) {
                  final alert = _alerts[p.ownerUserId];
                  final live = alert != null;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: live ? Theme.of(context).colorScheme.errorContainer : null,
                    child: ListTile(
                      onTap: live
                          ? () => Navigator.pushNamed(context, AppRoutes.guardianAlert, arguments: {
                                'eventId': alert.eventId,
                                'ownerUserId': p.ownerUserId,
                                'ownerName': p.name,
                                'ownerPhone': p.phone,
                              }).then((_) => _load())
                          : null,
                      leading: CircleAvatar(
                        child: Text(p.name.isEmpty ? '?' : p.name.characters.first.toUpperCase()),
                      ),
                      title: Text(p.name),
                      subtitle: Text(live
                          ? context.tr('guardian_live_now')
                          : context.trArgs('added_you_as',
                              {'relation': context.tr('rel_${p.relation}')})),
                      trailing: live
                          ? const Icon(Icons.chevron_right)
                          : (p.phone.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.call_outlined),
                                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: p.phone)),
                                )),
                    ),
                  );
                }),
          ],
        ),
      ),
    );
  }
}
