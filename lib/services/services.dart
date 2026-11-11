import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../models/models.dart';

final auth = FirebaseAuth.instance;
final db = FirebaseFirestore.instance;
final usersCol = db.collection('users');
final bellCol = db.collection('bell_requests');

final usernamesCol = db.collection('usernames');
final groupsCol = db.collection('groups');
final announcementsCol = db.collection('announcements');

class AuthService {
  /// Name/username typed on Create Account, used by profile setup.
  static String? pendingName, pendingUsername;

  static String cleanUsername(String u) =>
      u.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');

  /// Makes a free username from the name: "Rajaram Kumar" -> "rajaramkumar",
  /// or "rajaramkumar7" etc. if that one is taken.
  static Future<String> _freeUsername(String first, String last) async {
    var base = '$first$last'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (base.length < 3) base = '${base}user';
    if (base.length > 16) base = base.substring(0, 16);
    final rnd = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < 6; i++) {
      final u = i == 0 ? base : '$base${(rnd ~/ (i * 7 + 1)) % 1000}';
      if (!(await usernamesCol.doc(u).get()).exists) return u;
    }
    return '$base${rnd % 100000}';
  }

  /// Creates the account; the username is made from first + last name.
  static Future<void> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final u = await _freeUsername(firstName.trim(), lastName.trim());
    pendingName = '${firstName.trim()} ${lastName.trim()}'.trim();
    pendingUsername = u;
    final cred = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    try {
      await usernamesCol.doc(u).set({
        'uid': cred.user!.uid,
        'email': email.toLowerCase(),
      });
    } catch (_) {
      // Someone took it a moment ago; continue without a username.
      pendingUsername = null;
    }
  }

  /// [id] is an email or a username (with or without @).
  static Future<void> login(String id, String password) async {
    var email = id.trim();
    if (!email.contains('@') || email.startsWith('@')) {
      final d = await usernamesCol.doc(cleanUsername(email)).get();
      if (!d.exists) throw 'No account with username $id.';
      email = d.data()!['email'];
    }
    await auth.signInWithEmailAndPassword(email: email, password: password);
  }

  static bool _googleReady = false;

  /// Google sign-in inside the app (native account picker, no browser).
  /// New users continue to role + profile setup.
  static Future<void> google() async {
    final g = GoogleSignIn.instance;
    if (!_googleReady) {
      await g.initialize();
      _googleReady = true;
    }
    final account = await g.authenticate();
    final idToken = account.authentication.idToken;
    final cred = await auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    pendingName = cred.user?.displayName ?? account.displayName;
  }

  /// True if this account signs in with email + password (not only Google).
  static bool get hasPassword =>
      auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  /// Changes the password inside the app (checks the current one first).
  static Future<void> changePassword(String current, String next) async {
    final u = auth.currentUser!;
    await u.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: u.email!, password: current),
    );
    await u.updatePassword(next);
  }

  static Future<void> resetPassword(String email) =>
      auth.sendPasswordResetEmail(email: email);

  /// Creates the profile after sign-up (role + profile screens).
  static Future<void> createProfile({
    required String name,
    required String department,
    required String role,
    String? staffId,
    String? designation,
  }) {
    final u = auth.currentUser!;
    return usersCol.doc(u.uid).set({
      'name': name,
      'email': u.email,
      'department': department,
      'role': role,
      if (role == Roles.hod && designation != null) 'designation': designation,
      'staffId': staffId,
      'username': pendingUsername,
      'status': 'active',
      'fcmTokens': <String>[],
      'prefs': {'sound': true},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> logout() async {
    await TokenService.removeCurrent();
    // Forget the Google account so the picker shows again next time.
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await auth.signOut();
  }
}

class TokenService {
  static String? _token;

  static Future<void> register(String uid) async {
    final fm = FirebaseMessaging.instance;
    await fm.requestPermission(alert: true, sound: true, badge: true);
    // ignore: deprecated_member_use
    _token = await fm.getToken();
    if (_token != null) {
      await usersCol.doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([_token]),
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
    // ignore: deprecated_member_use
    fm.onTokenRefresh.listen((t) {
      _token = t;
      usersCol.doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([t]),
      });
    });
  }

  static Future<void> removeCurrent() async {
    final uid = auth.currentUser?.uid;
    if (uid == null || _token == null) return;
    await usersCol.doc(uid).update({
      'fcmTokens': FieldValue.arrayRemove([_token]),
    });
  }
}

class BellService {
  /// Saves a new request and returns its id. Call [notify] next.
  /// Saves a new bell (top → bottom ring) or, with [request], a quiet
  /// "request to meet" (bottom → top). Returns its id; call [notify] next.
  static Future<String> create({
    required AppUser me,
    required AppUser to,
    required String message,
    required String priority,
    required bool persistent,
    bool request = false,
  }) async {
    if (request
        ? !Roles.canRequest(me.role, to.role)
        : !Roles.canCall(me.role, to.role)) {
      throw request
          ? 'You can only send a request to someone above you.'
          : 'You can\'t ring a ${to.role}. Send a request instead.';
    }
    // No waiting/blocking: every press sends a new bell straight away.
    final ref = await bellCol.add({
      'kind': request ? BellKind.request : BellKind.bell,
      'senderUid': me.uid,
      'senderName': me.name,
      'senderRole': me.role,
      'recipientUid': to.uid,
      'recipientName': to.name,
      'recipientRole': to.role,
      'message': message,
      'priority': request ? Priority.normal : priority,
      'persistent': request ? false : persistent,
      'status': BellStatus.pending,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Rings every member of [group] at once. The first to accept goes; the
  /// others are told who accepted.
  static Future<String> createGroup({
    required AppUser me,
    required Group group,
    required String message,
    required String priority,
    required bool persistent,
  }) async {
    final members = group.memberUids.where((u) => u != me.uid).toList();
    if (members.isEmpty) throw 'This group has no members yet.';
    final ref = await bellCol.add({
      'kind': BellKind.bell,
      'senderUid': me.uid,
      'senderName': me.name,
      'senderRole': me.role,
      'groupId': group.id,
      'recipientUid': '',
      'recipientUids': members,
      'recipientName': group.name,
      'recipientRole': 'Group',
      'message': message,
      'priority': priority,
      'persistent': persistent,
      'status': BellStatus.pending,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Asks the push server to deliver the bell to the recipient's phone.
  static Future<void> notify(String requestId) async {
    if (pushServerUrl.isEmpty) {
      throw 'Push server is not set up yet (lib/core/config.dart).';
    }
    final idToken = await auth.currentUser!.getIdToken();
    final r = await http
        .post(
          Uri.parse('$pushServerUrl/notify'),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'requestId': requestId}),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) throw body['error'] ?? 'Push server error';
    if (body['error'] != null) throw body['error'];
  }

  /// Recipient answers a bell: accept, or decline with a reason.
  /// Then asks the push server to tell the sender.
  static Future<void> respond(
    String requestId, {
    required bool accept,
    String? reason,
  }) async {
    final me = auth.currentUser!;
    final snap = await bellCol.doc(requestId).get();
    final isGroup = (snap.data()?['groupId']) != null;
    if (isGroup && !accept) return; // group: "can't come" just stops my ring
    String? myName;
    if (isGroup) {
      myName = (await usersCol.doc(me.uid).get()).data()?['name'];
    }
    // Firestore rules only allow this while nobody has answered yet, so for
    // a group the first accept wins and later ones fail.
    await bellCol.doc(requestId).update({
      'status': accept ? BellStatus.accepted : BellStatus.declined,
      if (isGroup) 'claimedBy': me.uid,
      if (isGroup) 'claimedByName': myName ?? me.displayName ?? 'Someone',
      'reason': accept ? null : (reason ?? '').trim(),
      'respondedAt': FieldValue.serverTimestamp(),
    });
    try {
      await notify(requestId);
    } catch (_) {
      // The answer is saved; the sender also sees it live in the app.
    }
  }

  static Future<void> cancel(String requestId) =>
      bellCol.doc(requestId).delete();

  static Stream<BellRequest?> watch(String id) => bellCol
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? BellRequest.fromDoc(d) : null);

  static Stream<List<BellRequest>> sent(String uid) => bellCol
      .where('senderUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(BellRequest.fromDoc).toList());

  static Stream<List<BellRequest>> received(String uid) => bellCol
      .where('recipientUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(BellRequest.fromDoc).toList());

  /// Group bells I'm a member of.
  static Stream<List<BellRequest>> receivedGroup(String uid) => bellCol
      .where('recipientUids', arrayContains: uid)
      .limit(50)
      .snapshots()
      .map(
        (s) => s.docs.map(BellRequest.fromDoc).toList()
          ..sort(
            (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
              a.createdAt ?? DateTime.now(),
            ),
          ),
      );

  static Stream<List<AppUser>> users() => usersCol.snapshots().map(
    (s) =>
        s.docs.map(AppUser.fromDoc).where((u) => u.isActive).toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
  );
}

/// Groups a HOD (own department) or the main administrator can ring at once.
class GroupService {
  /// Groups I own or belong to; the main administrator sees all.
  static Stream<List<Group>> mine(AppUser me) {
    final q = me.isAdmin
        ? groupsCol
        : groupsCol.where('department', isEqualTo: me.department);
    return q.snapshots().map(
      (s) =>
          s.docs
              .map(Group.fromDoc)
              .where(
                (g) =>
                    me.isAdmin ||
                    g.ownerUid == me.uid ||
                    g.memberUids.contains(me.uid),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  static bool canManage(AppUser me, Group? g) =>
      me.isAdmin ||
      (me.role == Roles.hod && (g == null || g.department == me.department));

  static Future<void> save({
    required AppUser me,
    String? id,
    required String name,
    required String department,
    required List<String> memberUids,
  }) {
    final data = {
      'name': name.trim(),
      'department': department,
      'memberUids': memberUids,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    return id == null
        ? groupsCol.add({
            ...data,
            'ownerUid': me.uid,
            'createdAt': FieldValue.serverTimestamp(),
          })
        : groupsCol.doc(id).update(data);
  }

  static Future<void> delete(String id) => groupsCol.doc(id).delete();
}

/// Each department has exactly one HOD.
class HodService {
  /// The current HOD of [department], if any (ignores [exceptUid]).
  static Future<AppUser?> hodOf(String department, {String? exceptUid}) async {
    final s = await usersCol
        .where('department', isEqualTo: department)
        .where('role', isEqualTo: Roles.hod)
        .limit(3)
        .get();
    for (final d in s.docs) {
      final u = AppUser.fromDoc(d);
      if (u.uid != exceptUid && u.isActive) return u;
    }
    return null;
  }

  /// Throws a friendly message if [department] already has a HOD.
  static Future<void> ensureFree(String department, {String? exceptUid}) async {
    final h = await hodOf(department, exceptUid: exceptUid);
    if (h != null) {
      throw '${deptName(department)} already has a HOD (${h.name}). '
          'Each department can have only one HOD.';
    }
  }

  static String deptName(String d) => d.isEmpty ? 'This department' : d;
}

/// Notices from a HOD (own department) or the main administrator
/// (any department, or everyone).
class AnnouncementService {
  static bool canPost(AppUser me) => me.isAdmin || me.role == Roles.hod;

  /// Latest notices for my department plus the ones for everyone.
  static Stream<List<Announcement>> forMe(AppUser me, {int limit = 20}) =>
      announcementsCol
          .where('department', whereIn: [me.department, ''])
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(Announcement.fromDoc).toList());

  /// Notices I sent, newest first.
  static Stream<List<Announcement>> sentBy(String uid) => announcementsCol
      .where('senderUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((s) => s.docs.map(Announcement.fromDoc).toList());

  static Future<void> post({
    required AppUser me,
    required String title,
    required String message,
    required String department,
  }) => announcementsCol.add({
    'title': title.trim(),
    'message': message.trim(),
    'department': department,
    'senderUid': me.uid,
    'senderName': me.name,
    'senderRole': me.role,
    'seenBy': <String>[],
    'createdAt': FieldValue.serverTimestamp(),
  });

  static final _marked = <String>{};

  /// Records that I saw [a] (once per app run).
  static Future<void> markSeen(Announcement a, String uid) async {
    if (a.seenBy.contains(uid) || !_marked.add(a.id)) return;
    try {
      await announcementsCol.doc(a.id).update({
        'seenBy': FieldValue.arrayUnion([uid]),
      });
    } catch (_) {}
  }

  static Future<void> delete(String id) => announcementsCol.doc(id).delete();

  /// How many active people a notice for [department] can reach.
  static Future<int> audience(String department) async {
    final q = department.isEmpty
        ? usersCol
        : usersCol.where('department', isEqualTo: department);
    final r = await q.count().get();
    return r.count ?? 0;
  }
}

/// Weekly timetable, saved on the user's own profile.
class TimetableService {
  static Future<void> save(String uid, List<Period> periods) =>
      usersCol.doc(uid).update({
        'timetable': [for (final p in periods) p.toMap()],
        // The push server uses this to know the local time.
        'prefs.tzOffset': DateTime.now().timeZoneOffset.inMinutes,
      });

  static Future<void> setQuietInClass(String uid, bool on) =>
      usersCol.doc(uid).update({
        'prefs.quietInClass': on,
        'prefs.tzOffset': DateTime.now().timeZoneOffset.inMinutes,
      });
}
