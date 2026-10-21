import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';

import '../../../core/services/local_store.dart';
import '../../../core/utils/platform_support.dart';

/// A location fix, small enough to save on the phone.
class GxPosition {
  const GxPosition({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.at,
  });

  final double lat;
  final double lng;

  /// Radius in meters within which the real position lies.
  final double accuracy;
  final DateTime at;

  String get mapsLink =>
      'https://maps.google.com/?q=${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';

  Duration get age => DateTime.now().difference(at);

  double distanceTo(GxPosition other) =>
      Geolocator.distanceBetween(lat, lng, other.lat, other.lng);

  factory GxPosition.fromGeolocator(Position p) => GxPosition(
        lat: p.latitude,
        lng: p.longitude,
        accuracy: p.accuracy,
        at: p.timestamp.toLocal(),
      );

  Map<String, dynamic> toJson() =>
      {'lat': lat, 'lng': lng, 'accuracy': accuracy, 'at': at.toIso8601String()};

  factory GxPosition.fromJson(Map<String, dynamic> m) => GxPosition(
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        accuracy: (m['accuracy'] as num).toDouble(),
        at: DateTime.parse(m['at'] as String),
      );
}

/// Keeps a recent location ready, so pressing SOS never waits for GPS.
///
/// During an SOS, tracking runs as an Android foreground service with a
/// notification. That service is also what keeps the SOS alive when the
/// screen is off or the app is in the background.
class LocationService {
  LocationService._();
  static final instance = LocationService._();

  GxPosition? _last;
  StreamSubscription<Position>? _sub;

  bool get isTracking => _sub != null;

  /// Most recent fix: from memory, or saved on the phone from earlier.
  GxPosition? get lastKnown {
    if (_last != null) return _last;
    final raw = LocalStore.getString(LocalKeys.lastPosition);
    if (raw == null) return null;
    try {
      return _last = GxPosition.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  /// Refreshes the saved location. Called when the home screen opens.
  Future<void> warmUp() async {
    try {
      if (!await hasPermission()) return;
      final os = await Geolocator.getLastKnownPosition();
      if (os != null) _remember(GxPosition.fromGeolocator(os));
      final fresh = await Geolocator.getCurrentPosition(
        locationSettings: _settings(LocationAccuracy.medium, timeLimit: const Duration(seconds: 10)),
      );
      _remember(GxPosition.fromGeolocator(fresh));
    } catch (_) {
      // No fix right now; the saved one stays.
    }
  }

  /// Best fix within [timeout], or null.
  Future<GxPosition?> precise({Duration timeout = const Duration(seconds: 20)}) async {
    try {
      if (!await hasPermission()) return null;
      final p = await Geolocator.getCurrentPosition(
        locationSettings: _settings(LocationAccuracy.best, timeLimit: timeout),
      );
      return _remember(GxPosition.fromGeolocator(p));
    } catch (_) {
      return null;
    }
  }

  /// Continuous tracking with a foreground notification. Returns false if
  /// location permission is missing.
  Future<bool> startTracking({
    required void Function(GxPosition) onUpdate,
    required String notificationTitle,
    required String notificationText,
  }) async {
    if (_sub != null) return true;
    if (!await hasPermission()) return false;

    final LocationSettings settings = isAndroidDevice
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            intervalDuration: const Duration(seconds: 10),
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationTitle: notificationTitle,
              notificationText: notificationText,
              enableWakeLock: true,
            ),
          )
        : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);

    try {
      _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (p) => onUpdate(_remember(GxPosition.fromGeolocator(p))),
        onError: (_) {},
      );
      return true;
    } catch (_) {
      _sub = null;
      return false;
    }
  }

  Future<void> stopTracking() async {
    await _sub?.cancel();
    _sub = null;
  }

  LocationSettings _settings(LocationAccuracy accuracy, {Duration? timeLimit}) => isAndroidDevice
      ? AndroidSettings(accuracy: accuracy, timeLimit: timeLimit)
      : LocationSettings(accuracy: accuracy, timeLimit: timeLimit);

  GxPosition _remember(GxPosition p) {
    _last = p;
    LocalStore.setString(LocalKeys.lastPosition, jsonEncode(p.toJson()));
    return p;
  }
}
