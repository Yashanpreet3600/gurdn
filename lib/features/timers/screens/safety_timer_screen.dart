import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../data/timer_repository.dart';

/// Walk-home and Trip mode. Start a timer ("home in 20 min" / "in a cab to
/// X"); if you don't check in by the deadline, the server starts an SOS.
class SafetyTimerScreen extends StatefulWidget {
  const SafetyTimerScreen({super.key});

  @override
  State<SafetyTimerScreen> createState() => _SafetyTimerScreenState();
}

class _SafetyTimerScreenState extends State<SafetyTimerScreen> {
  final _repo = TimerRepository.instance;
  SafetyTimer? _active;
  bool _loading = true;
  bool _busy = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    // Repaint the countdown each second.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _active != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await _repo.active();
      if (mounted) setState(() {
        _active = t;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(Future<void> Function() op) async {
    setState(() => _busy = true);
    try {
      await op();
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('timer_title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _active != null
              ? _running(context, _active!)
              : _start(context),
    );
  }

  // ---------- Start a new timer ----------
  Widget _start(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(context.tr('timer_subtitle')),
        const SizedBox(height: 20),
        _StartCard(
          icon: Icons.directions_walk,
          title: context.tr('walk_home_title'),
          body: context.tr('walk_home_desc'),
          busy: _busy,
          onStart: (minutes, _) =>
              _act(() => _repo.start(kind: 'walk_home', minutes: minutes).then((_) {})),
        ),
        const SizedBox(height: 16),
        _StartCard(
          icon: Icons.local_taxi,
          title: context.tr('trip_title'),
          body: context.tr('trip_desc'),
          isTrip: true,
          busy: _busy,
          onStart: (minutes, destination) => _act(() =>
              _repo.start(kind: 'trip', minutes: minutes, destination: destination).then((_) {})),
        ),
      ],
    );
  }

  // ---------- A running timer ----------
  Widget _running(BuildContext context, SafetyTimer t) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final left = t.remaining;
    final overdue = left.isNegative;
    final grace = Duration(seconds: t.graceSeconds);
    final sosIn = (left + grace);

    String fmt(Duration d) {
      final s = d.inSeconds.abs();
      final m = s ~/ 60;
      return '${m}m ${(s % 60).toString().padLeft(2, '0')}s';
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          color: overdue ? scheme.errorContainer : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(t.isTrip ? Icons.local_taxi : Icons.directions_walk, size: 36),
                const SizedBox(height: 8),
                Text(t.isTrip ? context.tr('trip_title') : context.tr('walk_home_title'),
                    style: text.titleLarge),
                if (t.destination != null && t.destination!.isNotEmpty)
                  Text('${context.tr('trip_destination')}: ${t.destination}'),
                const SizedBox(height: 16),
                Text(
                  overdue ? context.tr('timer_overdue') : context.tr('timer_checkin_by'),
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  overdue ? context.trArgs('timer_sos_in', {'t': fmt(sosIn)}) : fmt(left),
                  style: text.displaySmall?.copyWith(
                    color: overdue ? scheme.error : null,
                    fontFeatures: const [],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: context.tr('timer_arrived'),
          icon: Icons.check_circle_outline,
          loading: _busy,
          onPressed: () => _act(() => _repo.checkIn(t.id)),
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: context.trArgs('timer_add_minutes', {'n': '10'}),
          icon: Icons.add_alarm,
          onPressed: _busy ? null : () => _act(() => _repo.extend(t.id, 10).then((_) {})),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  final ok = await confirmDialog(
                    context,
                    title: context.tr('timer_cancel_title'),
                    body: context.tr('timer_cancel_body'),
                    confirmLabel: context.tr('timer_cancel_confirm'),
                  );
                  if (ok) await _act(() => _repo.cancel(t.id));
                },
          child: Text(context.tr('timer_cancel_confirm')),
        ),
      ],
    );
  }
}

class _StartCard extends StatefulWidget {
  const _StartCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onStart,
    required this.busy,
    this.isTrip = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool isTrip;
  final bool busy;
  final void Function(int minutes, String? destination) onStart;

  @override
  State<_StartCard> createState() => _StartCardState();
}

class _StartCardState extends State<_StartCard> {
  int _minutes = 20;
  final _dest = TextEditingController();

  @override
  void dispose() {
    _dest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(widget.icon),
              const SizedBox(width: 8),
              Text(widget.title, style: text.titleMedium),
            ]),
            const SizedBox(height: 6),
            Text(widget.body, style: text.bodySmall),
            const SizedBox(height: 12),
            if (widget.isTrip) ...[
              AppTextField(
                controller: _dest,
                label: context.tr('trip_destination'),
                hint: context.tr('trip_destination_hint'),
                icon: Icons.place_outlined,
              ),
              const SizedBox(height: 4),
            ],
            Text('${context.tr('timer_duration')}: ${context.trArgs('minutes_short', {'n': '$_minutes'})}'),
            Slider(
              value: _minutes.toDouble(),
              min: 5,
              max: 120,
              divisions: 23,
              label: '$_minutes',
              onChanged: (v) => setState(() => _minutes = v.round()),
            ),
            PrimaryButton(
              label: context.tr('timer_start'),
              loading: widget.busy,
              onPressed: () => widget.onStart(
                  _minutes, widget.isTrip ? _dest.text.trim() : null),
            ),
          ],
        ),
      ),
    );
  }
}
