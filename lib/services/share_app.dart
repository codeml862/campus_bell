import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// "Share CampusBell": sends this phone's installed app as
/// `CampusBell.apk` through WhatsApp, Bluetooth, Drive, etc.
///
/// Sharing an app from the launcher (App info → Share) hands WhatsApp an
/// .apk with the Android-package type, which WhatsApp refuses and jumps
/// straight back. Here the file is copied with a proper name and sent as a
/// plain document, which WhatsApp accepts.
class ShareApp {
  static const _channel = MethodChannel('campusbell/app');

  static Future<void> share() async {
    if (!Platform.isAndroid) {
      await SharePlus.instance.share(
        ShareParams(text: 'Install CampusBell on your Android phone.'),
      );
      return;
    }
    final src = await _channel.invokeMethod<String>('apkPath');
    if (src == null) throw 'Could not find the app file.';
    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/CampusBell.apk');
    await File(src).copy(out.path);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            out.path,
            name: 'CampusBell.apk',
            mimeType: 'application/octet-stream',
          ),
        ],
        fileNameOverrides: const ['CampusBell.apk'],
        text: 'CampusBell app. Open the file to install.',
        subject: 'CampusBell',
      ),
    );
  }
}
