import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../data/rtc_signaling.dart';

/// The guardian side of live video: asks to watch, shows the incoming
/// stream, and can send remote controls (flashlight, switch camera).
///
/// The viewer creates the offer, so the broadcaster only turns its camera
/// on when someone actually watches.
class Viewer {
  Viewer({required this.eventId});

  final String eventId;

  final renderer = RTCVideoRenderer();
  RtcSignaling? _sig;
  RTCPeerConnection? _pc;
  StreamSubscription<RtcSignal>? _sub;

  final _state = StreamController<ViewerState>.broadcast();
  Stream<ViewerState> get state => _state.stream;
  ViewerState _current = ViewerState.connecting;

  Future<void> start() async {
    await renderer.initialize();
    _sig = RtcSignaling(eventId: eventId, role: 'viewer');
    await _sig!.connect();
    _sub = _sig!.signals.listen(_onSignal);

    final ice = await _sig!.iceServers();
    _pc = await createPeerConnection({'iceServers': ice, 'sdpSemantics': 'unified-plan'});

    // We only receive.
    await _pc!.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );
    await _pc!.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );

    _pc!.onTrack = (e) {
      if (e.streams.isNotEmpty) {
        renderer.srcObject = e.streams.first;
        _set(ViewerState.live);
      }
    };
    _pc!.onIceCandidate = (c) {
      if (c.candidate != null) {
        _sig!.send('ice', {'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex});
      }
    };
    _pc!.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _set(ViewerState.ended);
      }
    };

    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    await _sig!.send('offer', {'sdp': offer.sdp, 'type': offer.type});
  }

  Future<void> _onSignal(RtcSignal s) async {
    switch (s.kind) {
      case 'answer':
        await _pc?.setRemoteDescription(
            RTCSessionDescription(s.payload['sdp'] as String, s.payload['type'] as String));
      case 'ice':
        try {
          await _pc?.addCandidate(RTCIceCandidate(
              s.payload['candidate'] as String?, s.payload['sdpMid'] as String?,
              (s.payload['sdpMLineIndex'] as num?)?.toInt()));
        } catch (_) {}
      case 'bye':
        _set(ViewerState.ended);
    }
  }

  Future<void> toggleFlashlight(bool on) => _sig?.send('control', {'flashlight': on}) ?? Future.value();
  Future<void> switchCamera() => _sig?.send('control', {'switch_camera': true}) ?? Future.value();

  void _set(ViewerState s) {
    _current = s;
    _state.add(s);
  }

  ViewerState get currentState => _current;

  Future<void> dispose() async {
    await _sub?.cancel();
    await _pc?.close();
    renderer.srcObject = null;
    await renderer.dispose();
    await _sig?.dispose();
    await _state.close();
  }
}

enum ViewerState { connecting, live, ended }
