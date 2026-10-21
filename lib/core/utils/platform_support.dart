import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// True only on a real Android phone (or emulator).
///
/// Always use this instead of `Platform.isAndroid`: in Chrome, touching
/// `Platform` at all throws, which is what broke contact invites there.
bool get isAndroidDevice => !kIsWeb && Platform.isAndroid;
