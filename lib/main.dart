import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'firebase_options.dart';
import 'models/models.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/main_shell.dart';
import 'screens/onboarding/role_screen.dart';
import 'screens/incoming/ringing_screen.dart';
import 'screens/request_details/request_details_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'services/notifications.dart';
import 'services/services.dart';
import 'services/update_service.dart';
import 'widgets/common.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Runs in a background isolate when a push arrives and the app is closed.
@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage m) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.init(foreground: false);
  await NotificationService.handleMessage(m);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind a fully transparent status/navigation bar (no grey strip).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    ),
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_bgHandler);
  String? ringingId;
  onBellTapped = (id) async {
    final uid = auth.currentUser?.uid;
    if (uid == null || ringingId == id) return;
    ringingId = id;
    // Ring screen only for a bell I received and haven't answered yet;
    // otherwise (e.g. the sender tapping "accepted") show the details.
    var ring = true;
    try {
      final d = (await bellCol.doc(id).get()).data() ?? {};
      final forMe =
          d['recipientUid'] == uid ||
          ((d['recipientUids'] as List?)?.contains(uid) ?? false);
      ring =
          forMe &&
          d['kind'] != 'request' &&
          !['accepted', 'declined'].contains(d['status']);
    } catch (_) {}
    await navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ring
            ? RingingScreen(requestId: id)
            : RequestDetailsScreen(requestId: id),
      ),
    );
    ringingId = null;
  };
  runApp(const CampusBellApp());
  await NotificationService.init();
}

class CampusBellApp extends StatelessWidget {
  const CampusBellApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CampusBell',
    navigatorKey: navigatorKey,
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    // Phones set to very large / very small font sizes would push text out
    // of cards (overlap). Follow the phone's setting, but within limits.
    builder: (context, child) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(
          textScaler: mq.textScaler.clamp(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.15,
          ),
        ),
        child: child!,
      );
    },
    home: const _StartupGate(),
  );
}

/// Shows the loading page for at least 2.5 s on app open, then the app.
class _StartupGate extends StatefulWidget {
  const _StartupGate();
  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 300),
    child: _ready ? const AuthGate() : const SplashScreen(),
  );
}

/// Firebase keeps the login session on the device, so users stay signed in
/// across app restarts. This picks the right screen for the current state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (_, a) {
        if (a.connectionState == ConnectionState.waiting)
          return const SplashScreen();
        final user = a.data;
        if (user == null) return const AuthScreen();
        return StreamBuilder(
          stream: usersCol.doc(user.uid).snapshots(),
          builder: (_, s) {
            if (s.hasError) {
              return AppPage(
                back: false,
                child: Center(
                  child: Text('Could not load profile: ${s.error}'),
                ),
              );
            }
            if (!s.hasData) return const SplashScreen();
            // Signed up but profile not finished yet -> onboarding.
            if (!s.data!.exists) return const RoleScreen();
            final me = AppUser.fromDoc(s.data!);
            if (!me.isActive) return const _Disabled();
            return _Registered(me: me);
          },
        );
      },
    );
  }
}

/// Registers this device for pushes once per login, then shows the app.
class _Registered extends StatefulWidget {
  final AppUser me;
  const _Registered({required this.me});
  @override
  State<_Registered> createState() => _RegisteredState();
}

class _RegisteredState extends State<_Registered> {
  @override
  void initState() {
    super.initState();
    TokenService.register(widget.me.uid);
    // Let bells ring full screen over the lock screen (Android 14+).
    NotificationService.requestFullScreen();
    // Ask to update if a newer APK is published (Firestore config/app).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => UpdateService.check(context),
    );
  }

  @override
  Widget build(BuildContext context) => MainShell(me: widget.me);
}

class _Disabled extends StatelessWidget {
  const _Disabled();
  @override
  Widget build(BuildContext context) => AppPage(
    back: false,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 64, color: AppColors.danger),
            const SizedBox(height: 16),
            const Text(
              'Account disabled',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please contact your Administrator.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            GradientButton(label: 'Sign out', onPressed: AuthService.logout),
          ],
        ),
      ),
    ),
  );
}
