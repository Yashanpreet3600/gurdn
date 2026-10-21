
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/services/local_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../onboarding_flow.dart';
import '../../../core/utils/platform_support.dart';

class _PermItem {
  const _PermItem(this.permission, this.icon, this.textKey, {this.essential = false});

  final Permission permission;
  final IconData icon;

  /// Title is "perm_<textKey>", explanation is "perm_<textKey>_why".
  final String textKey;

  /// SOS can't really work without these.
  final bool essential;
}

/// Setup step 3. One card per permission, each saying why it's needed.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, this.editMode = false});

  final bool editMode;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  late final List<_PermItem> _items = [
    const _PermItem(Permission.locationWhenInUse, Icons.location_on_outlined, 'location',
        essential: true),
    const _PermItem(Permission.locationAlways, Icons.my_location, 'bg_location'),
    const _PermItem(Permission.camera, Icons.videocam_outlined, 'camera'),
    const _PermItem(Permission.microphone, Icons.mic_none, 'mic'),
    if (isAndroidDevice)
      const _PermItem(Permission.sms, Icons.sms_outlined, 'sms', essential: true),
    const _PermItem(Permission.notification, Icons.notifications_none, 'notif'),
    if (isAndroidDevice)
      const _PermItem(
          Permission.ignoreBatteryOptimizations, Icons.battery_charging_full, 'battery'),
  ];

  final Map<Permission, PermissionStatus> _status = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check when the user comes back from the system Settings app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final next = <Permission, PermissionStatus>{};
    for (final item in _items) {
      next[item.permission] = await item.permission.status;
    }
    if (mounted) {
      setState(() => _status
        ..clear()
        ..addAll(next));
    }
  }

  bool _granted(Permission p) {
    final s = _status[p];
    return s != null && (s.isGranted || s.isLimited);
  }

  Future<void> _request(_PermItem item) async {
    // Android only offers "all the time" after normal location is allowed.
    if (item.permission == Permission.locationAlways &&
        !_granted(Permission.locationWhenInUse)) {
      showMessage(context, context.tr('perm_location_first'));
      return;
    }
    final current = await item.permission.status;
    if (current.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      await item.permission.request();
    }
    await _refresh();
  }

  /// Asks for the simple ones in a row. Background location and battery
  /// open system pages, so they stay as separate taps.
  Future<void> _allowAll() async {
    setState(() => _busy = true);
    for (final item in _items) {
      if (_granted(item.permission)) continue;
      if (item.permission == Permission.locationAlways ||
          item.permission == Permission.ignoreBatteryOptimizations) {
        continue;
      }
      await item.permission.request();
    }
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _continue() async {
    final missingEssential = _items.any((i) => i.essential && !_granted(i.permission));
    if (missingEssential) {
      final ok = await confirmDialog(
        context,
        title: context.tr('perm_missing_title'),
        body: context.tr('perm_missing_body'),
        confirmLabel: context.tr('continue_anyway'),
      );
      if (!ok) return;
    }
    if (widget.editMode) {
      if (mounted) Navigator.pop(context);
      return;
    }
    await LocalStore.setBool(LocalKeys.obPermissionsDone, true);
    if (mounted) await OnboardingFlow.goNext(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: widget.editMode ? Text(context.tr('permissions_settings')) : null),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            if (!widget.editMode)
              StepHeader(
                step: 3,
                total: OnboardingFlow.totalSteps,
                title: context.tr('perm_title'),
                subtitle: context.tr('perm_subtitle'),
              ),
            for (final item in _items) _buildTile(item),
            const SizedBox(height: 8),
            SecondaryButton(
              label: context.tr('allow_all'),
              onPressed: _busy ? null : _allowAll,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: context.tr(widget.editMode ? 'done' : 'continue'),
              onPressed: _busy ? null : _continue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(_PermItem item) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final granted = _granted(item.permission);
    final blocked = _status[item.permission]?.isPermanentlyDenied ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.icon, color: granted ? AppTheme.safeGreen : scheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        context.tr('perm_${item.textKey}'),
                        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (item.essential)
                        StatusChip(label: context.tr('essential'), color: scheme.error),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(context.tr('perm_${item.textKey}_why'), style: text.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (granted)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.check_circle, color: AppTheme.safeGreen),
              )
            else
              TextButton(
                onPressed: () => _request(item),
                child: Text(context.tr(blocked ? 'open_settings' : 'allow')),
              ),
          ],
        ),
      ),
    );
  }
}
