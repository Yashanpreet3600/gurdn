import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';

/// The big SOS button.
///
/// With "tap 3 times to arm" on, three quick taps arm it (so it can't go off
/// in a pocket), then one more tap sends. It disarms itself after 6 seconds.
class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    required this.requireArming,
    required this.onSend,
    this.active = false,
    this.size = 210,
  });

  final bool requireArming;
  final VoidCallback onSend;

  /// An SOS is already running: the button opens it instead.
  final bool active;
  final double size;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> {
  static const _tapWindow = Duration(milliseconds: 1500);
  static const _armedFor = Duration(seconds: 6);

  int _taps = 0;
  DateTime? _firstTap;
  bool _armed = false;
  Timer? _disarm;

  @override
  void dispose() {
    _disarm?.cancel();
    super.dispose();
  }

  void _reset() {
    _disarm?.cancel();
    _taps = 0;
    _firstTap = null;
    _armed = false;
  }

  void _onTap() {
    if (widget.active || !widget.requireArming || _armed) {
      HapticFeedback.heavyImpact();
      setState(_reset);
      widget.onSend();
      return;
    }

    final now = DateTime.now();
    if (_firstTap == null || now.difference(_firstTap!) > _tapWindow) {
      _firstTap = now;
      _taps = 0;
    }
    _taps++;

    if (_taps >= 3) {
      HapticFeedback.heavyImpact();
      setState(() => _armed = true);
      _disarm?.cancel();
      _disarm = Timer(_armedFor, () {
        if (mounted) setState(_reset);
      });
    } else {
      HapticFeedback.selectionClick();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.active
        ? context.tr('sos_btn_open')
        : _armed
            ? context.tr('sos_btn_send')
            : 'SOS';
    final showDots = widget.requireArming && !_armed && !widget.active;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(_armed ? 10 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _armed ? AppTheme.sosRed.withValues(alpha: 0.35) : Colors.transparent,
              width: 6,
            ),
          ),
          child: Material(
            color: _armed ? const Color(0xFFB71C1C) : AppTheme.sosRed,
            shape: const CircleBorder(),
            elevation: 6,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _onTap,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: label == 'SOS' ? 52 : 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: label == 'SOS' ? 4 : 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 12,
          child: showDots
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _taps ? AppTheme.sosRed : AppTheme.sosRed.withValues(alpha: 0.2),
                        ),
                      ),
                  ],
                )
              : null,
        ),
      ],
    );
  }
}
