import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/services/local_store.dart';
import '../../../core/utils/platform_support.dart';
import '../../disguise/faces/face_actions.dart';

/// "Bachao" voice trigger: listens on-device for a chosen safe word and
/// fires a silent SOS when it hears it. On-device speech recognition, so
/// nothing is sent anywhere.
///
/// ⚠️ Needs testing on a real phone (the speech package can't be run where
/// this was built). Speech recognition isn't perfect and uses battery while
/// listening, so this is an EXTRA trigger — the SOS button, power button and
/// Bluetooth button are the dependable paths.
///
/// The safe word is stored so the user can change it; defaults suit each
/// language. Listening restarts itself, since the recognizer stops after each
/// phrase.
class VoiceTrigger {
  VoiceTrigger._();
  static final instance = VoiceTrigger._();

  final _speech = SpeechToText();
  bool _enabled = false;
  bool _available = false;
  DateTime _lastFire = DateTime.fromMillisecondsSinceEpoch(0);

  static bool get enabled => LocalStore.getBool(LocalKeys.voiceTrigger);

  /// The safe word to listen for (lowercased). Defaults to "bachao".
  static String get safeWord =>
      (LocalStore.getString('voice_safe_word') ?? 'bachao').toLowerCase();

  static Future<void> setSafeWord(String word) =>
      LocalStore.setString('voice_safe_word', word.trim().toLowerCase());

  Future<void> setEnabled(bool on) async {
    await LocalStore.setBool(LocalKeys.voiceTrigger, on);
    if (on) { await start(); } else { await stop(); }
  }

  /// Begin listening. Call at launch if [enabled]. No-op off-device.
  Future<void> start() async {
    if (_enabled || !isAndroidDevice) return;
    _enabled = true;
    try {
      _available = await _speech.initialize(onStatus: _onStatus, onError: (_) => _restart());
      if (_available) _listen();
    } catch (e) {
      if (kDebugMode) debugPrint('VoiceTrigger init failed: $e');
      _enabled = false;
    }
  }

  void _listen() {
    if (!_enabled || !_available) return;
    _speech.listen(
      onResult: (r) {
        final heard = r.recognizedWords.toLowerCase();
        if (heard.contains(safeWord)) _fire();
      },
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 3),
      localeId: null,
      listenOptions: SpeechListenOptions(partialResults: true, cancelOnError: false),
    );
  }

  void _onStatus(String status) {
    // The recognizer stops after a phrase/timeout; keep it going.
    if (_enabled && (status == 'done' || status == 'notListening')) _restart();
  }

  void _restart() {
    if (!_enabled) return;
    Future.delayed(const Duration(milliseconds: 400), _listen);
  }

  void _fire() {
    final now = DateTime.now();
    if (now.difference(_lastFire).inSeconds < 5) return;
    _lastFire = now;
    FaceActions.handleSos();
  }

  Future<void> stop() async {
    _enabled = false;
    try { await _speech.stop(); } catch (_) {}
  }
}
