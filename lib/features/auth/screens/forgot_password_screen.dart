import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../onboarding/onboarding_flow.dart';
import '../data/auth_repository.dart';

/// Two steps: get a code by email, then enter it with a new password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _codeSent = false;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final email = _email.text.trim();
    try {
      await AuthRepository.instance.sendPasswordResetCode(email);
      if (!mounted) return;
      setState(() => _codeSent = true);
      showMessage(context, context.trArgs('reset_code_sent', {'email': email}));
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    if (_code.text.trim().length != AppConfig.emailCodeLength) {
      showMessage(context, context.tr('err_code'), error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthRepository.instance.resetPasswordWithCode(
        email: _email.text,
        code: _code.text,
        newPassword: _password.text,
      );
      if (!mounted) return;
      showMessage(context, context.tr('password_updated'));
      await OnboardingFlow.goNext(context);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('reset_title'))),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(context.tr(_codeSent ? 'reset_enter_code' : 'reset_body')),
              const SizedBox(height: 20),
              AppTextField(
                controller: _email,
                label: context.tr('email'),
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email(context),
                enabled: !_codeSent,
              ),
              if (_codeSent) ...[
                CodeField(controller: _code, length: AppConfig.emailCodeLength),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _password,
                  label: context.tr('new_password'),
                  validator: Validators.password(context),
                  autofillHints: const [AutofillHints.newPassword],
                ),
                PasswordField(
                  controller: _confirm,
                  label: context.tr('confirm_password'),
                  validator: (v) =>
                      v != _password.text ? context.tr('err_password_match') : null,
                ),
              ],
              const SizedBox(height: 8),
              PrimaryButton(
                label: context.tr(_codeSent ? 'reset_password' : 'send_code'),
                onPressed: _codeSent ? _reset : _sendCode,
                loading: _loading,
              ),
              if (_codeSent)
                TextButton(
                  onPressed: _loading ? null : _sendCode,
                  child: Text(context.tr('resend_code')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
