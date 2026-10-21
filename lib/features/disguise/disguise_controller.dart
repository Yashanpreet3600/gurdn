import 'package:flutter/foundation.dart';

import '../../core/services/local_store.dart';

enum DisguiseKind { off, calculator, notepad, weather, gallery }

DisguiseKind _parse(String? s) {
  switch (s) {
    case 'calculator':
      return DisguiseKind.calculator;
    case 'notepad':
      return DisguiseKind.notepad;
    case 'weather':
      return DisguiseKind.weather;
    case 'gallery':
      return DisguiseKind.gallery;
    default:
      return DisguiseKind.off;
  }
}

/// Decides, at launch, whether to show a disguise or the real app, and
/// holds the "unlocked for this session" flag.
///
/// How a disguise is left:
///   * Calculator: type the safety PIN, then press "=". Typing "112=" with
///     any leading digits that END in the SOS code fires a silent SOS.
///   * Notepad: type the secret word (the safety PIN) on its own line.
///   * Weather / Gallery: a long-press on a fixed spot opens a PIN pad.
/// The exact unlock gestures live in each face; this class only answers
/// "does a PIN unlock / trigger?" so every face shares one rule.
class DisguiseController extends ChangeNotifier {
  DisguiseController._();
  static final instance = DisguiseController._();

  DisguiseKind _kind = DisguiseKind.off;
  bool _unlocked = false;

  DisguiseKind get kind => _kind;
  bool get isDisguised => _kind != DisguiseKind.off;

  /// True once the real app should be shown (either no disguise, or unlocked
  /// this session). Resets every cold start, so closing the app re-hides it.
  bool get showRealApp => !isDisguised || _unlocked;

  void load() {
    _kind = _parse(LocalStore.getString(LocalKeys.disguise));
    _unlocked = false;
  }

  Future<void> setKind(DisguiseKind kind) async {
    _kind = kind;
    if (kind == DisguiseKind.off) {
      await LocalStore.remove(LocalKeys.disguise);
    } else {
      await LocalStore.setString(LocalKeys.disguise, kind.name);
    }
    notifyListeners();
  }

  /// Call when a face's secret unlock succeeds.
  void unlock() {
    _unlocked = true;
    notifyListeners();
  }

  /// Hide the real app again without closing (e.g. from a "panic hide").
  void relock() {
    if (isDisguised) {
      _unlocked = false;
      notifyListeners();
    }
  }
}
