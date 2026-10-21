import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../onboarding/onboarding_flow.dart';
import '../../profile/models/user_profile.dart';
import '../data/auth_repository.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _consent = false;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consent) {
      showMessage(context, context.tr('err_consent'), error: true);
      return;
    }

    setState(() => _loading = true);
    final email = _email.text.trim();
    try {
      final needsCode = await AuthRepository.instance.signUp(
        name: _name.text,
        email: email,
        password: _password.text,
        phone: PhoneUtils.normalize(_phone.text)!,
        role: widget.role,
      );
      if (!mounted) return;
      if (needsCode) {
        Navigator.pushNamed(context, AppRoutes.verifyEmail, arguments: email);
      } else {
        // Email confirmation is switched off in Supabase: already signed in.
        await OnboardingFlow.goNext(context);
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('signup_title'))),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                AppTextField(
                  controller: _name,
                  label: context.tr('full_name'),
                  icon: Icons.person_outline,
                  validator: Validators.required(context),
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                ),
                AppTextField(
                  controller: _email,
                  label: context.tr('email'),
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email(context),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                ),
                AppTextField(
                  controller: _phone,
                  label: context.tr('phone'),
                  hint: '98765 43210',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone(context),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                ),
                PasswordField(
                  controller: _password,
                  label: context.tr('password'),
                  validator: Validators.password(context),
                  autofillHints: const [AutofillHints.newPassword],
                ),
                PasswordField(
                  controller: _confirm,
                  label: context.tr('confirm_password'),
                  validator: (v) =>
                      v != _password.text ? context.tr('err_password_match') : null,
                  onSubmitted: (_) => _submit(),
                ),
                CheckboxListTile(
                  value: _consent,
                  onChanged: (v) => setState(() => _consent = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    context.tr('consent_text'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: context.tr('create_account'),
                  onPressed: _submit,
                  loading: _loading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
