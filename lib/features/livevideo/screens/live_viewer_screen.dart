import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/localization/app_strings.dart';
import '../services/viewer.dart';

/// Full-screen live video of the person in trouble, for a guardian.
class LiveViewerScreen extends StatefulWidget {
  const LiveViewerScreen({super.key, required this.eventId, this.ownerName});

  final String eventId;
  final String? ownerName;

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> {
  late final Viewer _viewer = Viewer(eventId: widget.eventId);
  ViewerState _state = ViewerState.connecting;
  bool _flashOn = false;

  @override
  void initState() {
    super.initState();
    _viewer.state.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _viewer.start();
  }

  @override
  void dispose() {
    _viewer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _state == ViewerState.live
                  ? RTCVideoView(_viewer.renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_state == ViewerState.connecting)
                            const CircularProgressIndicator(color: Colors.white)
                          else
                            const Icon(Icons.videocam_off, color: Colors.white54, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            _state == ViewerState.connecting
                                ? context.tr('live_connecting')
                                : context.tr('live_ended'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
            ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    if (_state == ViewerState.live)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('LIVE',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.ownerName ?? context.tr('guardian_alert_title'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Remote controls (only meaningful while live)
            if (_state == ViewerState.live)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ctrl(
                      icon: _flashOn ? Icons.flash_on : Icons.flash_off,
                      label: context.tr('live_flashlight'),
                      onTap: () {
                        setState(() => _flashOn = !_flashOn);
                        _viewer.toggleFlashlight(_flashOn);
                      },
                    ),
                    const SizedBox(width: 24),
                    _ctrl(
                      icon: Icons.cameraswitch,
                      label: context.tr('live_switch_camera'),
                      onTap: _viewer.switchCamera,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _ctrl({required IconData icon, required String label, required VoidCallback onTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white24,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.all(16), child: Icon(icon, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
