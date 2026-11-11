import 'package:cloud_firestore/cloud_firestore.dart';

/// First name for greetings, keeping a title: "Dr. Vipin Kumar" -> "Dr. Vipin".
/// "Prof Vipin Kumar" -> "Professor Vipin".
String shortName(String name) {
  final parts = displayName(name).split(' ').where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '';
  const titles = {
    'dr',
    'prof',
    'professor',
    'mr',
    'mrs',
    'ms',
    'miss',
    'sri',
    'smt',
    'er',
  };
  final first = parts.first;
  final isTitle = titles.contains(first.replaceAll('.', '').toLowerCase());
  return isTitle && parts.length > 1 ? '$first ${parts.elementAt(1)}' : first;
}

/// Full name for display, with short titles written out:
/// "Prof Vipin Kumar" / "Prof. Vipin Kumar" -> "Professor Vipin Kumar",
/// "dr vipin kumar" -> "Dr. Vipin Kumar".
String displayName(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '';
  const full = {
    'prof': 'Professor',
    'professor': 'Professor',
    'dr': 'Dr.',
    'mr': 'Mr.',
    'mrs': 'Mrs.',
    'ms': 'Ms.',
  };
  final first = parts.first;
  final t = full[first.replaceAll('.', '').toLowerCase()];
  return [t ?? first, ...parts.skip(1)].join(' ');
}

class Roles {
  static const hod = 'HOD';
  static const professor = 'Professor';
  static const associateProfessor = 'Associate Professor';
  static const assistantProfessor = 'Assistant Professor';
  static const labAssistant = 'Lab Assistant';
  static const student = 'Student';
  static const admin = 'Administrator';

  /// Older accounts were saved as "Assistant"; they are Lab Assistants.
  static const legacyAssistant = 'Assistant';

  static const all = [
    hod,
    professor,
    associateProfessor,
    assistantProfessor,
    labAssistant,
    student,
    admin,
  ];

  /// Roles a user may pick for themselves (Administrator is granted by an admin).
  static const selfSelectable = [
    hod,
    professor,
    associateProfessor,
    assistantProfessor,
    labAssistant,
    student,
  ];

  /// What a HOD is by designation.
  static const hodDesignations = [professor, associateProfessor];

  /// Teaching staff (not HOD).
  static const faculty = [professor, associateProfessor, assistantProfessor];

  /// "Assistant" (old) -> "Lab Assistant".
  static String normal(String role) =>
      role == legacyAssistant ? labAssistant : role;

  /// Hierarchy, top to bottom. Must match worker/src/index.js.
  static const order = [
    admin,
    hod,
    professor,
    associateProfessor,
    assistantProfessor,
    labAssistant,
    student,
  ];
  static int rank(String role) {
    final i = order.indexOf(normal(role));
    return i < 0 ? order.length : i;
  }

  /// Ring (loud bell) goes top → bottom only. The main administrator can
  /// ring anyone. Must match worker/src/index.js (CAN_CALL).
  static bool canCall(String from, String to) =>
      from == admin || (rank(from) < rank(to) && from != student);
  static bool canCallAnyone(String role) => role != student;

  /// Bottom → top: a quiet "request to meet" instead of a ring.
  static bool canRequest(String from, String to) =>
      from != admin && rank(from) > rank(to);

  static String describe(String role) => switch (normal(role)) {
    hod => 'Head of department',
    professor => 'Senior teaching staff',
    associateProfessor => 'Teaching staff',
    assistantProfessor => 'Teaching staff',
    labAssistant => 'Lab and office staff',
    student => 'Receives bells, can request to meet',
    _ => '',
  };
}

/// One class/meeting in a person's weekly timetable.
/// [day] is 1 (Monday) … 7 (Sunday); [start]/[end] are "HH:mm".
class Period {
  final int day;
  final String start, end, title, place;
  const Period({
    required this.day,
    required this.start,
    required this.end,
    required this.title,
    this.place = '',
  });

  static int minutes(String hhmm) {
    final p = hhmm.split(':');
    return (int.tryParse(p[0]) ?? 0) * 60 +
        (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
  }

  int get startMin => minutes(start);
  int get endMin => minutes(end);

  Map<String, dynamic> toMap() => {
    'day': day,
    'start': start,
    'end': end,
    'title': title,
    'place': place,
  };

  factory Period.fromMap(Map m) => Period(
    day: (m['day'] as num?)?.toInt() ?? 1,
    start: m['start'] ?? '09:00',
    end: m['end'] ?? '10:00',
    title: m['title'] ?? '',
    place: m['place'] ?? '',
  );
}

class AppUser {
  final String uid, name, email, department, role, status;
  final String? photoUrl, staffId, username;

  /// For a HOD: "Professor" or "Associate Professor".
  final String? designation;
  final bool soundOn;

  /// Bells ring silently while this person is in a timetable class.
  final bool quietInClass;
  final List<Period> timetable;

  const AppUser({
    this.username,
    required this.uid,
    required this.name,
    required this.email,
    required this.department,
    required this.role,
    required this.status,
    this.photoUrl,
    this.staffId,
    this.designation,
    this.soundOn = true,
    this.quietInClass = true,
    this.timetable = const [],
  });

  bool get isActive => status != 'disabled';

  /// The timetable class this person is in right now, if any.
  Period? get currentClass {
    final n = DateTime.now();
    final m = n.hour * 60 + n.minute;
    for (final p in timetable) {
      if (p.day == n.weekday && p.startMin <= m && m < p.endMin) return p;
    }
    return null;
  }

  bool get isAdmin => role == Roles.admin;

  /// Role as shown to people, e.g. "HOD · Professor", "Lab Assistant".
  String get roleLabel {
    final r = Roles.normal(role);
    if (r == Roles.hod && (designation ?? '').isNotEmpty) {
      return 'HOD · $designation';
    }
    return r;
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return AppUser(
      uid: d.id,
      name: m['name'] ?? '',
      email: m['email'] ?? '',
      department: m['department'] ?? '',
      role: m['role'] ?? Roles.student,
      status: m['status'] ?? 'active',
      photoUrl: m['photoUrl'],
      staffId: m['staffId'],
      designation: m['designation'],
      username: m['username'],
      soundOn: (m['prefs'] as Map?)?['sound'] ?? true,
      quietInClass: (m['prefs'] as Map?)?['quietInClass'] ?? true,
      timetable: [
        for (final p in (m['timetable'] as List?) ?? const [])
          if (p is Map) Period.fromMap(p),
      ]..sort((a, b) => a.startMin.compareTo(b.startMin)),
    );
  }
}

/// A notice to a department (or everyone when [department] is empty).
class Announcement {
  final String id, title, message, department, senderUid, senderName;
  final String senderRole;
  final List<String> seenBy;
  final DateTime? createdAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.department,
    required this.senderUid,
    required this.senderName,
    required this.senderRole,
    required this.seenBy,
    this.createdAt,
  });

  bool get forEveryone => department.isEmpty;

  factory Announcement.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    final t = m['createdAt'];
    return Announcement(
      id: d.id,
      title: m['title'] ?? '',
      message: m['message'] ?? '',
      department: m['department'] ?? '',
      senderUid: m['senderUid'] ?? '',
      senderName: m['senderName'] ?? '',
      senderRole: m['senderRole'] ?? '',
      seenBy: List<String>.from(m['seenBy'] ?? const []),
      createdAt: t is Timestamp ? t.toDate() : null,
    );
  }
}

class BellStatus {
  static const pending = 'pending';
  static const delivered = 'delivered';
  static const acknowledged = 'acknowledged';
  static const accepted = 'accepted';
  static const declined = 'declined';
  static const failed = 'failed';
  static const rejected = 'rejected';
  static const open = [pending];
}

class BellKind {
  static const bell = 'bell';
  static const request = 'request';
}

class Priority {
  static const normal = 'normal';
  static const high = 'high';
  static const urgent = 'urgent';
  static const all = [normal, high, urgent];
}

class BellRequest {
  final String id, senderUid, senderName, senderRole;
  final String recipientUid, recipientName, recipientRole, message, status;
  final String priority;
  final bool persistent;
  final String? error;

  /// Why the recipient declined (only for status "declined").
  final String? reason;
  final DateTime? createdAt, deliveredAt, respondedAt;

  /// "bell" (loud ring, top → bottom) or "request" (quiet request to meet,
  /// bottom → top).
  final String kind;

  /// Group bell: rings every member; the first to accept goes.
  final String? groupId;
  final List<String> recipientUids;

  /// Who accepted a group bell first.
  final String? claimedBy, claimedByName;

  const BellRequest({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.senderRole,
    required this.recipientUid,
    required this.recipientName,
    required this.recipientRole,
    required this.message,
    required this.status,
    required this.priority,
    required this.persistent,
    this.error,
    this.reason,
    this.createdAt,
    this.deliveredAt,
    this.respondedAt,
    this.kind = BellKind.bell,
    this.groupId,
    this.recipientUids = const [],
    this.claimedBy,
    this.claimedByName,
  });

  bool get isRequest => kind == BellKind.request;
  bool get isGroup => groupId != null;

  /// True if [uid] is a recipient (single bell or group member).
  bool isFor(String uid) => recipientUid == uid || recipientUids.contains(uid);

  bool get isOpen => BellStatus.open.contains(status);
  bool get isAnswered =>
      status == BellStatus.accepted || status == BellStatus.declined;

  static DateTime? _t(dynamic v) => v is Timestamp ? v.toDate() : null;

  factory BellRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return BellRequest(
      id: d.id,
      senderUid: m['senderUid'] ?? '',
      senderName: m['senderName'] ?? '',
      senderRole: m['senderRole'] ?? '',
      recipientUid: m['recipientUid'] ?? '',
      recipientName: m['recipientName'] ?? '',
      recipientRole: m['recipientRole'] ?? '',
      message: m['message'] ?? '',
      status: m['status'] ?? BellStatus.pending,
      priority: m['priority'] ?? Priority.normal,
      persistent: m['persistent'] ?? true,
      error: m['error'],
      reason: m['reason'],
      createdAt: _t(m['createdAt']),
      deliveredAt: _t(m['deliveredAt']),
      respondedAt: _t(m['respondedAt']),
      kind: m['kind'] ?? BellKind.bell,
      groupId: m['groupId'],
      recipientUids: List<String>.from(m['recipientUids'] ?? const []),
      claimedBy: m['claimedBy'],
      claimedByName: m['claimedByName'],
    );
  }
}

/// A named set of people a HOD (or the main administrator) can ring at
/// once, e.g. "Lab assistants" or "Final-year students".
class Group {
  final String id, name, department, ownerUid;
  final List<String> memberUids;

  const Group({
    required this.id,
    required this.name,
    required this.department,
    required this.ownerUid,
    required this.memberUids,
  });

  factory Group.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Group(
      id: d.id,
      name: m['name'] ?? '',
      department: m['department'] ?? '',
      ownerUid: m['ownerUid'] ?? '',
      memberUids: List<String>.from(m['memberUids'] ?? const []),
    );
  }
}
