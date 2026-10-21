import '../../core/services/local_store.dart';

/// Chrome/desktop stand-in: Safety Ear needs the phone's microphone and
/// on-device AI, so here it does nothing. Same API as the phone version.
class SafetyEar {
  SafetyEar._();
  static final instance = SafetyEar._();

  void Function(String label, double confidence)? onDanger;

  static bool get enabled => LocalStore.getBool(LocalKeys.safetyEar);
  bool get isRunning => false;

  Future<void> setEnabled(bool on) => LocalStore.setBool(LocalKeys.safetyEar, on);
  Future<void> start() async {}
  Future<void> stop() async {}
}
