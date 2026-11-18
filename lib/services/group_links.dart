import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Retains an invitation while the student signs in or completes onboarding.
class GroupLinks {
  static const host = 'campus-bell-seven.vercel.app';
  static final pending = ValueNotifier<String?>(null);
  static final _links = AppLinks();

  static String inviteUrl(String id) => 'https://$host/join/$id';

  static String? groupId(Uri uri) {
    final parts = uri.pathSegments;
    String? id;
    if (uri.scheme == 'campusbell' && uri.host == 'join' && parts.length == 1) {
      id = parts.single;
    } else if (uri.scheme == 'https' &&
        uri.host == host &&
        parts.length == 2 &&
        parts.first == 'join') {
      id = parts.last;
    }
    return id != null && RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(id)
        ? id
        : null;
  }

  static void init() {
    _links.uriLinkStream.listen(
      (uri) {
        final id = groupId(uri);
        if (id != null) pending.value = id;
      },
      onError: (Object error) {
        debugPrint('Could not read group invitation: $error');
      },
    );
  }
}
