import 'package:flutter/material.dart';

import 'disguise_controller.dart';
import 'faces/calculator_face.dart';
import 'faces/gallery_face.dart';
import 'faces/notepad_face.dart';
import 'faces/weather_face.dart';

/// Wraps the whole app. If a disguise is set and not yet unlocked this
/// session, it shows the fake app. The real app only appears after the
/// secret unlock, and hides again on the next cold start.
class DisguiseGate extends StatelessWidget {
  const DisguiseGate({super.key, required this.realApp});

  final Widget realApp;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DisguiseController.instance,
      builder: (context, _) {
        final c = DisguiseController.instance;
        if (c.showRealApp) return realApp;
        return _face(c.kind);
      },
    );
  }

  Widget _face(DisguiseKind kind) {
    switch (kind) {
      case DisguiseKind.calculator:
        return const CalculatorFace();
      case DisguiseKind.notepad:
        return const NotepadFace();
      case DisguiseKind.weather:
        return const WeatherFace();
      case DisguiseKind.gallery:
        return const GalleryFace();
      case DisguiseKind.off:
        return const SizedBox.shrink();
    }
  }
}
