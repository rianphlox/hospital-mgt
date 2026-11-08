import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:crownlog_flutter/models/register_patient_models.dart';
import 'package:crownlog_flutter/services/patient_register_service.dart';
import 'package:crownlog_flutter/utils/patient_register_utils.dart';
import 'package:crownlog_flutter/utils/register_import.dart';

void main() {
  group('normalizeCardNumber', () {
    test('spacing, case and punctuation do not matter', () {
      for (final input in ['B50', 'b 50', 'B 50', ' B  50 ', 'b-50', 'B/50']) {
        expect(normalizeCardNumber(input), 'B50', reason: input);
      }
    });

    test('letter prefixes are kept', () {
      expect(normalizeCardNumber('A 146'), 'A146');
      expect(normalizeCardNumber('a146'), isNot(normalizeCardNumber('B146')));
    });

    test('empty input stays empty', () {
      expect(normalizeCardNumber('  '), '');
    });
  });

  group('name search keys', () {
    test('contain every prefix of every word, lower-case', () {
      final keys = buildNameSearchKeys('Jane Doe');
      expect(keys, containsAll(['j', 'ja', 'jan', 'jane', 'd', 'do', 'doe']));
      expect(keys.every((k) => k == k.toLowerCase()), isTrue);
      expect(keys.toSet().length, keys.length);
    });

    test('ignore punctuation and extra spaces', () {
      expect(nameWords("  Mary-Jane  O'Neil "), ['mary', 'jane', 'oneil']);
    });

    test('matching is case-insensitive and word-prefix based', () {
      expect(nameMatchesQuery('Jane Doe', 'jane'), isTrue);
      expect(nameMatchesQuery('Jane Doe', 'DO'), isTrue);
      expect(nameMatchesQuery('Jane Doe', 'ja do'), isTrue);
      expect(nameMatchesQuery('Jane Doe', 'ane'), isFalse);
      expect(nameMatchesQuery('Jane Doe', 'jane x'), isFalse);
      expect(nameMatchesQuery('Jane Doe', ''), isFalse);
    });
  });

  test('register search offers only card number and name', () {
    expect(RegisterSearchMode.values, [
      RegisterSearchMode.cardNumber,
      RegisterSearchMode.name,
    ]);
  });

  group('card number validation', () {
    test('accepts register-style card numbers', () {
      for (final c in ['B 50', 'b50', 'A 199', 'Z-1', 'OPD/12']) {
        expect(validateCardNumber(c), isNull, reason: c);
      }
    });

    test('rejects blank, digit-less, odd characters and over-long values', () {
      expect(validateCardNumber(null), isNotNull);
      expect(validateCardNumber('   '), isNotNull);
      expect(validateCardNumber('ABC'), isNotNull);
      expect(validateCardNumber('B#50'), isNotNull);
      expect(validateCardNumber('B ${'1' * 30}'), isNotNull);
    });
  });

  group('CSV parsing', () {
    test('handles quotes, commas, newlines and CRLF', () {
      final rows = parseCsv('a,b,c\r\n1,"x, y","say ""hi"""\r\n2,"line1\nline2",\r\n');
      expect(rows.length, 3);
      expect(rows[1], ['1', 'x, y', 'say "hi"']);
      expect(rows[2], ['2', 'line1\nline2', '']);
    });

    test('parses register rows into patients', () {
      const csv = 'cardNumber,visitDate,name,dateOfBirth,sex,age,ageUnit,'
          'contactAddress,stateOfOrigin,phone,firstContact,nokName,nokRelationship,nokAddress,'
          'nokPhone,lga,ward,facility,needsReview,reviewNotes\n'
          'z 1,2026-01-05,Sample Patient,01/01/90,F,36,years,Sample Street,'
          'Sample State,00000000001,Yes,Sample Kin,Husband,Sample Street,00000000002,'
          'Sample LGA,Sample Ward,Sample Facility,true,"DOB unclear, check"\n';
      final rows = parseRegisterCsv(csv, now: DateTime(2026, 1, 1));
      expect(rows.length, 1);
      final p = rows.single.patient!;
      expect(rows.single.isValid, isTrue);
      expect(p.cardNumber, 'z 1');
      expect(p.cardNumberNormalized, 'Z1');
      expect(p.name, 'Sample Patient');
      expect(p.sex, RegisterSex.female);
      expect(p.age, 36);
      expect(p.ageYears, 36);
      expect(p.firstContact, isTrue);
      expect(p.visitDate, DateTime(2026, 1, 5));
      expect(p.needsReview, isTrue);
      expect(p.reviewNotes, 'DOB unclear, check');
      expect(p.nokRelationship, 'Husband');
    });

    test('import preserves babies age and unit for display', () {
      const csv = 'cardNumber,name,age,ageUnit,firstContact\nZ 3,Sample Baby,2,days,No\n';
      final p = parseRegisterCsv(csv).single.patient!;
      expect(p.age, 2);
      expect(p.ageUnit, AgeUnit.days);
      expect(p.ageDisplay, '2 days');
      expect(p.ageYears, 0);
      expect(p.firstContact, isFalse);
      expect(p.sex, RegisterSex.unknown);
    });

    test('rows missing card number or name are reported, not imported', () {
      const csv = 'cardNumber,name,age\n,No Card,3\nZ 9,,4\nZ 10,Bad Age,abc\n';
      final rows = parseRegisterCsv(csv);
      expect(rows.every((r) => !r.isValid), isTrue);
      expect(rows[0].errors, contains('Missing card number'));
      expect(rows[1].errors, contains('Missing name'));
      expect(rows[2].errors.single, contains('not a whole number'));
    });

    test('old files with serialNo / ageBand and unknown columns still import', () {
      const csv = 'serialNo,visitDate,cardNumber,name,age,ageUnit,ageBand,somethingElse\n'
          '1,2026-01-05,Z 11,Sample Old,36,years,>=20 years,ignored\n';
      final rows = parseRegisterCsv(csv);
      expect(rows.single.isValid, isTrue);
      final p = rows.single.patient!;
      expect(p.cardNumber, 'Z 11');
      expect(p.age, 36);
      expect(p.toJson().containsKey('serialNo'), isFalse);
      expect(p.toJson().containsKey('ageBand'), isFalse);

      const json = '[{"serialNo":3,"cardNumber":"Z 12","name":"Sample Old Json",'
          '"ageBand":"5-9 years","age":7,"extra":"x"}]';
      final jsonRows = parseRegisterImport(json);
      expect(jsonRows.single.isValid, isTrue);
      expect(jsonRows.single.patient!.age, 7);
    });

    test('rows with an invalid card number are rejected', () {
      const csv = 'cardNumber,name\nABC,No Digits\nB#5,Bad Char\n   ,Blank\n';
      final rows = parseRegisterCsv(csv);
      expect(rows.every((r) => !r.isValid), isTrue);
      expect(rows[0].errors.single, contains('must include a number'));
      expect(rows[1].errors.single, contains('Use only'));
      expect(rows[2].errors, contains('Missing card number'));
    });

    test('export puts card number first and drops serialNo / ageBand', () {
      final header = registerCsvColumns;
      expect(header.first, 'cardNumber');
      expect(header, isNot(contains('serialNo')));
      expect(header, isNot(contains('ageBand')));
    });

    test('header without required columns is rejected', () {
      expect(() => parseRegisterCsv('foo,bar\n1,2\n'), throwsFormatException);
    });

    test('duplicates by card number are marked (existing and in-file)', () {
      const csv = 'cardNumber,name\nZ 1,A\nz1,B\nZ 2,C\nZ 3,D\n';
      final rows = parseRegisterCsv(csv);
      final count = markDuplicates(rows, {'Z3'});
      expect(count, 2);
      expect(rows.map((r) => r.isDuplicate).toList(), [false, true, false, true]);
    });

    test('export then import round-trips', () {
      final original = parseRegisterCsv(
        'cardNumber,name,sex,age,ageUnit,phone,firstContact,reviewNotes,needsReview\n'
        'Z 5,"Sample, Person",M,4,years,000,No,"has ""quotes""",true\n',
      ).single.patient!;
      final again = parseRegisterCsv(registerPatientsToCsv([original])).single.patient!;
      expect(again.name, 'Sample, Person');
      expect(again.cardNumber, 'Z 5');
      expect(again.sex, RegisterSex.male);
      expect(again.age, 4);
      expect(again.firstContact, isFalse);
      expect(again.reviewNotes, 'has "quotes"');
      expect(again.needsReview, isTrue);
    });

    test('JSON with a patients list is accepted', () {
      const json = '{"patients":[{"cardNumber":"Z 7","name":"Sample Json","age":30,'
          '"ageUnit":"years","needsReview":false,"firstContact":"Yes"}]}';
      final rows = parseRegisterImport(json);
      expect(rows.single.patient!.cardNumberNormalized, 'Z7');
      expect(rows.single.patient!.age, 30);
      expect(rows.single.patient!.firstContact, isTrue);
    });
  });

  test('visit dates accept ISO and day-first formats', () {
    expect(parseRegisterDate('2026-02-07'), DateTime(2026, 2, 7));
    expect(parseRegisterDate('07/02/2026'), DateTime(2026, 2, 7));
    expect(parseRegisterDate('7/2/26'), DateTime(2026, 2, 7));
    expect(parseRegisterDate('13/13/2026'), isNull);
  });

  test('toJson stores card/name search fields and preserves age', () {
    final p = RegisterPatient(
      id: '',
      cardNumber: 'b 50',
      name: 'Sample Person',
      age: 6,
      ageUnit: AgeUnit.months,
      createdAt: DateTime(2026, 1, 1),
    );
    final json = p.toJson();
    expect(json['cardNumberNormalized'], 'B50');
    expect(json['nameLower'], 'sample person');
    expect(json['nameSearchKeys'], contains('pers'));
    expect(json['age'], 6);
    expect(json['ageUnit'], 'months');
    expect(json['ageYears'], 0);
    expect(RegisterPatient.fromJson(json, 'test').ageDisplay, '6 months');
    expect(json.containsKey('ageBand'), isFalse);
    expect(json.containsKey('serialNo'), isFalse);
  });

  test('sample import file in docs/ parses cleanly', () {
    // Keep the sample file valid; it must only ever contain fake data.
    final rows = parseRegisterCsv(_sampleCsv());
    expect(rows.length, 3);
    expect(rows.every((r) => r.isValid), isTrue);
  });
}

String _sampleCsv() {
  // Read relative to the package root, where `flutter test` runs.
  return File('docs/sample_patient_register_import.csv').readAsStringSync();
}
