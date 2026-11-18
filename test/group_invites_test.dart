import 'package:alaram_bell/models/models.dart';
import 'package:alaram_bell/services/group_links.dart';
import 'package:alaram_bell/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser person(
  String uid,
  String role, {
  String dept = 'CSE',
  String status = 'active',
}) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.com',
  department: dept,
  role: role,
  status: status,
);

void main() {
  test('student directory follows their current department', () {
    final itStudent = person('student', Roles.student, dept: 'IT');
    final movedStudent = person('student', Roles.student, dept: 'MBA');
    for (final role in Roles.all) {
      expect(
        itStudent.canSeeDirectoryUser(person('it', role, dept: 'IT')),
        isTrue,
      );
      expect(
        itStudent.canSeeDirectoryUser(person('cse', role, dept: 'CSE')),
        isFalse,
      );
      expect(
        movedStudent.canSeeDirectoryUser(person('it', role, dept: 'IT')),
        isFalse,
      );
      expect(
        movedStudent.canSeeDirectoryUser(person('mba', role, dept: 'MBA')),
        isTrue,
      );
    }
    expect(
      person(
        'student',
        Roles.student,
        dept: '',
      ).canSeeDirectoryUser(person('unknown', Roles.student, dept: '')),
      isFalse,
    );
    expect(
      person(
        'hod',
        Roles.hod,
        dept: 'IT',
      ).canSeeDirectoryUser(person('cse', Roles.student)),
      isTrue,
    );
  });

  test('HODs see directory emails while students cannot see staff emails', () {
    final student = person('student', Roles.student);
    final hod = person('hod', Roles.hod);
    for (final role in [Roles.hod, ...Roles.faculty, Roles.labAssistant]) {
      final staff = person('staff-$role', role);
      expect(student.canViewEmailOf(staff), isFalse, reason: role);
      expect(hod.canViewEmailOf(staff), isTrue, reason: role);
      expect(person('admin', Roles.admin).canViewEmailOf(staff), isTrue);
    }
    expect(hod.canViewEmailOf(student), isTrue);
    expect(student.canViewEmailOf(student), isTrue);
    expect(
      person('hod', Roles.hod, status: 'disabled').canViewEmailOf(student),
      isFalse,
    );
  });

  const group = Group(
    id: 'class1',
    name: 'Class',
    department: 'CSE',
    ownerUid: 'teacher',
    memberUids: [],
  );

  test(
    'teachers create groups and manage only their own department groups',
    () {
      for (final role in Roles.faculty) {
        final teacher = person('teacher', role);
        expect(GroupService.canManage(teacher, null), isTrue);
        expect(GroupService.canManage(teacher, group), isTrue);
        expect(GroupService.canManage(person('other', role), group), isFalse);
        expect(
          GroupService.canManage(person('teacher', role, dept: 'MBA'), group),
          isFalse,
        );
      }
      expect(GroupService.canManage(person('s', Roles.student), null), isFalse);
      expect(
        GroupService.canManage(person('l', Roles.labAssistant), null),
        isFalse,
      );
      expect(
        GroupService.canManage(
          person('teacher', Roles.professor, status: 'disabled'),
          group,
        ),
        isFalse,
      );
      expect(GroupService.canManage(person('hod', Roles.hod), group), isTrue);
      expect(
        GroupService.canManage(person('hod', Roles.hod, dept: 'MBA'), group),
        isFalse,
      );
      expect(
        GroupService.canManage(
          person('admin', Roles.admin, dept: 'MBA'),
          group,
        ),
        isTrue,
      );
    },
  );

  test('shared and native invitation links resolve the same group', () {
    expect(
      GroupLinks.groupId(Uri.parse(GroupLinks.inviteUrl('class1'))),
      'class1',
    );
    expect(GroupLinks.groupId(Uri.parse('campusbell://join/class1')), 'class1');
    for (final invalid in [
      'https://example.com/join/class1',
      'https://${GroupLinks.host}/users/class1',
      'http://${GroupLinks.host}/join/class1',
      'campusbell://join/',
      'campusbell://join/class1/extra',
      'campusbell://join/a%2Fb',
    ]) {
      expect(GroupLinks.groupId(Uri.parse(invalid)), isNull, reason: invalid);
    }
  });

  test('delegated group admins manage members without changing app roles', () {
    const delegated = Group(
      id: 'class1',
      name: 'Class',
      department: 'CSE',
      ownerUid: 'teacher',
      memberUids: ['studentAdmin', 'facultyAdmin'],
      adminUids: ['studentAdmin', 'facultyAdmin'],
    );
    final student = person('studentAdmin', Roles.student);
    expect(GroupService.canManage(student, delegated), isTrue);
    expect(GroupService.canManage(student, null), isFalse);
    expect(GroupService.canRing(student, delegated), isFalse);
    expect(
      GroupService.canRing(person('facultyAdmin', Roles.professor), delegated),
      isTrue,
    );
    expect(
      GroupService.canManage(person('other', Roles.student), delegated),
      isFalse,
    );
    expect(
      GroupService.canManage(
        person('studentAdmin', Roles.student, dept: 'MBA'),
        delegated,
      ),
      isFalse,
    );
    expect(
      GroupService.canManage(
        person('studentAdmin', Roles.student, status: 'disabled'),
        delegated,
      ),
      isFalse,
    );
  });
}
