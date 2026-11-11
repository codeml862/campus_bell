import 'dart:io';

import 'package:flutter/services.dart';

/// "Share CampusBell": sends this phone's installed app as
/// `CampusBell.apk` (WhatsApp, Bluetooth, Drive, …).
///
/// Done natively (MainActivity.shareApk) so the receiving app gets a real
/// file name; sharing through a generic plugin showed up as "Untitled".
class ShareApp {
  static const _channel = MethodChannel('campusbell/app');

  static Future<void> share() async {
    if (!Platform.isAndroid) {
      throw 'Sharing the app works on Android phones.';
    }
    await _channel.invokeMethod('shareApk');
  }
}
