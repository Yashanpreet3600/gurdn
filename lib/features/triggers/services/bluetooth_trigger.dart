import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../core/services/local_store.dart';
import '../../../core/utils/platform_support.dart';
import '../../disguise/faces/face_actions.dart';

/// A cheap Bluetooth "panic button" (a ~₹200 BLE tag/remote) that fires an
/// SOS without touching the phone. The user pairs their button once; after
/// that, a press on it starts a silent SOS.
///
/// ⚠️ Cheap BLE buttons vary a lot in how they signal a press. This watches
/// for the button to (re)connect and for any notification from it, which
/// covers the common "iTag"-style buttons. It's an EXTRA trigger, not the
/// main one, exactly because these buttons aren't 100% reliable — the app's
/// own SOS button and the power-button trigger are the dependable paths.
/// Must be tested with your specific button on your phone.
class BluetoothTrigger {
  BluetoothTrigger._();
  static final instance = BluetoothTrigger._();

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  final _notifySubs = <StreamSubscription>[];
  BluetoothDevice? _device;
  bool _armed = false;
  DateTime _lastFire = DateTime.fromMillisecondsSinceEpoch(0);

  static bool get enabled => LocalStore.getBool(LocalKeys.bluetoothTrigger);
  static String? get pairedId => LocalStore.getString(LocalKeys.bluetoothDeviceId);

  bool get isArmed => _armed;

  /// Scan for nearby BLE devices so the user can pick their button.
  Stream<List<ScanResult>> scan() async* {
    if (!isAndroidDevice) return;
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));
    yield* FlutterBluePlus.scanResults;
  }

  Future<void> stopScan() async {
    try { await FlutterBluePlus.stopScan(); } catch (_) {}
  }

  /// Remember this device as the panic button and turn the feature on.
  Future<void> pair(String deviceId) async {
    await LocalStore.setString(LocalKeys.bluetoothDeviceId, deviceId);
    await LocalStore.setBool(LocalKeys.bluetoothTrigger, true);
    await arm();
  }

  Future<void> setEnabled(bool on) async {
    await LocalStore.setBool(LocalKeys.bluetoothTrigger, on);
    if (on) { await arm(); } else { await disarm(); }
  }

  /// Start watching the paired button. Call at launch if [enabled].
  Future<void> arm() async {
    final id = pairedId;
    if (_armed || !isAndroidDevice || id == null) return;
    _armed = true;
    try {
      _device = BluetoothDevice.fromId(id);
      // Watch connection; a button press often toggles connection on cheap tags.
      _connSub = _device!.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.connected) {
          await _subscribeNotifications();
        } else if (state == BluetoothConnectionState.disconnected) {
          // Some buttons "disconnect" on press; try to reconnect quietly.
          try { await _device!.connect(autoConnect: true, mtu: null); } catch (_) {}
        }
      });
      await _device!.connect(autoConnect: true, mtu: null);
    } catch (e) {
      if (kDebugMode) debugPrint('BluetoothTrigger arm failed: $e');
    }
  }

  Future<void> _subscribeNotifications() async {
    try {
      final services = await _device!.discoverServices();
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.properties.notify || c.properties.indicate) {
            await c.setNotifyValue(true);
            _notifySubs.add(c.onValueReceived.listen((_) => _fire()));
          }
        }
      }
    } catch (_) {}
  }

  void _fire() {
    // Debounce: ignore repeats within 5s so one press is one SOS.
    final now = DateTime.now();
    if (now.difference(_lastFire).inSeconds < 5) return;
    _lastFire = now;
    FaceActions.handleSos();
  }

  Future<void> disarm() async {
    _armed = false;
    await _connSub?.cancel();
    _connSub = null;
    for (final s in _notifySubs) { await s.cancel(); }
    _notifySubs.clear();
    try { await _device?.disconnect(); } catch (_) {}
    _device = null;
  }

  Future<void> unpair() async {
    await disarm();
    await LocalStore.remove(LocalKeys.bluetoothDeviceId);
    await LocalStore.setBool(LocalKeys.bluetoothTrigger, false);
  }
}
