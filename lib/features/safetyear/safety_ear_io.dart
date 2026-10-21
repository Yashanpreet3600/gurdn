import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/services/local_store.dart';
import '../../core/utils/platform_support.dart';

/// AI Safety Ear: listens on the phone for screaming, yelling or breaking
/// glass using Google's YAMNet model (bundled in assets/models). Nothing is
/// recorded or uploaded — audio is classified in memory and thrown away.
///
/// YAMNet takes 15,600 samples (0.975 s at 16 kHz) and scores 521 sound
/// classes. We slide a window every ~0.5 s and need two danger windows in a
/// row before calling [onDanger], so one loud bang doesn't fire. A wedding
/// dhol or truck horn is loud but isn't "Screaming", so it doesn't trigger.
class SafetyEar {
  SafetyEar._();
  static final instance = SafetyEar._();

  static const _modelAsset = 'assets/models/yamnet.tflite';
  static const _labelsAsset = 'assets/models/yamnet_labels.txt';
  static const _window = 15600; // samples YAMNet expects
  static const _hop = 7800; // ~0.5 s between checks

  // Danger classes and the score needed. Names match yamnet_labels.txt.
  static const _danger = <String, double>{
    'Screaming': 0.35,
    'Yell': 0.40,
    'Shout': 0.45,
    'Children shouting': 0.45,
    'Crying, sobbing': 0.50,
    'Glass': 0.40,
    'Shatter': 0.35,
  };

  /// Called with the detected label; the app shows the cancel-countdown.
  void Function(String label, double confidence)? onDanger;

  Interpreter? _interpreter;
  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  final Map<int, MapEntry<String, double>> _watch = {}; // label index -> (name, threshold)
  final List<double> _buffer = [];
  bool _running = false;
  bool _busy = false;
  int _hits = 0;

  static bool get enabled => LocalStore.getBool(LocalKeys.safetyEar);
  bool get isRunning => _running;

  Future<void> setEnabled(bool on) async {
    await LocalStore.setBool(LocalKeys.safetyEar, on);
    on ? await start() : await stop();
  }

  Future<void> start() async {
    if (_running || !isAndroidDevice) return;
    try {
      if (!await _recorder.hasPermission()) return;
      _interpreter ??= await Interpreter.fromAsset(_modelAsset);
      if (_watch.isEmpty) {
        final labels = (await rootBundle.loadString(_labelsAsset)).split('\n');
        for (var i = 0; i < labels.length; i++) {
          final t = _danger[labels[i].trim()];
          if (t != null) _watch[i] = MapEntry(labels[i].trim(), t);
        }
      }
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));
      _running = true;
      _sub = stream.listen(_onAudio, onError: (_) {});
    } catch (e) {
      if (kDebugMode) debugPrint('SafetyEar failed to start: $e');
      _running = false;
    }
  }

  void _onAudio(Uint8List bytes) {
    // 16-bit little-endian PCM -> floats in [-1, 1].
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      _buffer.add(data.getInt16(i, Endian.little) / 32768.0);
    }
    if (_buffer.length >= _window && !_busy) {
      _busy = true;
      final input = List<double>.from(_buffer.sublist(0, _window));
      _buffer.removeRange(0, _hop);
      _classify(input);
      _busy = false;
    }
    // Never let the buffer grow without bound if inference falls behind.
    if (_buffer.length > _window * 3) _buffer.removeRange(0, _buffer.length - _window);
  }

  void _classify(List<double> wave) {
    final interpreter = _interpreter;
    if (interpreter == null) return;
    try {
      final output = [List<double>.filled(521, 0.0)];
      interpreter.run(Float32List.fromList(wave), output);
      final scores = output[0];
      for (final e in _watch.entries) {
        if (scores[e.key] >= e.value.value) {
          if (++_hits >= 2) {
            _hits = 0;
            onDanger?.call(e.value.key, scores[e.key]);
          }
          return;
        }
      }
      _hits = 0;
    } catch (e) {
      if (kDebugMode) debugPrint('SafetyEar inference failed: $e');
    }
  }

  Future<void> stop() async {
    _running = false;
    _hits = 0;
    _buffer.clear();
    await _sub?.cancel();
    _sub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
  }
}
