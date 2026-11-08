import 'package:flutter_test/flutter_test.dart';
import 'package:crownlog_flutter/models/register_patient_models.dart';
import 'package:crownlog_flutter/utils/register_age.dart';
import 'package:crownlog_flutter/utils/register_import.dart';

void main() {
  CalculatedAge? age(DateTime dob, DateTime ref) => calculateAge(dob, ref);

  group('calculateAge units', () {
    test('0-28 days are recorded in days', () {
      expect(
        age(DateTime(2026, 3, 1), DateTime(2026, 3, 1)),
        const CalculatedAge(0, AgeUnit.days),
      );
      expect(
        age(DateTime(2026, 3, 1), DateTime(2026, 3, 2)),
        const CalculatedAge(1, AgeUnit.days),
      );
      expect(
        age(DateTime(2026, 3, 1), DateTime(2026, 3, 29)),
        const CalculatedAge(28, AgeUnit.days),
      );
    });

    test('29 days up to the first birthday are months (at least 1)', () {
      // 29 days but not yet a calendar month.
      expect(
        age(DateTime(2026, 1, 1), DateTime(2026, 1, 30)),
        const CalculatedAge(1, AgeUnit.months),
      );
      expect(
        age(DateTime(2026, 1, 15), DateTime(2026, 3, 14)),
        const CalculatedAge(1, AgeUnit.months),
      );
      expect(
        age(DateTime(2026, 1, 15), DateTime(2026, 3, 15)),
        const CalculatedAge(2, AgeUnit.months),
      );
      expect(
        age(DateTime(2025, 3, 10), DateTime(2026, 3, 9)),
        const CalculatedAge(11, AgeUnit.months),
      );
    });

    test('from the first birthday on, whole years', () {
      expect(
        age(DateTime(2025, 3, 10), DateTime(2026, 3, 10)),
        const CalculatedAge(1, AgeUnit.years),
      );
      expect(
        age(DateTime(1996, 8, 7), DateTime(2026, 8, 1)),
        const CalculatedAge(29, AgeUnit.years),
      );
    });
  });

  group('birthday boundaries', () {
    test('day before, on and after a birthday', () {
      final dob = DateTime(1990, 6, 15);
      expect(age(dob, DateTime(2026, 6, 14))!.value, 35);
      expect(age(dob, DateTime(2026, 6, 15))!.value, 36);
      expect(age(dob, DateTime(2026, 6, 16))!.value, 36);
    });

    test('times of day do not matter', () {
      expect(
        age(DateTime(1990, 6, 15, 23, 59), DateTime(2026, 6, 15, 0, 1))!.value,
        36,
      );
    });

    test('month-end births complete a month on the last day', () {
      expect(
        age(DateTime(2026, 1, 31), DateTime(2026, 2, 28)),
        const CalculatedAge(28, AgeUnit.days),
      );
      expect(
        age(DateTime(2025, 12, 31), DateTime(2026, 2, 28)),
        const CalculatedAge(2, AgeUnit.months),
      );
      expect(
        age(DateTime(2025, 10, 31), DateTime(2026, 2, 27)),
        const CalculatedAge(3, AgeUnit.months),
      );
      expect(
        age(DateTime(2025, 10, 31), DateTime(2026, 2, 28)),
        const CalculatedAge(4, AgeUnit.months),
      );
    });
  });

  group('leap day', () {
    final dob = DateTime(2000, 2, 29);
    test('non-leap years: birthday counted on 28 February', () {
      expect(age(dob, DateTime(2027, 2, 27))!.value, 26);
      expect(age(dob, DateTime(2027, 2, 28))!.value, 27);
      expect(age(dob, DateTime(2027, 3, 1))!.value, 27);
    });
    test('leap years: birthday on 29 February', () {
      expect(age(dob, DateTime(2028, 2, 28))!.value, 27);
      expect(age(dob, DateTime(2028, 2, 29))!.value, 28);
    });
    test('leap-day baby', () {
      expect(
        age(DateTime(2024, 2, 29), DateTime(2024, 3, 28)),
        const CalculatedAge(28, AgeUnit.days),
      );
      expect(
        age(DateTime(2024, 2, 29), DateTime(2025, 2, 28)),
        const CalculatedAge(1, AgeUnit.years),
      );
    });
  });

  group('future date of birth', () {
    test('gives no age and a validation error', () {
      final ref = DateTime(2026, 8, 1);
      expect(age(DateTime(2026, 8, 2), ref), isNull);
      expect(calculateAgeFromText('2/8/2026', ref), isNull);
      expect(validateDateOfBirth('2/8/2026', ref), contains('future'));
      expect(
        validateDateOfBirth('2/8/2026', ref, referenceIsVisitDate: true),
        contains('after the visit date'),
      );
      expect(validateDateOfBirth('1/8/2026', ref), isNull);
      expect(validateDateOfBirth('?/4/2023', ref), isNull);
      expect(validateDateOfBirth('', ref), isNull);
    });
  });

  group('parseDateOfBirth', () {
    final ref = DateTime(2026, 8, 1);
    test('day-first and ISO', () {
      expect(
        parseDateOfBirth('7/8/1996', reference: ref),
        DateTime(1996, 8, 7),
      );
      expect(
        parseDateOfBirth('07-08-1996', reference: ref),
        DateTime(1996, 8, 7),
      );
      expect(
        parseDateOfBirth('1996-08-07', reference: ref),
        DateTime(1996, 8, 7),
      );
    });
    test('two-digit years never land in the future', () {
      expect(parseDateOfBirth('4/8/23', reference: ref), DateTime(2023, 8, 4));
      expect(parseDateOfBirth('7/8/96', reference: ref), DateTime(1996, 8, 7));
      expect(parseDateOfBirth('1/1/26', reference: ref), DateTime(2026, 1, 1));
      expect(parseDateOfBirth('1/1/27', reference: ref), DateTime(1927, 1, 1));
    });
    test('unclear or impossible dates are ignored', () {
      for (final v in [
        '',
        '?/4/2023',
        '31/2/1991',
        '29/2/2023',
        '13/13/2000',
        'abc',
      ]) {
        expect(parseDateOfBirth(v, reference: ref), isNull, reason: v);
      }
      expect(
        parseDateOfBirth('29/2/2024', reference: ref),
        DateTime(2024, 2, 29),
      );
    });
  });

  group('importer', () {
    test('blank age is calculated from DOB on the visit date', () {
      const csv =
          'cardNumber,visitDate,name,dateOfBirth,age,ageUnit\n'
          'L 1,2026-08-03,Sample Adult,4/8/1990,,\n'
          'L 2,2026-08-03,Sample Baby,20/7/2026,,years\n'
          'L 3,2026-08-03,Sample Infant,3/2/2026,,\n'
          'L 4,2026-08-03,Sample Typed,4/8/1990,40,years\n'
          'L 5,2026-08-03,Sample Unclear,?/4/2023,,\n';
      final rows = parseRegisterCsv(csv, now: DateTime(2026, 11, 1));
      expect(rows.every((r) => r.isValid), isTrue);
      final p = rows.map((r) => r.patient!).toList();
      expect([p[0].age, p[0].ageUnit], [35, AgeUnit.years]);
      expect([p[1].age, p[1].ageUnit], [14, AgeUnit.days]);
      expect([p[2].age, p[2].ageUnit], [6, AgeUnit.months]);
      expect([p[3].age, p[3].ageUnit], [40, AgeUnit.years]);
      expect(p[4].age, isNull);
    });

    test('without a visit date, today is the reference', () {
      const csv = 'cardNumber,name,dateOfBirth\nL 6,Sample,1/11/2000\n';
      final p = parseRegisterCsv(
        csv,
        now: DateTime(2026, 11, 1),
      ).single.patient!;
      expect([p.age, p.ageUnit], [26, AgeUnit.years]);
    });

    test('DOB after the visit date is rejected', () {
      const csv =
          'cardNumber,visitDate,name,dateOfBirth\n'
          'L 7,2026-08-03,Sample,5/8/2026\n';
      final row = parseRegisterCsv(csv).single;
      expect(row.isValid, isFalse);
      expect(row.errors.single, contains('after the visit date'));
    });
  });

  group('display for stored records without an age', () {
    test('computed on read, stored age untouched', () {
      final p = RegisterPatient(
        id: 'x',
        cardNumber: 'H 1',
        name: 'Sample',
        dateOfBirth: '1/6/2026',
        visitDate: DateTime(2026, 8, 3),
        createdAt: DateTime(2026, 8, 3),
      );
      expect(p.age, isNull);
      expect(p.isAgeCalculated, isTrue);
      expect(p.ageDisplay, '2 months');
      expect(p.toJson()['age'], isNull);
    });

    test('stored age wins; no DOB shows a dash', () {
      final stored = RegisterPatient(
        id: 'x',
        cardNumber: 'H 2',
        name: 'Sample',
        dateOfBirth: '1/6/1990',
        age: 30,
        createdAt: DateTime(2026, 8, 3),
      );
      expect(stored.ageDisplay, '30 yrs');
      expect(stored.isAgeCalculated, isFalse);
      final none = RegisterPatient(
        id: 'y',
        cardNumber: 'H 3',
        name: 'Sample',
        createdAt: DateTime(2026, 8, 3),
      );
      expect(none.ageDisplay, '-');
    });
  });
}
