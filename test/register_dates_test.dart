import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:crownlog_flutter/models/user_models.dart';
import 'package:crownlog_flutter/screens/register/register_patient_form_screen.dart';
import 'package:crownlog_flutter/models/register_patient_models.dart';
import 'package:crownlog_flutter/utils/register_age.dart';
import 'package:crownlog_flutter/utils/register_import.dart';

void main() {
  testWidgets('form accepts day-first dates without live age or DOB filling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterPatientFormScreen(
          profile: UserProfile(
            uid: 'test',
            name: 'Tester',
            email: 'test@example.invalid',
            role: UserRole.admin,
          ),
        ),
      ),
    );
    final dobField = find.widgetWithText(TextFormField, '10. Date of birth');
    final ageField = find.widgetWithText(TextFormField, 'Age');
    await tester.enterText(dobField, '07/02/2000');
    await tester.pump();
    expect(tester.widget<TextFormField>(ageField).controller!.text, '');
    await tester.enterText(dobField, '');
    await tester.enterText(ageField, '30');
    await tester.pump();
    expect(tester.widget<TextFormField>(dobField).controller!.text, '');
    final visitField = find.widgetWithText(TextFormField, 'Entry / visit date');
    await tester.ensureVisible(visitField);
    await tester.enterText(visitField, '7/2/2026');
    await tester.pump();
    expect(
      tester.widget<TextFormField>(visitField).validator!('7/2/2026'),
      isNull,
    );
    expect(
      tester.widget<TextFormField>(visitField).validator!('31/2/2026'),
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  group('register date input and display', () {
    for (final input in ['07/02/2026', '7/2/2026', '2026-02-07', '7/2/26']) {
      test('accepts $input', () {
        final date = parseRegisterDate(input);
        expect(date, DateTime(2026, 2, 7));
        expect(formatRegisterDate(date!), '07/02/2026');
      });
    }
    for (final input in [
      '31/2/2026',
      '2026-02-31',
      '29/2/2025',
      '0/2/2026',
      '1/13/2026',
    ]) {
      test(
        'rejects impossible $input',
        () => expect(parseRegisterDate(input), isNull),
      );
    }
    test('normalizes readable DOB but preserves unclear original text', () {
      expect(formatDateOfBirth('1996-08-07'), '07/08/1996');
      expect(
        formatDateOfBirth('7/8/96', reference: DateTime(2026)),
        '07/08/1996',
      );
      expect(formatDateOfBirth('?/4/2023'), '?/4/2023');
    });
  });

  group('DOB resolved on save', () {
    ResolvedDateOfBirth resolve(int n, AgeUnit unit, DateTime date) =>
        resolveDateOfBirthOnSubmit(
          dateOfBirth: '',
          age: CalculatedAge(n, unit),
          reference: date,
        );
    test('subtracts years from visit date', () {
      final dob = resolve(30, AgeUnit.years, DateTime(2026, 2, 7));
      expect(dob.value, '07/02/1996');
      expect(dob.estimated, isTrue);
    });
    test('subtracts months across years', () {
      expect(
        resolve(3, AgeUnit.months, DateTime(2026, 2, 7)).value,
        '07/11/2025',
      );
    });
    test('subtracts days across years', () {
      expect(
        resolve(10, AgeUnit.days, DateTime(2026, 1, 5)).value,
        '26/12/2025',
      );
    });
    test('clamps month-end and leap day', () {
      expect(
        resolve(1, AgeUnit.months, DateTime(2026, 3, 31)).value,
        '28/02/2026',
      );
      expect(
        resolve(1, AgeUnit.months, DateTime(2024, 3, 31)).value,
        '29/02/2024',
      );
      expect(
        resolve(1, AgeUnit.years, DateTime(2024, 2, 29)).value,
        '28/02/2023',
      );
    });
    test('zero age is valid', () {
      expect(
        resolve(0, AgeUnit.days, DateTime(2026, 2, 7)).value,
        '07/02/2026',
      );
    });
    test('missing or negative age cannot generate a DOB', () {
      expect(
        resolveDateOfBirthOnSubmit(
          dateOfBirth: '',
          age: null,
          reference: DateTime(2026),
        ).value,
        '',
      );
      expect(resolve(-1, AgeUnit.years, DateTime(2026)).estimated, isFalse);
    });
    test('never replaces a real or unclear supplied DOB', () {
      for (final input in ['01/01/1990', '?/1/1990']) {
        final dob = resolveDateOfBirthOnSubmit(
          dateOfBirth: input,
          age: const CalculatedAge(12, AgeUnit.years),
          reference: DateTime(2026),
        );
        expect(dob.value, input);
        expect(dob.estimated, isFalse);
      }
    });
    test('existing estimated flag survives an unchanged edit', () {
      final dob = resolveDateOfBirthOnSubmit(
        dateOfBirth: '07/02/1996',
        age: const CalculatedAge(30, AgeUnit.years),
        reference: DateTime(2026, 2, 7),
        alreadyEstimated: true,
      );
      expect(dob.estimated, isTrue);
    });
  });

  group('import and storage compatibility', () {
    test('CSV estimates age-only DOB with visit date; typed age wins', () {
      final p = parseRegisterCsv(
        'cardNumber,name,visitDate,age,ageUnit\nB1,Sample,7/2/2026,3,months\n',
      ).single.patient!;
      expect(p.dateOfBirth, '07/11/2025');
      expect(p.dobEstimated, isTrue);
      expect(p.age, 3);
      expect(p.ageUnit, AgeUnit.months);
    });
    test('JSON without visit date uses supplied today and supports days', () {
      final p = parseRegisterJson(
        '[{"cardNumber":"B2","name":"Sample","age":7,"ageUnit":"days"}]',
        now: DateTime(2026, 2, 7),
      ).single.patient!;
      expect(p.dateOfBirth, '31/01/2026');
      expect(p.dobEstimated, isTrue);
    });
    test('real DOB keeps priority but typed age is retained', () {
      final p = parseRegisterJson(
        '[{"cardNumber":"B3","name":"Sample","visitDate":"07/02/2026","dateOfBirth":"2000-01-01","age":30}]',
      ).single.patient!;
      expect(p.dateOfBirth, '01/01/2000');
      expect(p.age, 30);
      expect(p.dobEstimated, isFalse);
    });
    test('DOB-only still calculates age and blank data stays blank', () {
      final rows = parseRegisterCsv(
        'cardNumber,name,visitDate,dateOfBirth\nB4,Sample,2026-02-07,7/2/2000\nB5,Sample,,\n',
        now: DateTime(2026, 2, 7),
      );
      expect(rows.first.patient!.age, 26);
      expect(rows.first.patient!.dobEstimated, isFalse);
      expect(rows.last.patient!.dateOfBirth, '');
      expect(rows.last.patient!.age, isNull);
    });
    test(
      'CSV export is day-first and preserves estimated flag on reimport',
      () {
        final p = parseRegisterCsv(
          'cardNumber,name,visitDate,age\nB6,Sample,2026-02-07,30\n',
        ).single.patient!;
        final csv = registerPatientsToCsv([p]);
        expect(csv, contains('07/02/2026'));
        final copy = parseRegisterCsv(csv).single.patient!;
        expect(copy.dateOfBirth, p.dateOfBirth);
        expect(copy.dobEstimated, isTrue);
        expect(copy.visitDate, p.visitDate);
      },
    );
    test('Firestore retains Timestamp visit date and reads legacy ISO', () {
      final date = DateTime(2026, 2, 7);
      final p = RegisterPatient(
        id: 'id',
        cardNumber: 'B7',
        name: 'Sample',
        dateOfBirth: '07/02/1996',
        dobEstimated: true,
        visitDate: date,
        createdAt: date,
      );
      final json = p.toJson();
      expect(json['visitDate'], isA<Timestamp>());
      expect((json['visitDate'] as Timestamp).toDate(), date);
      final loaded = RegisterPatient.fromJson(json, 'id');
      expect(loaded.dobEstimated, isTrue);
      expect(loaded.copyWith(name: 'Changed').dobEstimated, isTrue);
      expect(loaded.dateOfBirth, '07/02/1996');
      json['visitDate'] = '2026-02-07';
      json.remove('dobEstimated');
      final legacy = RegisterPatient.fromJson(json, 'id');
      expect(legacy.visitDate, date);
      expect(legacy.dobEstimated, isFalse);
    });
    test('negative age is rejected rather than creating a future DOB', () {
      expect(
        parseRegisterCsv('cardNumber,name,age\nB8,Sample,-1\n').single.isValid,
        isFalse,
      );
    });
  });
}
