import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Number pad with dots. Calls [onCompleted] when all digits are entered,
/// then clears itself for the next entry.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onCompleted,
    this.length = 4,
    this.errorText,
    this.enabled = true,
  });

  final ValueChanged<String> onCompleted;
  final int length;
  final String? errorText;
  final bool enabled;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _value = '';

  void _tap(String digit) {
    if (!widget.enabled || _value.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() => _value += digit);

    if (_value.length == widget.length) {
      final pin = _value;
      // Short pause so the last dot fills before the screen changes.
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        setState(() => _value = '');
        widget.onCompleted(pin);
      });
    }
  }

  void _backspace() {
    if (_value.isEmpty) return;
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 9),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _value.length ? scheme.primary : Colors.transparent,
                  border: Border.all(color: scheme.primary, width: 2),
                ),
              ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Center(
            child: widget.errorText == null
                ? null
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      widget.errorText!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
          ),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) _PinKey(label: d, onTap: () => _tap(d))],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 84, height: 84),
            _PinKey(label: '0', onTap: () => _tap('0')),
            _PinKey(icon: Icons.backspace_outlined, onTap: _backspace),
          ],
        ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: label != null ? scheme.surfaceContainerHighest : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(
              child: label != null
                  ? Text(label!, style: Theme.of(context).textTheme.headlineSmall)
                  : Icon(icon),
            ),
          ),
        ),
      ),
    );
  }
}
