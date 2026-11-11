import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// In-app update prompt (free, no Play Store needed).
///
/// To publish an update, edit the Firestore doc `config/app` in the
/// Firebase console:
///   latestBuild   (number)  build number of the new APK, e.g. 2
///                           (the "+2" in pubspec.yaml `version: 1.0.1+2`)
///   latestVersion (string)  shown to users, e.g. "1.0.1"
///   apkUrl        (string)  public download link of the new APK
///                           (Google Drive / GitHub release link)
///   notes         (string)  what's new (optional)
///   force         (bool)    true = users can't skip the update
class UpdateService {
  static bool _shown = false;

  static Future<void> check(BuildContext context) async {
    if (_shown) return;
    try {
      final doc = await FirebaseFirestore.instance.doc('config/app').get();
      final d = doc.data();
      if (d == null) return;
      final latest = (d['latestBuild'] as num?)?.toInt() ?? 0;
      final url = (d['apkUrl'] ?? '').toString();
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      if (latest <= current || url.isEmpty || !context.mounted) return;
      _shown = true;
      await showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => _UpdateDialog(
          version: (d['latestVersion'] ?? '').toString(),
          notes: (d['notes'] ?? '').toString(),
          url: url,
          force: d['force'] == true,
        ),
      );
    } catch (_) {
      // No internet / no config: just skip the check.
    }
  }
}

class _UpdateDialog extends StatelessWidget {
  final String version, notes, url;
  final bool force;
  const _UpdateDialog({
    required this.version,
    required this.notes,
    required this.url,
    required this.force,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !force,
      child: CupertinoAlertDialog(
        title: Text(
          version.isEmpty ? 'Update available' : 'Update to $version',
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            notes.isEmpty ? 'A new version of CampusBell is ready.' : notes,
          ),
        ),
        actions: [
          if (!force)
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () =>
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
