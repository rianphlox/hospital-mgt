import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:crownlog_flutter/models/register_patient_models.dart';
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

  group('AgeRange.parse', () {
    test('single age and ranges', () {
      expect(AgeRange.parse('45').toString(), '45');
      expect(AgeRange.parse('40-50').toString(), '40-50');
      expect(AgeRange.parse('50 - 40').toString(), '40-50');
      expect(AgeRange.parse('40 to 50').toString(), '40-50');
      expect(AgeRange.parse('60+')!.min, 60);
      expect(AgeRange.parse('<5')!.max, 4);
      expect(AgeRange.parse('<=5')!.max, 5);
      expect(AgeRange.parse('abc'), isNull);
      expect(AgeRange.parse(''), isNull);
    });
  });

  group('age band', () {
    test('derived from age and unit', () {
      expect(AgeBandExtension.fromAge(3, AgeUnit.days), AgeBand.days0to28);
      expect(AgeBandExtension.fromAge(6, AgeUnit.months), AgeBand.days29toMonths11);
      expect(AgeBandExtension.fromAge(2, AgeUnit.years), AgeBand.months12to59);
      expect(AgeBandExtension.fromAge(7, AgeUnit.years), AgeBand.years5to9);
      expect(AgeBandExtension.fromAge(19, AgeUnit.years), AgeBand.years10to19);
      expect(AgeBandExtension.fromAge(20, AgeUnit.years), AgeBand.years20plus);
    });

    test('labels round-trip, including the printed ≥ sign', () {
      for (final b in AgeBand.values) {
        expect(AgeBandExtension.fromLabel(b.label), b);
      }
      expect(AgeBandExtension.fromLabel('≥20 years'), AgeBand.years20plus);
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
      const csv = 'serialNo,visitDate,cardNumber,name,dateOfBirth,sex,age,ageUnit,ageBand,'
          'contactAddress,stateOfOrigin,phone,firstContact,nokName,nokRelationship,nokAddress,'
          'nokPhone,lga,ward,facility,needsReview,reviewNotes\n'
          '1,2026-01-05,z 1,Sample Patient,01/01/90,F,36,years,>=20 years,Sample Street,'
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
      expect(p.ageBand, AgeBand.years20plus);
      expect(p.firstContact, isTrue);
      expect(p.visitDate, DateTime(2026, 1, 5));
      expect(p.needsReview, isTrue);
      expect(p.reviewNotes, 'DOB unclear, check');
      expect(p.nokRelationship, 'Husband');
      expect(p.serialNo, 1);
    });

    test('babies recorded in days count as age 0 for search', () {
      const csv = 'cardNumber,name,age,ageUnit,firstContact\nZ 3,Sample Baby,2,days,No\n';
      final p = parseRegisterCsv(csv).single.patient!;
      expect(p.ageYears, 0);
      expect(p.ageBand, AgeBand.days0to28);
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

  test('toJson stores the search fields', () {
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
    expect(json['ageYears'], 0);
    expect(json['ageBand'], '29 days-11 months');
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
