import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/localization/app_strings.dart';
import '../../core/routing/app_routes.dart';
import 'readiness_service.dart';

/// One screen that shows, in green / amber / red, whether an SOS would
/// actually work on this phone right now, with a fix for each problem.
class ReadinessScreen extends StatefulWidget {
  const ReadinessScreen({super.key});

  @override
  State<ReadinessScreen> createState() => _ReadinessScreenState();
}

class _ReadinessScreenState extends State<ReadinessScreen> with WidgetsBindingObserver {
  List<ReadinessResult>? _results;
  PhoneBrand _brand = PhoneBrand.other;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    ReadinessService.brand().then((b) {
      if (mounted) setState(() => _brand = b);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from the phone's Settings: check again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final r = await ReadinessService.runAll();
    if (mounted) setState(() => _results = r);
  }

  Future<void> _fix(ReadinessItem item) async {
    switch (item) {
      case ReadinessItem.sms:
        final s = await Permission.sms.request();
        // Blocked on Android 15+ for APKs: the steps in the card explain
        // "Allow restricted settings"; open the app's settings page for them.
        if (!s.isGranted) await openAppSettings();
      case ReadinessItem.locationAlways:
        if (!await Permission.locationWhenInUse.isGranted) {
          await Permission.locationWhenInUse.request();
        }
        final s = await Permission.locationAlways.request();
        if (!s.isGranted) await openAppSettings();
      case ReadinessItem.notifications:
        final s = await Permission.notification.request();
        if (!s.isGranted) await openAppSettings();
      case ReadinessItem.battery:
        await Permission.ignoreBatteryOptimizations.request();
        await openAppSettings();
      case ReadinessItem.guardians:
        await Navigator.pushNamed(context, AppRoutes.contactsSetup, arguments: true);
      case ReadinessItem.testAlert:
        await Navigator.pushNamed(context, AppRoutes.testAlert);
      case ReadinessItem.server:
        break; // nothing to tap; the card says to check the internet
    }
    await _refresh();
  }

  String _guide(BuildContext context, ReadinessItem item) => switch (item) {
        ReadinessItem.sms => context.tr('ready_sms_fix'),
        ReadinessItem.locationAlways => context.tr('ready_location_fix'),
        ReadinessItem.notifications => context.tr('ready_notifications_fix'),
        ReadinessItem.battery => '${context.tr('ready_battery_fix')}\n\n'
            '${context.tr('battery_fix_${_brand.name}')}',
        ReadinessItem.guardians => context.tr('ready_guardians_fix'),
        ReadinessItem.server => context.tr('ready_server_fix'),
        ReadinessItem.testAlert => context.tr('ready_test_fix'),
      };

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final issues = results == null ? 0 : ReadinessService.issues(results);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('readiness_title')),
        actions: [
          IconButton(
            tooltip: context.tr('retry'),
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: results == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(context.tr('readiness_subtitle')),
                  const SizedBox(height: 12),
                  _Summary(issues: issues),
                  const SizedBox(height: 12),
                  for (final r in results)
                    _ItemCard(
                      result: r,
                      guide: _guide(context, r.item),
                      onFix: r.item == ReadinessItem.server ? null : () => _fix(r.item),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.issues});

  final int issues;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ok = issues == 0;
    return Card(
      color: ok ? Colors.green.withValues(alpha: 0.12) : scheme.errorContainer,
      child: ListTile(
        leading: Icon(ok ? Icons.verified_user : Icons.warning_amber_rounded,
            color: ok ? Colors.green : scheme.error),
        title: Text(ok
            ? context.tr('ready_all_good')
            : context.trArgs('ready_issues', {'n': '$issues'})),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.result, required this.guide, this.onFix});

  final ReadinessResult result;
  final String guide;
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (result.level) {
      ReadinessLevel.ok => (Icons.check_circle, Colors.green),
      ReadinessLevel.warning => (Icons.error_outline, Colors.orange),
      ReadinessLevel.problem => (Icons.cancel, scheme.error),
    };
    final key = result.item.name;
    final title = context.tr('ready_${_snake(key)}');
    final subtitle = result.detail;

    if (result.ok) {
      return Card(
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
        ),
      );
    }
    return Card(
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(subtitle ?? context.tr('how_to_fix')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(guide),
          if (onFix != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onFix, child: Text(context.tr('fix'))),
          ],
        ],
      ),
    );
  }

  // locationAlways -> location_always (matches the string keys).
  static String _snake(String camel) =>
      camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
}
