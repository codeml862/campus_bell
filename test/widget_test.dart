import 'package:alaram_bell/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Roles.canCall', () {
    test('HOD can call everyone below them', () {
      for (final r in Roles.all.where(
        (r) => r != Roles.hod && r != Roles.admin,
      )) {
        expect(Roles.canCall(Roles.hod, r), isTrue, reason: r);
      }
      expect(Roles.canCall(Roles.hod, Roles.admin), isFalse);
    });

    test('Professor cannot call HOD or Administrator', () {
      expect(Roles.canCall(Roles.professor, Roles.hod), isFalse);
      expect(Roles.canCall(Roles.professor, Roles.admin), isFalse);
      expect(Roles.canCall(Roles.professor, Roles.associateProfessor), isTrue);
      expect(Roles.canCall(Roles.professor, Roles.labAssistant), isTrue);
    });

    test('Order: Associate above Assistant Professor above Lab Assistant', () {
      expect(
        Roles.canCall(Roles.associateProfessor, Roles.assistantProfessor),
        isTrue,
      );
      expect(
        Roles.canCall(Roles.assistantProfessor, Roles.associateProfessor),
        isFalse,
      );
      expect(
        Roles.canCall(Roles.assistantProfessor, Roles.labAssistant),
        isTrue,
      );
      expect(Roles.canRequest(Roles.labAssistant, Roles.professor), isTrue);
    });

    test('Old "Assistant" accounts rank as Lab Assistant', () {
      expect(Roles.normal('Assistant'), Roles.labAssistant);
      expect(Roles.canCall(Roles.assistantProfessor, 'Assistant'), isTrue);
      expect(Roles.canCall('Assistant', Roles.student), isTrue);
    });

    test('Students cannot send bells', () {
      expect(Roles.canCallAnyone(Roles.student), isFalse);
      for (final r in Roles.all) {
        expect(Roles.canCall(Roles.student, r), isFalse, reason: r);
      }
    });
  });

  test('displayName / shortName keep and expand titles', () {
    expect(displayName('Dr. Vipin Kumar'), 'Dr. Vipin Kumar');
    expect(displayName('prof vipin kumar'), 'Professor vipin kumar');
    expect(shortName('Dr. Vipin Kumar'), 'Dr. Vipin');
    expect(shortName('Rajaram Kumar'), 'Rajaram');
  });
}
