import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/localization/app_strings.dart';

/// "Tactical Guardian Call": speaks loud, firm phrases aloud to make an
/// attacker think help is coming and being recorded. On-device TTS, free,
/// works offline. Spoken in the app's current language.
class TacticalVoice {
  TacticalVoice._();
  static final instance = TacticalVoice._();

  final _tts = FlutterTts();
  bool _speaking = false;

  bool get isSpeaking => _speaking;

  /// Speak the tactical phrases once, at full volume.
  Future<void> speak(String languageCode) async {
    if (_speaking) return;
    _speaking = true;
    try {
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      // Map our app languages to TTS locales; fall back to English (India).
      await _tts.setLanguage(switch (languageCode) {
        'hi' => 'hi-IN',
        'pa' => 'pa-IN',
        _ => 'en-IN',
      });
      await _tts.awaitSpeakCompletion(true);
      for (final key in ['tactical_1', 'tactical_2', 'tactical_3']) {
        if (!_speaking) break;
        await _tts.speak(AppStrings.get(key, languageCode));
      }
    } catch (_) {
      // TTS not available on this device; nothing else to do.
    } finally {
      _speaking = false;
    }
  }

  Future<void> stop() async {
    _speaking = false;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
