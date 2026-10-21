import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/services/sms_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../contacts/data/contacts_repository.dart';
import '../../contacts/models/emergency_contact.dart';
import '../../profile/data/profile_repository.dart';
import '../onboarding_flow.dart';
import '../../../core/services/local_store.dart';

/// Setup step 5. Sends a message marked TEST to every contact,
/// which also proves the user's own number and SIM work.
class TestAlertScreen extends StatefulWidget {
  const TestAlertScreen({super.key});

  @override
  State<TestAlertScreen> createState() => _TestAlertScreenState();
}

class _TestAlertScreenState extends State<TestAlertScreen> {
  List<EmergencyContact> _contacts = [];
  final Map<String, SmsResult> _results = {};
  bool _loading = true;
  bool _sending = false;
  bool _finishing = false;

  bool get _sent => _results.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ContactsRepository.instance.fetchMine();
      if (mounted) setState(() => _contacts = list);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _message(BuildContext context) =>
      context.trArgs('test_sms', {'name': ProfileRepository.myDisplayName});

  Future<void> _sendTest() async {
    final message = _message(context);
    final permissionLabel = context.tr('sms_permission_needed');

    if (!await SmsService.ensurePermission()) {
      if (mounted) showMessage(context, permissionLabel, error: true);
      return;
    }
    setState(() {
      _sending = true;
      _results.clear();
    });
    final results = await SmsService.sendToAll(_contacts.map((c) => c.phone).toList(), message);
    if (results.any((r) => r.sent)) {
      await LocalStore.setString(LocalKeys.lastTestAt, DateTime.now().toIso8601String());
    }
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < _contacts.length; i++) {
        _results[_contacts[i].id] = results[i];
      }
      _sending = false;
    });
  }

  Future<void> _finish({bool skipped = false}) async {
    if (skipped) {
      final ok = await confirmDialog(
        context,
        title: context.tr('skip_test_title'),
        body: context.tr('skip_test_body'),
        confirmLabel: context.tr('skip'),
      );
      if (!ok) return;
    }
    setState(() => _finishing = true);
    try {
      await ProfileRepository.instance.markOnboardingComplete();
      if (mounted) await OnboardingFlow.goNext(context);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  StepHeader(
                    step: 5,
                    total: OnboardingFlow.totalSteps,
                    title: context.tr('test_title'),
                    subtitle: context.tr('test_subtitle'),
                  ),
                  InfoCard(
                    icon: Icons.sms_outlined,
                    title: context.tr('test_preview'),
                    body: _message(context),
                  ),
                  const SizedBox(height: 16),
                  for (final c in _contacts) _buildRow(c),
                  const SizedBox(height: 16),
                  if (_sent) ...[
                    Text(context.tr('test_ask_contacts'), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: context.tr('finish_setup'),
                      onPressed: _sending ? null : () => _finish(),
                      loading: _finishing,
                    ),
                    TextButton(
                      onPressed: _sending || _finishing ? null : _sendTest,
                      child: Text(context.tr('send_again')),
                    ),
                  ] else ...[
                    PrimaryButton(
                      label: context.tr('send_test'),
                      icon: Icons.send,
                      onPressed: _contacts.isEmpty ? null : _sendTest,
                      loading: _sending,
                    ),
                    TextButton(
                      onPressed: _sending || _finishing ? null : () => _finish(skipped: true),
                      child: Text(context.tr('skip')),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    context.tr('test_cost_note'),
                    textAlign: TextAlign.center,
                    style: text.bodySmall,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRow(EmergencyContact c) {
    final scheme = Theme.of(context).colorScheme;
    final result = _results[c.id];

    final Widget trailing;
    if (_sending && result == null) {
      trailing = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (result == null) {
      trailing = Icon(Icons.schedule, color: scheme.outline);
    } else if (result.sent) {
      trailing = StatusChip(label: context.tr('sms_sent'), color: AppTheme.safeGreen);
    } else {
      trailing = StatusChip(label: context.tr('sms_failed'), color: scheme.error);
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.person_outline),
      title: Text(c.name),
      subtitle: Text(c.phone),
      trailing: trailing,
    );
  }
}
