// Safety Ear. The real version uses on-device AI (tflite_flutter), which
// can't compile for Chrome, so Chrome gets a do-nothing stub instead.
export 'safety_ear_stub.dart' if (dart.library.io) 'safety_ear_io.dart';
