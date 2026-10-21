import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/sms_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../onboarding/onboarding_flow.dart';
import '../../profile/data/profile_repository.dart';
import '../data/contacts_repository.dart';
import '../models/emergency_contact.dart';

/// Setup step 2. Each contact gets an SMS invite with a link to accept.
class ContactsSetupScreen extends StatefulWidget {
  const ContactsSetupScreen({super.key, this.editMode = false});

  final bool editMode;

  @override
  State<ContactsSetupScreen> createState() => _ContactsSetupScreenState();
}

class _ContactsSetupScreenState extends State<ContactsSetupScreen> {
  final _repo = ContactsRepository.instance;
  List<EmergencyContact> _contacts = [];
  bool _loading = true;
  bool _busy = false;

  int get _primaryCount => _contacts.where((c) => !c.isBackup).length;
  int get _backupCount => _contacts.length - _primaryCount;
  bool get _canAddPrimary => _primaryCount < AppConfig.maxPrimaryContacts;
  bool get _canAddBackup => _backupCount < AppConfig.maxBackupContacts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _repo.fetchMine();
      if (mounted) setState(() => _contacts = list);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFromPhone() async {
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!mounted) return;
    if (!granted) {
      showMessage(context, context.tr('contacts_permission_denied'));
      await _openEditor();
      return;
    }
    final picked = await FlutterContacts.openExternalPick();
    if (picked == null || !mounted) return;
    await _openEditor(
      name: picked.displayName,
      phones: picked.phones.map((p) => p.number).toList(),
    );
  }

  Future<void> _openEditor({String name = '', List<String> phones = const []}) async {
    final draft = await showModalBottomSheet<ContactDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ContactEditorSheet(
        initialName: name,
        phones: phones,
        allowPrimary: _canAddPrimary,
        allowBackup: _canAddBackup,
      ),
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final contact = await _repo.add(draft);
      try {
        await _sendInvite(contact);
      } catch (e) {
        // The contact IS saved; only the invite failed. Say so, and keep going.
        if (mounted) showMessage(context, friendlyError(context, e), error: true);
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    } finally {
      // Always refresh, so a saved contact never looks missing.
      await _load();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendInvite(EmergencyContact contact) async {
    // Until your guardian web page exists (Phase 3), the invite carries a code
    // that guardians with the app can paste, instead of a link that can't open.
    final message = AppConfig.hasGuardianWeb
        ? context.trArgs('invite_sms', {
            'name': ProfileRepository.myDisplayName,
            'link': ContactsRepository.inviteLink(contact.inviteToken),
          })
        : context.trArgs('invite_sms_code', {
            'name': ProfileRepository.myDisplayName,
            'code': contact.inviteToken,
          });
    final sentLabel = context.trArgs('invite_sent', {'name': contact.name});
    final failedLabel = context.trArgs('invite_failed', {'name': contact.name});
    final deniedLabel = context.tr('invite_sms_denied');

    if (!await SmsService.ensurePermission()) {
      if (mounted) showMessage(context, deniedLabel, error: true);
      return;
    }
    final result = await SmsService.send(contact.phone, message);
    if (result.sent) await _repo.markInviteSent(contact.id);
    if (mounted) {
      showMessage(context, result.sent ? sentLabel : failedLabel, error: !result.sent);
    }
  }

  Future<void> _onMenu(EmergencyContact contact, String action) async {
    try {
      switch (action) {
        case 'invite':
          await _sendInvite(contact);
          await _load();
        case 'backup':
          final makingPrimary = contact.isBackup;
          if ((makingPrimary && !_canAddPrimary) || (!makingPrimary && !_canAddBackup)) {
            showMessage(context, context.tr('contacts_limit'), error: true);
            return;
          }
          await _repo.setBackup(contact.id, !contact.isBackup);
          await _load();
        case 'remove':
          final ok = await confirmDialog(
            context,
            title: context.tr('remove_contact'),
            body: context.trArgs('remove_contact_body', {'name': contact.name}),
            confirmLabel: context.tr('remove'),
            danger: true,
          );
          if (!ok) return;
          await _repo.remove(contact.id);
          await _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    }
  }

  Future<void> _continue() async {
    if (widget.editMode) {
      Navigator.pop(context);
      return;
    }
    await OnboardingFlow.goNext(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canAdd = (_canAddPrimary || _canAddBackup) && !_busy;

    return Scaffold(
      appBar: AppBar(title: widget.editMode ? Text(context.tr('emergency_contacts')) : null),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  if (!widget.editMode)
                    StepHeader(
                      step: 2,
                      total: OnboardingFlow.totalSteps,
                      title: context.tr('contacts_title'),
                      subtitle: context.tr('contacts_subtitle'),
                    ),
                  if (_contacts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Icon(Icons.group_add_outlined, size: 56, color: scheme.outline),
                          const SizedBox(height: 8),
                          Text(context.tr('contacts_empty'), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  for (final contact in _contacts) _buildTile(contact),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: canAdd ? _pickFromPhone : null,
                      icon: const Icon(Icons.contacts_outlined),
                      label: Text(context.tr('pick_contact')),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: canAdd ? () => _openEditor() : null,
                    icon: const Icon(Icons.dialpad),
                    label: Text(context.tr('enter_manually')),
                  ),
                  if (!_canAddPrimary || !_canAddBackup)
                    Text(
                      context.tr('contacts_limit'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 16),
                  InfoCard(icon: Icons.info_outline, body: context.tr('contacts_info')),
                  const SizedBox(height: 20),
                  if (_primaryCount == 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        context.tr('contacts_need_one'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  PrimaryButton(
                    label: context.tr(widget.editMode ? 'done' : 'continue'),
                    onPressed: (_primaryCount > 0 && !_busy) ? _continue : null,
                    loading: _busy,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTile(EmergencyContact c) {
    final scheme = Theme.of(context).colorScheme;
    final (statusLabel, statusColor) = switch (c.inviteStatus) {
      InviteStatus.accepted => (context.tr('status_accepted'), AppTheme.safeGreen),
      InviteStatus.declined => (context.tr('status_declined'), scheme.error),
      InviteStatus.pending => (
          context.tr(c.inviteSentAt == null ? 'status_not_sent' : 'status_waiting'),
          AppTheme.warningAmber,
        ),
    };
    final relationLabel = context.tr('rel_${c.relation}');
    final initial = c.name.isEmpty ? '?' : c.name.characters.first.toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(child: Text(initial)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: Theme.of(context).textTheme.titleMedium),
                  Text('$relationLabel, ${c.phone}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      StatusChip(label: statusLabel, color: statusColor),
                      if (c.isBackup) StatusChip(label: context.tr('backup'), color: scheme.outline),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (action) => _onMenu(c, action),
              itemBuilder: (_) => [
                if (c.inviteStatus != InviteStatus.accepted)
                  PopupMenuItem(value: 'invite', child: Text(context.tr('resend_invite'))),
                PopupMenuItem(
                  value: 'backup',
                  child: Text(context.tr(c.isBackup ? 'make_primary' : 'make_backup')),
                ),
                PopupMenuItem(value: 'remove', child: Text(context.tr('remove'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactEditorSheet extends StatefulWidget {
  const _ContactEditorSheet({
    required this.initialName,
    required this.phones,
    required this.allowPrimary,
    required this.allowBackup,
  });

  final String initialName;
  final List<String> phones;
  final bool allowPrimary;
  final bool allowBackup;

  @override
  State<_ContactEditorSheet> createState() => _ContactEditorSheetState();
}

class _ContactEditorSheetState extends State<_ContactEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  late final _phone =
      TextEditingController(text: widget.phones.isNotEmpty ? widget.phones.first : '');
  final _email = TextEditingController();
  String _relation = contactRelations.first;
  late bool _isBackup = !widget.allowPrimary;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      ContactDraft(
        name: _name.text.trim(),
        phone: PhoneUtils.normalize(_phone.text)!,
        relation: _relation,
        isBackup: _isBackup,
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canToggle = widget.allowPrimary && widget.allowBackup;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.tr('contact_details'), style: text.titleLarge),
              const SizedBox(height: 16),
              AppTextField(
                controller: _name,
                label: context.tr('name'),
                icon: Icons.person_outline,
                validator: Validators.required(context),
                textCapitalization: TextCapitalization.words,
              ),
              if (widget.phones.length > 1) ...[
                Text(context.tr('choose_number'), style: text.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in widget.phones)
                      ChoiceChip(
                        label: Text(p),
                        selected: _phone.text == p,
                        onSelected: (_) => setState(() => _phone.text = p),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              AppTextField(
                controller: _phone,
                label: context.tr('phone'),
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: Validators.phone(context),
              ),
              AppTextField(
                controller: _email,
                label: context.tr('contact_email'),
                hint: context.tr('contact_email_hint'),
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                // Optional: only checked when something was typed.
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? null
                    : Validators.email(context)(v),
              ),
              Text(context.tr('relation'), style: text.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in contactRelations)
                    ChoiceChip(
                      label: Text(context.tr('rel_$r')),
                      selected: _relation == r,
                      onSelected: (_) => setState(() => _relation = r),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isBackup,
                onChanged: canToggle ? (v) => setState(() => _isBackup = v) : null,
                title: Text(context.tr('backup_contact')),
                subtitle: Text(context.tr('backup_contact_desc')),
              ),
              const SizedBox(height: 12),
              PrimaryButton(label: context.tr('save_send_invite'), onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
