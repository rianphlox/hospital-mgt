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

    test('leading zeros do not change card identity', () {
      for (final card in ['H1', 'H01', 'H001', 'H0001', 'h 001', 'H-01']) {
        expect(normalizeCardNumber(card), 'H1', reason: card);
        expect(validateCardNumber(card), isNull, reason: card);
        expect(registerCardKey(2026, card), '2026:H1');
      }
      expect(normalizeCardNumber('B 00050'), 'B50');
      expect(normalizeCardNumber('H000100'), 'H100');
      expect(normalizeCardNumber('H0001234567890123456'), 'H1234567890123456');
    });

    test('zero-only cards are valid and share the H0 identity', () {
      for (final card in ['H0', 'H00', 'h 000', 'H-0000']) {
        expect(normalizeCardNumber(card), 'H0');
        expect(validateCardNumber(card), isNull);
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
      for (final c in ['B 50', 'b50', 'A 199', 'L-1', 'A/12']) {
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
      final rows = parseCsv(
        'a,b,c\r\n1,"x, y","say ""hi"""\r\n2,"line1\nline2",\r\n',
      );
      expect(rows.length, 3);
      expect(rows[1], ['1', 'x, y', 'say "hi"']);
      expect(rows[2], ['2', 'line1\nline2', '']);
    });

    test('parses register rows into patients', () {
      const csv =
          'cardNumber,visitDate,name,dateOfBirth,sex,age,ageUnit,'
          'contactAddress,stateOfOrigin,phone,firstContact,nokName,nokRelationship,nokAddress,'
          'nokPhone,lga,ward,facility,needsReview,reviewNotes\n'
          'l 1,2026-01-05,Sample Patient,01/01/90,F,36,years,Sample Street,'
          'Sample State,00000000001,Yes,Sample Kin,Husband,Sample Street,00000000002,'
          'Sample LGA,Sample Ward,Sample Facility,true,"DOB unclear, check"\n';
      final rows = parseRegisterCsv(csv, now: DateTime(2026, 1, 1));
      expect(rows.length, 1);
      final p = rows.single.patient!;
      expect(rows.single.isValid, isTrue);
      expect(p.cardNumber, 'l 1');
      expect(p.cardNumberNormalized, 'L1');
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
      const csv =
          'cardNumber,name,age,ageUnit,firstContact\nL 3,Sample Baby,2,days,No\n';
      final p = parseRegisterCsv(csv).single.patient!;
      expect(p.age, 2);
      expect(p.ageUnit, AgeUnit.days);
      expect(p.ageDisplay, '2 days');
      expect(p.ageYears, 0);
      expect(p.firstContact, isFalse);
      expect(p.sex, RegisterSex.unknown);
    });

    test('rows missing card number or name are reported, not imported', () {
      const csv = 'cardNumber,name,age\n,No Card,3\nL 9,,4\nL 10,Bad Age,abc\n';
      final rows = parseRegisterCsv(csv);
      expect(rows.every((r) => !r.isValid), isTrue);
      expect(rows[0].errors, contains('Missing card number'));
      expect(rows[1].errors, contains('Missing name'));
      expect(rows[2].errors.single, contains('not a whole number'));
    });

    test(
      'old files with serialNo / ageBand and unknown columns still import',
      () {
        const csv =
            'serialNo,visitDate,cardNumber,name,age,ageUnit,ageBand,somethingElse\n'
            '1,2026-01-05,L 11,Sample Old,36,years,>=20 years,ignored\n';
        final rows = parseRegisterCsv(csv);
        expect(rows.single.isValid, isTrue);
        final p = rows.single.patient!;
        expect(p.cardNumber, 'L 11');
        expect(p.age, 36);
        expect(p.toJson().containsKey('serialNo'), isFalse);
        expect(p.toJson().containsKey('ageBand'), isFalse);

        const json =
            '[{"serialNo":3,"cardNumber":"L 12","name":"Sample Old Json",'
            '"ageBand":"5-9 years","age":7,"extra":"x"}]';
        final jsonRows = parseRegisterImport(json);
        expect(jsonRows.single.isValid, isTrue);
        expect(jsonRows.single.patient!.age, 7);
      },
    );

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
      const csv = 'cardNumber,name\nL 1,A\nl1,B\nL 2,C\nL 3,D\n';
      final rows = parseRegisterCsv(csv);
      final count = markDuplicates(rows, {
        registerCardKey(DateTime.now().year, 'L3'),
      });
      expect(count, 2);
      expect(rows.map((r) => r.isDuplicate).toList(), [
        false,
        true,
        false,
        true,
      ]);
    });

    test('export then import round-trips', () {
      final original = parseRegisterCsv(
        'cardNumber,name,sex,age,ageUnit,phone,firstContact,reviewNotes,needsReview\n'
        'L 5,"Sample, Person",M,4,years,000,No,"has ""quotes""",true\n',
      ).single.patient!;
      final again = parseRegisterCsv(
        registerPatientsToCsv([original]),
      ).single.patient!;
      expect(again.name, 'Sample, Person');
      expect(again.cardNumber, 'L 5');
      expect(again.sex, RegisterSex.male);
      expect(again.age, 4);
      expect(again.firstContact, isFalse);
      expect(again.reviewNotes, 'has "quotes"');
      expect(again.needsReview, isTrue);
    });

    test('JSON with a patients list is accepted', () {
      const json =
          '{"patients":[{"cardNumber":"L 7","name":"Sample Json","age":30,'
          '"ageUnit":"years","needsReview":false,"firstContact":"Yes"}]}';
      final rows = parseRegisterImport(json);
      expect(rows.single.patient!.cardNumberNormalized, 'L7');
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

  group('zero-padded legacy cards', () {
    RegisterPatient legacy(String card, int year, String storedKey) =>
        RegisterPatient.fromJson({
          'cardNumber': card,
          'cardNumberNormalized': storedKey,
          'registerYear': year,
          'name': 'Sample Patient',
          'createdAt': DateTime(year),
        }, '$year:$card');

    test('reads rebuild identity without changing the written card', () {
      final p = legacy('h 001', 2026, 'H001');
      expect(p.cardNumberNormalized, 'H1');
      expect(p.cardKey, '2026:H1');
      expect(p.cardNumber, 'h 001');
      expect(p.toJson()['cardNumber'], 'h 001');
      expect(p.toJson()['cardNumberNormalized'], 'H1');
    });

    test('search is bidirectional, year scoped and exact-first', () {
      final patients = [
        legacy('H010', 2026, 'H010'),
        legacy('H19', 2026, 'H19'),
        legacy('H001', 2026, 'H001'),
        legacy('H2', 2026, 'H2'),
        legacy('H0001', 2025, 'H0001'),
      ];
      for (final query in ['H1', 'H01', 'H001', 'h-0001']) {
        final matches = PatientRegisterService.filterByCardNumber(
          patients,
          query,
          year: 2026,
        );
        expect(matches.map((p) => p.cardNumber), ['H001', 'H010', 'H19']);
      }
      expect(
        PatientRegisterService.filterByCardNumber([
          legacy('H1', 2026, 'H1'),
        ], 'H001').single.cardNumber,
        'H1',
      );
      expect(
        PatientRegisterService.filterByCardNumber(patients, 'H'),
        hasLength(5),
      );
      expect(PatientRegisterService.filterByCardNumber(patients, ''), isEmpty);
      expect(
        PatientRegisterService.filterByCardNumber(patients, 'H9'),
        isEmpty,
      );
    });

    test(
      'CSV/JSON accept zeros and deduplicate per year and existing keys',
      () {
        final rows = parseRegisterCsv(
          'cardNumber,name,registerYear\n'
          'H001,Sample One,2026\nH1,Sample Two,2026\n'
          'H0001,Sample Three,2027\nH013,Sample Four,2026\n'
          'H000,Sample Zero,2026\nH0,Sample Other Zero,2026\n',
        );
        expect(rows.every((r) => r.isValid), isTrue);
        expect(markDuplicates(rows, {legacy('H13', 2026, 'H13').cardKey}), 3);
        expect(rows.map((r) => r.isDuplicate), [
          false,
          true,
          false,
          true,
          false,
          true,
        ]);
        final json = parseRegisterJson(
          '[{"cardNumber":"H-0001","name":"Sample","registerYear":2026}]',
        ).single.patient!;
        expect(json.cardNumber, 'H-0001');
        expect(json.cardKey, '2026:H1');
        expect(
          parseRegisterCsv(
            registerPatientsToCsv([json]),
          ).single.patient!.cardNumber,
          'H-0001',
        );
      },
    );
  });

  group('annual cards', () {
    test('constructor derives year from visit date then creation date', () {
      final p = RegisterPatient(
        id: '',
        cardNumber: 'B 50',
        name: 'Sample',
        visitDate: DateTime(2026, 2, 7),
        createdAt: DateTime(2027),
      );
      expect(p.registerYear, 2026);
      expect(p.copyWith(registerYear: 2027).registerYear, 2027);
      expect(
        RegisterPatient(
          id: '',
          cardNumber: 'B 50',
          name: 'Sample',
          createdAt: DateTime(2025),
        ).registerYear,
        2025,
      );
    });

    test('legacy Firestore data derives year without requiring migration', () {
      final base = <String, dynamic>{
        'cardNumber': 'B 50',
        'name': 'Sample',
        'visitDate': '2026-02-07',
        'createdAt': DateTime(2027),
      };
      expect(RegisterPatient.fromJson(base, 'legacy').registerYear, 2026);
      base.remove('visitDate');
      expect(RegisterPatient.fromJson(base, 'legacy').registerYear, 2027);
      base['registerYear'] = 2024;
      final p = RegisterPatient.fromJson(base, 'legacy');
      expect(p.registerYear, 2024);
      expect(p.toJson()['registerYear'], 2024);
      expect(p.copyWith(name: 'Sample Edit').registerYear, 2024);
      expect(
        RegisterPatient.fromJson({}, 'empty').registerYear,
        DateTime.now().year,
      );
    });

    test(
      'imports explicit registerYear or year, then visit date, then now',
      () {
        final rows = parseRegisterCsv(
          'cardNumber,name,registerYear,year,visitDate\n'
          'A 1,Sample One,2024,2025,2026-02-07\n'
          'A 2,Sample Two,,2025,2026-02-07\n'
          'A 3,Sample Three,,,2026-02-07\n'
          'A 4,Sample Four,,,\n',
          now: DateTime(2027),
        );
        expect(rows.map((r) => r.patient!.registerYear), [
          2024,
          2025,
          2026,
          2027,
        ]);
        expect(
          parseRegisterCsv(
            'cardNumber,name,registerYear\nA 1,Sample,bad\n',
          ).single.isValid,
          isFalse,
        );
        final json = parseRegisterJson(
          '[{"cardNumber":"A 1","name":"Sample","year":2026}]',
        );
        expect(json.single.patient!.registerYear, 2026);
      },
    );

    test('duplicate keys include year and normalized card number', () {
      final rows = parseRegisterCsv(
        'cardNumber,name,registerYear\n'
        'B 50,Sample One,2026\nb50,Sample Two,2027\n'
        'B-50,Sample Three,2026\nA 1,Sample Four,2027\n',
      );
      expect(markDuplicates(rows, {registerCardKey(2027, 'A 1')}), 2);
      expect(rows.map((r) => r.isDuplicate), [false, false, true, true]);
      expect(rows[0].patient!.cardKey, isNot(rows[1].patient!.cardKey));
    });

    test('selected year filters card and name matches, null includes all', () {
      final patients = parseRegisterCsv(
        'cardNumber,name,registerYear\n'
        'B 50,Sample Person,2026\nB 50,Sample Person,2027\n',
      ).map((r) => r.patient!).toList();
      expect(
        PatientRegisterService.filterByYear(patients, 2026).single.registerYear,
        2026,
      );
      expect(
        PatientRegisterService.filterByYear(patients, 2027).single.registerYear,
        2027,
      );
      expect(PatientRegisterService.filterByYear(patients, 2028), isEmpty);
      expect(PatientRegisterService.filterByYear(patients, null), hasLength(2));
    });

    test('A through L only, followed by a number', () {
      for (final c in ['A 199', 'B 50', 'l/12', 'a-1']) {
        expect(validateCardNumber(c), isNull);
      }
      for (final c in ['M 1', 'Z 1', 'OPD/12', '50', 'AA 1', 'B 1 X']) {
        expect(validateCardNumber(c), contains('A-L'));
      }
    });

    test('CSV round trip retains explicit card year', () {
      final p = parseRegisterCsv(
        'cardNumber,name,registerYear,visitDate\n'
        'A 1,Sample,2025,2026-02-07\n',
      ).single.patient!;
      expect(
        parseRegisterCsv(
          registerPatientsToCsv([p]),
        ).single.patient!.registerYear,
        2025,
      );
    });
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
