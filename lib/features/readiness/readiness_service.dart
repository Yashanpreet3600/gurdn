import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/local_store.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/platform_support.dart';
import '../contacts/data/contacts_repository.dart';
import '../contacts/models/emergency_contact.dart';

/// Everything that must be right for an SOS to actually work.
enum ReadinessItem { sms, locationAlways, notifications, battery, guardians, server, testAlert }

enum ReadinessLevel { ok, warning, problem }

class ReadinessResult {
  const ReadinessResult(this.item, this.level, {this.detail});

  final ReadinessItem item;
  final ReadinessLevel level;

  /// Extra text for the row, e.g. "2 of 3 accepted" or the last test date.
  final String? detail;

  bool get ok => level == ReadinessLevel.ok;
}

/// Phone brands that need their own battery steps. Each has a translated
/// guide "battery_fix_<brand>" in the strings.
enum PhoneBrand { xiaomi, vivo, oppo, samsung, other }

class ReadinessService {
  ReadinessService._();

  static const _device = MethodChannel('gx/device');

  /// A test alert older than this turns the row amber.
  static const testMaxAge = Duration(days: 30);

  /// Runs every check. Checks never throw; a failed check is a "problem".
  static Future<List<ReadinessResult>> runAll() async {
    final results = await Future.wait([
      _permission(ReadinessItem.sms, Permission.sms),
      _permission(ReadinessItem.locationAlways, Permission.locationAlways),
      _permission(ReadinessItem.notifications, Permission.notification),
      _permission(ReadinessItem.battery, Permission.ignoreBatteryOptimizations),
      _guardians(),
      _server(),
      Future.value(testAlert(LocalStore.getString(LocalKeys.lastTestAt), DateTime.now())),
    ]);
    return results;
  }

  /// How many rows need attention (warnings count too).
  static int issues(List<ReadinessResult> results) => results.where((r) => !r.ok).length;

  static Future<ReadinessResult> _permission(ReadinessItem item, Permission p) async {
    if (!isAndroidDevice) return ReadinessResult(item, ReadinessLevel.problem);
    try {
      final granted = await p.status.isGranted;
      return ReadinessResult(item, granted ? ReadinessLevel.ok : ReadinessLevel.problem);
    } catch (_) {
      return ReadinessResult(item, ReadinessLevel.problem);
    }
  }

  static Future<ReadinessResult> _guardians() async {
    try {
      final contacts = await ContactsRepository.instance.fetchMine();
      final accepted = contacts.where((c) => c.inviteStatus == InviteStatus.accepted).length;
      return guardians(accepted, contacts.length);
    } catch (_) {
      return const ReadinessResult(ReadinessItem.guardians, ReadinessLevel.warning);
    }
  }

  /// Pure rule, kept separate so it can be unit-tested.
  /// No contacts at all is a problem; contacts but nobody accepted yet is a
  /// warning (their SIM SMS still works, the app-based help doesn't).
  static ReadinessResult guardians(int accepted, int total) {
    final detail = '$accepted/$total';
    if (total == 0) return ReadinessResult(ReadinessItem.guardians, ReadinessLevel.problem, detail: detail);
    if (accepted == 0) return ReadinessResult(ReadinessItem.guardians, ReadinessLevel.warning, detail: detail);
    return ReadinessResult(ReadinessItem.guardians, ReadinessLevel.ok, detail: detail);
  }

  static Future<ReadinessResult> _server() async {
    try {
      await SupabaseService.client.rpc('keepalive').timeout(const Duration(seconds: 6));
      return const ReadinessResult(ReadinessItem.server, ReadinessLevel.ok);
    } catch (_) {
      // Offline isn't fatal (SMS still works), so it's a warning.
      return const ReadinessResult(ReadinessItem.server, ReadinessLevel.warning);
    }
  }

  /// Pure rule: never tested is a problem; older than [testMaxAge] a warning.
  static ReadinessResult testAlert(String? lastIso, DateTime now) {
    final last = lastIso == null ? null : DateTime.tryParse(lastIso);
    if (last == null) return const ReadinessResult(ReadinessItem.testAlert, ReadinessLevel.problem);
    final detail = last.toIso8601String().substring(0, 10);
    final level = now.difference(last) > testMaxAge ? ReadinessLevel.warning : ReadinessLevel.ok;
    return ReadinessResult(ReadinessItem.testAlert, level, detail: detail);
  }

  /// The phone brand, for the battery guide.
  static Future<PhoneBrand> brand() async {
    if (!isAndroidDevice) return PhoneBrand.other;
    try {
      final m = await _device.invokeMethod<String>('manufacturer') ?? '';
      return brandFrom(m);
    } catch (_) {
      return PhoneBrand.other;
    }
  }

  /// Pure mapping from Build.MANUFACTURER to a guide.
  static PhoneBrand brandFrom(String manufacturer) {
    final m = manufacturer.toLowerCase();
    if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) return PhoneBrand.xiaomi;
    if (m.contains('vivo') || m.contains('iqoo')) return PhoneBrand.vivo;
    if (m.contains('oppo') || m.contains('realme') || m.contains('oneplus')) return PhoneBrand.oppo;
    if (m.contains('samsung')) return PhoneBrand.samsung;
    return PhoneBrand.other;
  }
}
