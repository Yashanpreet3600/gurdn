import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../onboarding/onboarding_flow.dart';
import '../data/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final email = _email.text.trim();

    try {
      await AuthRepository.instance.signIn(email, _password.text);
      if (!mounted) return;
      await OnboardingFlow.goNext(context);
    } on AuthException catch (e) {
      if (!mounted) return;
      if (AuthRepository.isEmailNotConfirmed(e)) {
        // Account exists but was never verified: send a fresh code.
        try {
          await AuthRepository.instance.resendSignupCode(email);
        } catch (_) {}
        if (!mounted) return;
        showMessage(context, context.tr('email_not_confirmed'));
        Navigator.pushNamed(context, AppRoutes.verifyEmail, arguments: email);
      } else {
        showMessage(context, friendlyError(context, e), error: true);
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
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
                Text(
                  context.tr('login_title'),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _email,
                  label: context.tr('email'),
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email(context),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                ),
                PasswordField(
                  controller: _password,
                  label: context.tr('password'),
                  validator: Validators.required(context),
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _login(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
                    child: Text(context.tr('forgot_password')),
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(label: context.tr('login'), onPressed: _login, loading: _loading),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.roleChoice),
                  child: Text(context.tr('no_account')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
