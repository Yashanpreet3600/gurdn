import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/pin_pad.dart';
import '../../onboarding/onboarding_flow.dart';
import '../pin_service.dart';

enum _Stage { current, safe, safeConfirm, duress, duressConfirm }

/// Setup step 4: safety PIN (really stops SOS) and duress PIN
/// (pretends to stop it while alerts continue).
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, this.editMode = false});

  final bool editMode;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  _Stage _stage = _Stage.safe;
  String? _safe;
  String? _duress;
  String? _error;
  bool _ready = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  /// Changing existing PINs first asks for the current safety PIN.
  Future<void> _prepare() async {
    final hasPins = await PinService.hasPins();
    if (!mounted) return;
    setState(() {
      _stage = (widget.editMode && hasPins) ? _Stage.current : _Stage.safe;
      _ready = true;
    });
  }

  void _goTo(_Stage stage, {String? error}) {
    setState(() {
      _stage = stage;
      _error = error;
    });
  }

  void _fail(String message) => setState(() => _error = message);

  Future<void> _onPin(String pin) async {
    switch (_stage) {
      case _Stage.current:
        final result = await PinService.check(pin);
        if (!mounted) return;
        if (result == PinCheck.safe) {
          _goTo(_Stage.safe);
        } else {
          _fail(context.tr('pin_wrong'));
        }
      case _Stage.safe:
        if (PinService.isWeak(pin)) {
          _fail(context.tr('pin_weak'));
          return;
        }
        _safe = pin;
        _goTo(_Stage.safeConfirm);
      case _Stage.safeConfirm:
        if (pin != _safe) {
          _safe = null;
          _goTo(_Stage.safe, error: context.tr('pin_mismatch'));
          return;
        }
        _goTo(_Stage.duress);
      case _Stage.duress:
        if (PinService.isWeak(pin)) {
          _fail(context.tr('pin_weak'));
          return;
        }
        if (pin == _safe) {
          _fail(context.tr('pin_same'));
          return;
        }
        _duress = pin;
        _goTo(_Stage.duressConfirm);
      case _Stage.duressConfirm:
        if (pin != _duress) {
          _duress = null;
          _goTo(_Stage.duress, error: context.tr('pin_mismatch'));
          return;
        }
        await _save();
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await PinService.savePins(safePin: _safe!, duressPin: _duress!);
      if (!mounted) return;
      if (widget.editMode) {
        showMessage(context, context.tr('pins_saved'));
        Navigator.pop(context);
      } else {
        await OnboardingFlow.goNext(context);
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  (String, String?) get _texts => switch (_stage) {
        _Stage.current => ('pin_current_title', null),
        _Stage.safe => ('pin_safe_title', 'pin_safe_body'),
        _Stage.safeConfirm => ('pin_confirm_title', 'pin_confirm_safe_body'),
        _Stage.duress => ('pin_duress_title', 'pin_duress_body'),
        _Stage.duressConfirm => ('pin_confirm_title', 'pin_confirm_duress_body'),
      };

  @override
  Widget build(BuildContext context) {
    final (titleKey, bodyKey) = _texts;
    final title = context.tr(titleKey);
    final body = bodyKey == null ? null : context.tr(bodyKey);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: widget.editMode ? Text(context.tr('change_pins')) : null),
      body: SafeArea(
        child: !_ready
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  if (!widget.editMode)
                    StepHeader(
                      step: 4,
                      total: OnboardingFlow.totalSteps,
                      title: title,
                      subtitle: body,
                    )
                  else ...[
                    Text(title, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    if (body != null) ...[const SizedBox(height: 6), Text(body)],
                    const SizedBox(height: 20),
                  ],
                  if (_stage == _Stage.duress) ...[
                    InfoCard(
                      icon: Icons.privacy_tip_outlined,
                      title: context.tr('pin_duress_how_title'),
                      body: context.tr('pin_duress_how'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_saving)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    PinPad(
                      length: PinService.pinLength,
                      errorText: _error,
                      onCompleted: _onPin,
                    ),
                ],
              ),
      ),
    );
  }
}
