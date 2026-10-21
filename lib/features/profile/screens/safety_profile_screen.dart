import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/services/local_store.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../onboarding/onboarding_flow.dart';
import '../data/profile_repository.dart';

/// Setup step 1. Name and phone are required; the rest is optional.
class SafetyProfileScreen extends StatefulWidget {
  const SafetyProfileScreen({super.key, this.editMode = false});

  final bool editMode;

  @override
  State<SafetyProfileScreen> createState() => _SafetyProfileScreenState();
}

class _SafetyProfileScreenState extends State<SafetyProfileScreen> {
  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _allergies = TextEditingController();
  final _medical = TextEditingController();

  String? _bloodGroup;
  String? _avatarPath;
  String? _avatarUrl;
  File? _newAvatar;
  bool _hasProfileRow = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _allergies, _medical]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final meta = SupabaseService.currentUser?.userMetadata ?? const <String, dynamic>{};
    try {
      final p = await ProfileRepository.instance.fetchMine();
      _hasProfileRow = p != null;
      final savedName = p?.fullName ?? '';
      _name.text = savedName.isNotEmpty ? savedName : (meta['full_name'] as String? ?? '');
      _phone.text = p?.phone ?? (meta['phone'] as String? ?? '');
      _allergies.text = p?.allergies ?? '';
      _medical.text = p?.medicalNotes ?? '';
      _bloodGroup = p?.bloodGroup;
      _avatarPath = p?.avatarPath;
      _avatarUrl = await ProfileRepository.instance.avatarUrl(_avatarPath);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (picked != null && mounted) setState(() => _newAvatar = File(picked.path));
  }

  Future<void> _save({bool basicsOnly = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ProfileRepository.instance;
    final name = _name.text.trim();
    final phone = PhoneUtils.normalize(_phone.text)!;

    try {
      if (!_hasProfileRow) await repo.saveBasics(fullName: name, phone: phone);
      if (!basicsOnly) {
        var path = _avatarPath;
        if (_newAvatar != null) path = await repo.uploadAvatar(_newAvatar!);
        await repo.saveSafetyProfile(
          fullName: name,
          phone: phone,
          bloodGroup: _bloodGroup,
          allergies: _allergies.text,
          medicalNotes: _medical.text,
          avatarPath: path,
        );
      }
      await _finish();
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finish() async {
    if (widget.editMode) {
      if (!mounted) return;
      showMessage(context, context.tr('saved'));
      Navigator.pop(context);
      return;
    }
    await LocalStore.setBool(LocalKeys.obProfileDone, true);
    if (mounted) await OnboardingFlow.goNext(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    ImageProvider? avatar;
    if (_newAvatar != null) {
      avatar = FileImage(_newAvatar!);
    } else if (_avatarUrl != null) {
      avatar = NetworkImage(_avatarUrl!);
    }

    return Scaffold(
      appBar: AppBar(title: widget.editMode ? Text(context.tr('safety_profile')) : null),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  children: [
                    if (!widget.editMode)
                      StepHeader(
                        step: 1,
                        total: OnboardingFlow.totalSteps,
                        title: context.tr('profile_title'),
                        subtitle: context.tr('profile_subtitle'),
                      ),
                    Center(
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: scheme.primaryContainer,
                              backgroundImage: avatar,
                              child: avatar == null
                                  ? Icon(Icons.person, size: 48, color: scheme.onPrimaryContainer)
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: scheme.primary,
                                child: Icon(Icons.camera_alt, size: 16, color: scheme.onPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('profile_photo_hint'),
                      textAlign: TextAlign.center,
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      controller: _name,
                      label: context.tr('full_name'),
                      icon: Icons.person_outline,
                      validator: Validators.required(context),
                      textCapitalization: TextCapitalization.words,
                    ),
                    AppTextField(
                      controller: _phone,
                      label: context.tr('phone'),
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: Validators.phone(context),
                    ),
                    Text(context.tr('blood_group'), style: text.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final group in _bloodGroups)
                          ChoiceChip(
                            label: Text(group),
                            selected: _bloodGroup == group,
                            onSelected: (on) => setState(() => _bloodGroup = on ? group : null),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      controller: _allergies,
                      label: context.tr('allergies'),
                      hint: context.tr('allergies_hint'),
                      icon: Icons.warning_amber_outlined,
                    ),
                    AppTextField(
                      controller: _medical,
                      label: context.tr('medical_notes'),
                      hint: context.tr('medical_hint'),
                      icon: Icons.medical_information_outlined,
                      maxLines: 3,
                    ),
                    InfoCard(icon: Icons.lock_outline, body: context.tr('profile_privacy')),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: context.tr(widget.editMode ? 'save' : 'save_continue'),
                      onPressed: () => _save(),
                      loading: _saving,
                    ),
                    if (!widget.editMode)
                      TextButton(
                        onPressed: _saving ? null : () => _save(basicsOnly: true),
                        child: Text(context.tr('skip_for_now')),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
