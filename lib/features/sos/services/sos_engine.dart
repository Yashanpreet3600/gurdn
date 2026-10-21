import 'dart:async';
import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/local_store.dart';
import '../../../core/services/sms_service.dart';
import '../../../core/utils/id_utils.dart';
import '../../contacts/data/contacts_repository.dart';
import '../../contacts/models/emergency_contact.dart';
import '../../profile/data/profile_repository.dart';
import '../data/sos_event_repository.dart';
import '../data/sos_settings_repository.dart';
import '../models/sos_session.dart';
import '../models/sos_settings.dart';
import 'location_service.dart';
import 'sos_message_builder.dart';
import '../../evidence/services/evidence_recorder.dart';
import '../../evidence/data/evidence_repository.dart';
import '../../livevideo/services/broadcaster.dart';
import '../../safetyear/safety_ear.dart';

class SosStartResult {
  const SosStartResult({required this.contacted, required this.failed, this.noContacts = false});

  final int contacted;
  final int failed;
  final bool noContacts;
}

/// Runs the SOS. Everything starts at the same moment:
///
/// 1. SMS to main contacts, using the last known location (no internet or GPS wait).
/// 2. The SOS is saved to the server, or queued on the phone if offline.
/// 3. A precise GPS fix is taken; a follow-up SMS goes out if it adds something.
///
/// Level 1 stops there (a silent location ping). Levels 2 and 3 keep running:
/// live tracking, a check-in signal every 15 seconds, location update SMS when
/// the person moves, and escalation to backup contacts if no one responds.
/// Live video (level 3) is added in Phase 6.
class SosEngine extends ChangeNotifier {
  SosEngine._();
  static final instance = SosEngine._();

  static const _heartbeatEvery = Duration(seconds: 15);
  static const _updateSmsEvery = Duration(minutes: 5);
  static const _updateSmsDistance = 150.0; // meters

  final _events = SosEventRepository.instance;
  final _location = LocationService.instance;
  final _battery = Battery();

  SosSession? _session;
  SosSettings _settings = SosSettings.defaults;
  List<EmergencyContact> _contacts = [];

  /// Phone number → result. Missing = not alerted, null = sending now.
  final Map<String, SmsResult?> smsStatus = {};

  GxPosition? position;
  int? battery;
  bool serverSynced = false;
  bool locationAllowed = true;

  GxPosition? _lastSmsPosition;
  DateTime? _lastSmsAt;
  bool _lowBatterySent = false;
  static const _lowBatteryPercent = 5;
  Timer? _heartbeat;
  Timer? _escalation;

  SosSession? get session => _session;
  bool get isActive => _session != null;

  /// False while the duress PIN is pretending the SOS stopped.
  bool get isVisiblyActive => _session != null && !_session!.duress;

  List<EmergencyContact> get contacts => _contacts;
  List<EmergencyContact> get primaryContacts => _contacts.where((c) => !c.isBackup).toList();
  List<EmergencyContact> get backupContacts => _contacts.where((c) => c.isBackup).toList();

  /// Who gets messages right now: everyone once backups have been alerted.
  List<EmergencyContact> get _alerted => (_session?.escalated ?? false) ? _contacts : primaryContacts;

  // ───────────────────────── Start ─────────────────────────

  Future<SosStartResult> start({required int level, bool isTest = false}) async {
    if (_session != null) return const SosStartResult(contacted: 0, failed: 0);

    // Everything needed comes from the phone, so no internet is required.
    _settings = SosSettingsRepository.instance.cached;
    _contacts = ContactsRepository.instance.cachedContacts;
    if (_contacts.isEmpty) {
      try {
        _contacts = await ContactsRepository.instance.fetchMine().timeout(const Duration(seconds: 4));
      } catch (_) {}
    }

    final session = SosSession(
      eventId: Ids.uuid(),
      token: Ids.hex(64),
      level: level,
      isTest: isTest,
      startedAt: DateTime.now(),
    );
    _session = session;
    smsStatus.clear();
    _lowBatterySent = false;
    serverSynced = false;
    position = _location.lastKnown;
    _lastSmsPosition = null;
    _lastSmsAt = null;
    await _saveSession();
    notifyListeners();

    final primary = primaryContacts;
    final builder = _builder();
    battery = await _readBattery();

    // 1. SMS first.
    final text = builder.initial(
      levelMessage: _settings.messageFor(level),
      position: position,
      battery: battery,
      trackLink: level >= 2 ? AppConfig.trackingLink(session.token) : null,
      at: session.startedAt,
    );
    final smsFuture = _sendTo(primary, text, trackStatus: true);
    if (position != null) {
      _lastSmsPosition = position;
      _lastSmsAt = DateTime.now();
    }

    // 2. Save the event (queued on the phone when offline).
    unawaited(_events.create(session, position, battery).then((ok) {
      serverSynced = ok;
      notifyListeners();
    }));
    unawaited(_events.addTimeline(session.eventId, 'started', {'level': level, 'test': isTest}));

    if (level == 1) {
      // Silent ping: send, refine the location once, then finish.
      final results = await smsFuture;
      await _preciseFollowUp(builder, primary);
      await _events.heartbeat(session.eventId, position, battery);
      await _events.markEnded(session.eventId);
      await _clearSession();
      return SosStartResult(
        contacted: results.where((r) => r.sent).length,
        failed: results.where((r) => !r.sent).length,
        noContacts: primary.isEmpty,
      );
    }

    // 3. Levels 2 and 3 keep running.
    unawaited(_preciseFollowUp(builder, primary));
    await _startRunning(session);
    return SosStartResult(contacted: primary.length, failed: 0, noContacts: primary.isEmpty);
  }

  /// Resumes an SOS that was running when the app closed.
  Future<void> restore() async {
    final raw = LocalStore.getString(LocalKeys.activeSos);
    if (raw == null || raw.isEmpty) return;
    try {
      _session = SosSession.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      await _clearSession();
      return;
    }
    _settings = SosSettingsRepository.instance.cached;
    _contacts = ContactsRepository.instance.cachedContacts;
    position = _location.lastKnown;
    if (_session!.level == 1) {
      // A ping that was interrupted: just close it.
      await _events.markEnded(_session!.eventId);
      await _clearSession();
      return;
    }
    notifyListeners();
    await _startRunning(_session!);
  }

  Future<void> _startRunning(SosSession session) async {
    final language = LocaleController.instance.value.languageCode;
    locationAllowed = await _location.startTracking(
      onUpdate: (p) {
        position = p;
        notifyListeners();
      },
      // Neutral wording on purpose: anyone glancing at the phone sees nothing alarming.
      notificationTitle: AppStrings.get('notif_title', language),
      notificationText: AppStrings.get('notif_text', language),
    );
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_heartbeatEvery, (_) => _tick());
    unawaited(_tick());
    _scheduleEscalation(session);

    // Level 3 real SOS: capture audio evidence (Phase 5). Not for tests.
    if (session.level >= 3 && !session.isTest) {
      // The mic can only be used by one thing: pause Safety Ear while the
      // SOS records evidence (it resumes when the SOS stops).
      await SafetyEar.instance.stop();
      unawaited(EvidenceRecorder.instance.start(session.eventId));
      // Stand by to share live video if a guardian asks to watch (Phase 6).
      unawaited(Broadcaster.instance.start(session.eventId));
    }
    notifyListeners();
  }

  // ───────────────────────── While running ─────────────────────────

  Future<void> _tick() async {
    final s = _session;
    if (s == null) return;
    battery = await _readBattery();
    await _maybeLowBattery();
    final queueEmpty = await _events.flushQueue();
    final alive = await _events.heartbeat(s.eventId, position, battery);
    serverSynced = queueEmpty && alive;
    await _maybeSendLocationUpdate();
    notifyListeners();
  }

  /// At 5%, send one last location SMS and tell the server the battery is
  /// dying, so when the phone goes silent guardians read "battery died".
  Future<void> _maybeLowBattery() async {
    final s = _session;
    final b = battery;
    if (s == null || b == null || _lowBatterySent || b > _lowBatteryPercent) return;
    _lowBatterySent = true;
    await _sendTo(_alerted, _builder().lowBattery(position, b));
    unawaited(_events.update(s.eventId, {'battery_died_at': DateTime.now().toUtc().toIso8601String()}));
    unawaited(_events.addTimeline(s.eventId, 'low_battery', {'percent': b}));
  }

  /// Texts a new location when the person has moved, at most every 5 minutes.
  /// Useful for guardians who only have SMS.
  Future<void> _maybeSendLocationUpdate() async {
    final p = position;
    final s = _session;
    if (p == null || s == null) return;
    final builder = _builder();

    if (_lastSmsPosition == null) {
      // The first SMS had no location; send one as soon as it exists.
      await _sendTo(_alerted, builder.precise(p));
    } else {
      final dueByTime = _lastSmsAt == null || DateTime.now().difference(_lastSmsAt!) >= _updateSmsEvery;
      if (!dueByTime || p.distanceTo(_lastSmsPosition!) < _updateSmsDistance) return;
      await _sendTo(_alerted, builder.update(p));
      unawaited(_events.addTimeline(s.eventId, 'location_update_sms'));
    }
    _lastSmsPosition = p;
    _lastSmsAt = DateTime.now();
  }

  Future<void> _preciseFollowUp(SosMessageBuilder builder, List<EmergencyContact> to) async {
    final first = position;
    final s = _session;
    final precise = await _location.precise();
    if (precise == null || s == null || _session == null) return;
    position = precise;
    notifyListeners();

    final worthIt = first == null ||
        first.age > const Duration(minutes: 2) ||
        first.distanceTo(precise) > 30 ||
        (first.accuracy > 100 && precise.accuracy < 50);
    if (!worthIt) return;

    await _sendTo(to, builder.precise(precise));
    _lastSmsPosition = precise;
    _lastSmsAt = DateTime.now();
    unawaited(_events.addTimeline(s.eventId, 'precise_location', {
      'accuracy_m': precise.accuracy.round(),
    }));
  }

  // ───────────────────────── Escalation ─────────────────────────

  void _scheduleEscalation(SosSession s) {
    _escalation?.cancel();
    if (s.escalated) return;
    final remaining = Duration(seconds: _settings.escalationSeconds) - DateTime.now().difference(s.startedAt);
    _escalation = Timer(remaining.isNegative ? Duration.zero : remaining, _escalate);
  }

  /// No guardian opened the alert in time: alert backup contacts too.
  /// (Until the guardian page exists in Phase 3, nobody can "open" it,
  /// so this always runs. That's the safe choice.)
  Future<void> _escalate() async {
    final s = _session;
    if (s == null || s.escalated) return;
    if (await _events.anyGuardianResponded(s.eventId)) return;

    s.escalated = true;
    await _saveSession();
    notifyListeners();

    final minutes = (DateTime.now().difference(s.startedAt).inSeconds / 60).ceil();
    final text = _builder().escalation(minutes: minutes, position: position);
    // With no backup contacts, the main contacts get the urgent reminder instead.
    final to = backupContacts.isNotEmpty ? backupContacts : primaryContacts;
    await _sendTo(to, text, trackStatus: backupContacts.isNotEmpty);
    unawaited(_events.markEscalated(s.eventId));
    unawaited(_events.addTimeline(s.eventId, 'escalated', {'to': to.length}));
  }

  // ───────────────────────── Duress and stop ─────────────────────────

  /// Duress PIN: the screen pretends the SOS stopped, but tracking continues
  /// and contacts are told the person was forced to cancel.
  Future<void> enterDuress() async {
    final s = _session;
    if (s == null) return;
    s.duress = true;
    await _saveSession();
    notifyListeners();
    unawaited(_sendTo(_alerted, _builder().duress(position)));
    unawaited(_events.markDuress(s.eventId));
    unawaited(_events.addTimeline(s.eventId, 'duress_pin'));
  }

  /// Safety PIN: really stops everything and tells contacts the person is safe.
  Future<void> stop() async {
    final s = _session;
    if (s == null) return;
    final text = _builder().safe(DateTime.now());
    final to = _alerted;

    _heartbeat?.cancel();
    _escalation?.cancel();
    await _location.stopTracking();
    await EvidenceRecorder.instance.stop();
    await Broadcaster.instance.stop();
    if (SafetyEar.enabled) unawaited(SafetyEar.instance.start());
    unawaited(EvidenceRepository.instance.flushQueue());

    unawaited(_sendTo(to, text));
    unawaited(_events.markEnded(s.eventId));
    unawaited(_events.addTimeline(s.eventId, 'stopped'));
    await _clearSession();
  }

  // ───────────────────────── Helpers ─────────────────────────

  SosMessageBuilder _builder() => SosMessageBuilder(
        language: _settings.smsLanguage,
        name: ProfileRepository.myDisplayName,
        isTest: _session?.isTest ?? false,
      );

  Future<List<SmsResult>> _sendTo(
    List<EmergencyContact> to,
    String text, {
    bool trackStatus = false,
  }) async {
    if (to.isEmpty) return [];
    if (trackStatus) {
      for (final c in to) {
        smsStatus[c.phone] = null;
      }
      notifyListeners();
    }
    final results = await SmsService.sendToAll(to.map((c) => c.phone).toList(), text);
    if (trackStatus) {
      for (final r in results) {
        smsStatus[r.phone] = r;
      }
      notifyListeners();
    }
    final s = _session;
    if (s != null) {
      unawaited(_events.addTimeline(s.eventId, 'sms', {
        'sent': results.where((r) => r.sent).length,
        'failed': results.where((r) => !r.sent).length,
      }));
    }
    return results;
  }

  Future<int?> _readBattery() async {
    try {
      return await _battery.batteryLevel.timeout(const Duration(seconds: 1));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveSession() async {
    final s = _session;
    if (s != null) await LocalStore.setString(LocalKeys.activeSos, jsonEncode(s.toJson()));
  }

  Future<void> _clearSession() async {
    _session = null;
    await LocalStore.remove(LocalKeys.activeSos);
    notifyListeners();
  }
}
