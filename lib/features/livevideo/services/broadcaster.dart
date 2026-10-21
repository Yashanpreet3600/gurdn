import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/utils/platform_support.dart';
import '../data/rtc_signaling.dart';

/// The person-in-trouble side of live video. Captures camera + mic and
/// sends the stream to a guardian who asks to watch, during a Level-3 SOS.
///
/// Negotiation: the VIEWER sends the offer (they chose to watch); this side
/// answers with its camera track. Keeping the broadcaster as the answerer
/// means it doesn't spend battery on video until someone is actually
/// watching.
///
/// Remote controls (flashlight, switch camera) arrive as 'control' signals.
class Broadcaster {
  Broadcaster._();
  static final instance = Broadcaster._();

  RtcSignaling? _sig;
  RTCPeerConnection? _pc;
  MediaStream? _stream;
  StreamSubscription<RtcSignal>? _sub;
  bool _running = false;
  bool _frontCamera = false; // start with the back camera (sees attacker/scene)

  bool get isLive => _running;

  /// Begin standing by for a viewer. Camera starts only when an offer comes.
  Future<void> start(String eventId) async {
    if (_running || !isAndroidDevice) return;
    _running = true;
    _sig = RtcSignaling(eventId: eventId, role: 'broadcaster');
    await _sig!.connect();
    _sub = _sig!.signals.listen(_onSignal);
  }

  Future<void> _onSignal(RtcSignal s) async {
    switch (s.kind) {
      case 'offer':
        await _answer(s.payload);
      case 'ice':
        await _addIce(s.payload);
      case 'control':
        await _control(s.payload);
      case 'bye':
        await _tearDownPeer();
    }
  }

  Future<void> _answer(Map<String, dynamic> offer) async {
    await _tearDownPeer(); // one viewer at a time
    final ice = await _sig!.iceServers();
    _pc = await createPeerConnection({'iceServers': ice, 'sdpSemantics': 'unified-plan'});

    _stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': _frontCamera ? 'user' : 'environment'},
    });
    for (final track in _stream!.getTracks()) {
      await _pc!.addTrack(track, _stream!);
    }

    _pc!.onIceCandidate = (c) {
      if (c.candidate != null) {
        _sig!.send('ice', {'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex});
      }
    };

    await _pc!.setRemoteDescription(RTCSessionDescription(offer['sdp'] as String, offer['type'] as String));
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    await _sig!.send('answer', {'sdp': answer.sdp, 'type': answer.type});
  }

  Future<void> _addIce(Map<String, dynamic> p) async {
    try {
      await _pc?.addCandidate(RTCIceCandidate(
          p['candidate'] as String?, p['sdpMid'] as String?, (p['sdpMLineIndex'] as num?)?.toInt()));
    } catch (_) {}
  }

  // Remote controls from the guardian.
  Future<void> _control(Map<String, dynamic> p) async {
    try {
      if (p.containsKey('flashlight')) {
        final track = _stream?.getVideoTracks().firstOrNull;
        if (track != null) await track.setTorch(p['flashlight'] == true);
      }
      if (p['switch_camera'] == true) {
        final track = _stream?.getVideoTracks().firstOrNull;
        if (track != null) {
          await Helper.switchCamera(track);
          _frontCamera = !_frontCamera;
        }
      }
    } catch (_) {}
  }

  Future<void> _tearDownPeer() async {
    await _pc?.close();
    _pc = null;
    await _stream?.dispose();
    _stream = null;
  }

  Future<void> stop() async {
    _running = false;
    await _sub?.cancel();
    _sub = null;
    await _tearDownPeer();
    await _sig?.dispose();
    _sig = null;
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
