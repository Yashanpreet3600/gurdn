import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../onboarding/onboarding_flow.dart';
import '../data/auth_repository.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _cooldownSeconds = 60;

  final _code = TextEditingController();
  bool _loading = false;
  int _cooldown = _cooldownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != AppConfig.emailCodeLength || _loading) return;

    setState(() => _loading = true);
    try {
      await AuthRepository.instance.verifySignupCode(widget.email, code);
      if (!mounted) return;
      await OnboardingFlow.goNext(context);
    } catch (e) {
      if (!mounted) return;
      _code.clear();
      showMessage(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await AuthRepository.instance.resendSignupCode(widget.email);
      if (!mounted) return;
      showMessage(context, context.tr('code_resent'));
      setState(() => _cooldown = _cooldownSeconds);
      _startTimer();
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('verify_title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.mark_email_read_outlined, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              context.trArgs('verify_body', {
                'n': '${AppConfig.emailCodeLength}',
                'email': widget.email,
              }),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            CodeField(
              controller: _code,
              length: AppConfig.emailCodeLength,
              onCompleted: (_) => _verify(),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: context.tr('verify'), onPressed: _verify, loading: _loading),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _cooldown > 0 ? null : _resend,
              child: Text(
                _cooldown > 0
                    ? context.trArgs('resend_in', {'s': '$_cooldown'})
                    : context.tr('resend_code'),
              ),
            ),
            Text(
              context.tr('check_spam'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
