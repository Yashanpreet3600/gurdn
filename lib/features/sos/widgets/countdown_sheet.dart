import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';

/// Short countdown before an SOS goes out, with Cancel and Send now.
/// Returns true if the SOS should be sent.
Future<bool> showSosCountdown(
  BuildContext context, {
  required int seconds,
  required int level,
}) async {
  final go = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _CountdownSheet(seconds: seconds, level: level),
  );
  return go ?? false;
}

class _CountdownSheet extends StatefulWidget {
  const _CountdownSheet({required this.seconds, required this.level});

  final int seconds;
  final int level;

  @override
  State<_CountdownSheet> createState() => _CountdownSheetState();
}

class _CountdownSheetState extends State<_CountdownSheet> {
  late int _left = widget.seconds;
  Timer? _timer;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) {
        _close(true);
      } else {
        HapticFeedback.mediumImpact();
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close(bool go) {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    if (mounted) Navigator.pop(context, go);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('sos_sending_in'), style: text.titleMedium),
              const SizedBox(height: 8),
              Text(
                '$_left',
                style: text.displayLarge?.copyWith(
                  color: AppTheme.sosRed,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                context.tr('level_${widget.level}_name'),
                style: text.titleSmall,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _close(false),
                      child: Text(context.tr('cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.sosRed,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _close(true),
                      child: Text(context.tr('sos_send_now')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
