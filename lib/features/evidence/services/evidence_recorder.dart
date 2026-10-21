import 'dart:async';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/utils/platform_support.dart';
import '../data/evidence_repository.dart';

/// Records short audio clips during a Level-3 SOS and hands each one to the
/// EvidenceRepository (which fingerprints and uploads it).
///
/// Audio, not continuous video, is the default: it's far lighter on battery
/// and on the free storage quota during a real emergency, and a phone in a
/// pocket or bag captures useful audio but useless video anyway. Video is a
/// separate manual button on the SOS screen.
///
/// Clips are recorded in segments so that even if the phone is destroyed
/// mid-recording, everything up to the last completed segment is already
/// uploaded.
class EvidenceRecorder {
  EvidenceRecorder._();
  static final instance = EvidenceRecorder._();

  final _recorder = AudioRecorder();
  Timer? _segmentTimer;
  String? _eventId;
  bool _running = false;

  static const _segment = Duration(seconds: 30);

  bool get isRecording => _running;

  /// Begin segmented audio capture for [eventId]. Safe to call twice.
  Future<void> start(String eventId) async {
    if (_running || !isAndroidDevice) return;
    if (!await _recorder.hasPermission()) return;
    _eventId = eventId;
    _running = true;
    await _startSegment();
    // Each segment rolls over to the next, uploading the finished one.
    _segmentTimer = Timer.periodic(_segment, (_) => _rollSegment());
  }

  Future<void> stop() async {
    _segmentTimer?.cancel();
    _segmentTimer = null;
    if (_running) {
      await _finishSegment();
    }
    _running = false;
    _eventId = null;
  }

  Future<void> _startSegment() async {
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '${dir.path}/AUD_$ts.m4a';
    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100),
        path: path,
      );
    } catch (_) {
      _running = false;
    }
  }

  Future<void> _rollSegment() async {
    if (!_running) return;
    await _finishSegment();
    if (_running) await _startSegment();
  }

  Future<void> _finishSegment() async {
    final eventId = _eventId;
    try {
      final path = await _recorder.stop();
      if (path != null && eventId != null) {
        // Fingerprint + upload happens in the repository; don't block here.
        unawaited(EvidenceRepository.instance.capture(
          localPath: path,
          kind: 'audio',
          eventId: eventId,
          durationMs: _segment.inMilliseconds,
        ));
      }
    } catch (_) {}
  }
}
