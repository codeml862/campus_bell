import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android channel for incoming bells. Rings with the phone's own ringtone
/// on the alarm stream, like a call. (Channel sound can't change after it is
/// created, so this uses a new id instead of the old 'campus_bell_calls'.)
const _ringtone = UriAndroidNotificationSound(
  'content://settings/system/ringtone',
);
const _channel = AndroidNotificationChannel(
  'campus_bell_ring',
  'Bell calls',
  description: 'Incoming calling bells (rings like a phone call)',
  importance: Importance.max,
  playSound: true,
  sound: _ringtone,
  enableVibration: true,
  audioAttributesUsage: AudioAttributesUsage.alarm,
);

final _plugin = FlutterLocalNotificationsPlugin();

/// Set by the app; opens the ringing screen for a bell.
void Function(String requestId)? onBellTapped;

/// Set by the app; a group bell was accepted by someone else ([name]).
void Function(String requestId, String name)? onBellClaimed;

/// Stable notification id for a bell (same in every isolate).
int bellNotificationId(String requestId) {
  var h = 7;
  for (final c in requestId.codeUnits) {
    h = (h * 31 + c) & 0x3fffffff;
  }
  return h;
}

class NotificationService {
  static Future<void> init({bool foreground = true}) async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onResponse,
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.deleteNotificationChannel('campus_bell_calls');
    await android?.createNotificationChannel(_channel);

    if (!foreground) return;
    await android?.requestNotificationsPermission();

    // iOS shows the APNs alert itself while the app is open.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          sound: true,
          badge: true,
        );

    FirebaseMessaging.onMessage.listen((m) async {
      await handleMessage(m);
      // App is open: show the ringing screen straight away.
      final id = m.data['requestId'];
      if (m.data['type'] == 'bell' && id != null) onBellTapped?.call(id);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      final id = m.data['requestId'];
      if (id != null) onBellTapped?.call(id);
    });
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    final launch = await _plugin.getNotificationAppLaunchDetails();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = initial?.data['requestId'];
      if (id != null) onBellTapped?.call(id);
      if (launch?.didNotificationLaunchApp ?? false) {
        final r = launch!.notificationResponse;
        if (r != null) _onResponse(r);
      }
    });
  }

  /// Android 14+: lets the bell open full screen over the lock screen.
  /// Opens the system setting only if it isn't allowed yet.
  static Future<void> requestFullScreen() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestFullScreenIntentPermission();
  }

  /// Stops the ringing for a bell.
  static Future<void> stop(String requestId) =>
      _plugin.cancel(bellNotificationId(requestId));

  static void _onResponse(NotificationResponse r) {
    if (r.actionId == 'stop') return; // Stop button: just silence it.
    final id = r.payload;
    if (id == null || id.isEmpty) return;
    onBellTapped?.call(id);
  }

  /// Shows the ringing bell notification for a data message (Android).
  static Future<void> handleMessage(RemoteMessage m) async {
    final d = m.data;
    // Sender side: "X accepted / declined your bell" (normal notification).
    if (d['type'] == 'answer') {
      if (m.notification != null &&
          defaultTargetPlatform == TargetPlatform.iOS) {
        return;
      }
      await _plugin.show(
        bellNotificationId('${d['requestId']}-answer'),
        d['title'] ?? 'Bell answered',
        d['body'] ?? '',
        payload: d['requestId'],
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'campus_bell_answers',
            'Bell answers',
            channelDescription: 'Accepted / declined answers to your bells',
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFF1E3A8A),
          ),
        ),
      );
      return;
    }
    // Group bell: someone else accepted → stop my ringing, say who's going.
    if (d['type'] == 'claimed') {
      await stop(d['requestId'] ?? '');
      onBellClaimed?.call(d['requestId'] ?? '', d['name'] ?? 'Someone');
      await _plugin.show(
        bellNotificationId('${d['requestId']}-claimed'),
        d['title'] ?? 'Someone accepted',
        d['body'] ?? '',
        payload: d['requestId'],
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'campus_bell_answers',
            'Bell answers',
            channelDescription: 'Accepted / declined answers to your bells',
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFF1E3A8A),
          ),
        ),
      );
      return;
    }
    // Student → teacher "request to meet": quiet notification (no ringing).
    if (d['type'] == 'request') {
      if (m.notification != null &&
          defaultTargetPlatform == TargetPlatform.iOS) {
        return;
      }
      await _plugin.show(
        bellNotificationId(d['requestId'] ?? ''),
        '${d['senderName']} (${d['senderRole']}) wants to meet you',
        (d['message'] ?? '').toString().isEmpty
            ? 'Tap to accept or decline'
            : d['message'],
        payload: d['requestId'],
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'campus_bell_requests',
            'Meeting requests',
            channelDescription: 'Requests to meet from students and staff',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
            color: Color(0xFF1E3A8A),
            styleInformation: BigTextStyleInformation(''),
          ),
        ),
      );
      return;
    }
    if (d['type'] != 'bell') return;
    // iOS already displays the APNs alert; avoid a duplicate.
    if (m.notification != null && defaultTargetPlatform == TargetPlatform.iOS) {
      return;
    }

    final sound = d['sound'] != 'off';
    final keepRinging = sound && d['persistent'] != 'false';
    final prefix = switch (d['priority']) {
      'urgent' => '🔴 URGENT · ',
      'high' => '🟠 ',
      _ => '',
    };
    final id = d['requestId'] ?? '';
    await _plugin.show(
      bellNotificationId(id),
      '$prefix${d['senderName']} (${d['senderRole']}) is calling you',
      (d['message'] ?? '').toString().isEmpty ? 'Please come' : d['message'],
      payload: id,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.call,
          // Opens the ringing screen over the lock screen, like a call.
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: true,
          playSound: sound,
          sound: _ringtone,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1000, 800, 1000, 800]),
          // FLAG_INSISTENT: keep ringing until stopped (max 60 s).
          additionalFlags: keepRinging ? Int32List.fromList(<int>[4]) : null,
          timeoutAfter: 60000,
          visibility: NotificationVisibility.public,
          actions: const [
            AndroidNotificationAction(
              'stop',
              'Stop',
              cancelNotification: true,
              showsUserInterface: false,
            ),
          ],
          styleInformation: const BigTextStyleInformation(''),
          color: const Color(0xFF1E3A8A),
        ),
      ),
    );
  }
}
