import 'dart:convert';
import 'dart:io';

import 'package:crownlog_flutter/models/hmo_models.dart';
import 'package:crownlog_flutter/services/hmo/hmo_client.dart';
import 'package:crownlog_flutter/services/hmo/hmo_format.dart';
import 'package:crownlog_flutter/services/hmo/hmo_registry.dart';
import 'package:crownlog_flutter/services/hmo/phml_client.dart';
import 'package:crownlog_flutter/services/hmo/tht_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClient implements HmoClient {
  int logins = 0;
  bool expireNext = false;
  @override
  String get id => 'fake';
  @override
  String get label => 'Fake';
  @override
  String get queryHint => 'id';
  @override
  Future<Object> login(HmoCredentials creds) async => ++logins;
  @override
  Future<HmoSearchResult> search(Object session, String query) async {
    if (expireNext) {
      expireNext = false;
      throw const HmoSessionExpired('Fake');
    }
    return HmoSearchResult(const [], notice: 'session $session');
  }
}

void main() {
  test('portal dates become dd/mm/yyyy', () {
    expect(toDdMmYyyy('2013-03-30T00:00:00'), '30/03/2013');
    expect(toDdMmYyyy('05 April, 1965'), '05/04/1965');
    expect(toDdMmYyyy('19 November, 2008'), '19/11/2008');
    expect(toDdMmYyyy('0001-01-01T00:00:00'), isNull);
    expect(toDdMmYyyy(''), isNull);
    expect(toDdMmYyyy(null), isNull);
  });

  test('names: HTML entities and nbsp decoded before title-casing', () {
    expect(titleCase('CHIDI &nbsp; NWOSU'), 'Chidi Nwosu');
    expect(titleCase('CHIDI&NBSP;NWOSU'), 'Chidi Nwosu');
    expect(titleCase('ADA\u00A0\u00A0 OBI '), 'Ada Obi');
    expect(titleCase("O&#39;BRIEN &amp; SONS"), "O'Brien & Sons");
    expect(titleCase('MARY&#x27;S'), "Mary's");
    expect(cleanText('  A   B\tC  '), 'A B C');
    final tht = ThtClient.rowToMember({
      'EligibilityStatus': 'ELIGIBLE',
      'FirstName': 'CHIDI',
      'OtherName': '&nbsp;',
      'LastName': 'NWOSU',
    });
    expect(tht.name, 'Chidi Nwosu');
    final phml = PhmlClient.rowToMember({
      'firstname': 'AMAKA&nbsp;',
      'surname': 'EZE',
    });
    expect(phml.name, 'Amaka Eze');
  });

  test('THT photo URL from PixPath', () {
    const base = ThtClient.photoBase;
    expect(
      ThtClient.photoUrlFrom(r'D:\pictures\1234567-01.jpg'),
      '${base}1234567-01.jpg',
    );
    expect(
      ThtClient.photoUrlFrom(r'D:\Pictures\ABC123.PNG'),
      '${base}ABC123.PNG',
    );
    expect(
      ThtClient.photoUrlFrom(r'D:\pictures\my photo#1.jpg'),
      '${base}my%20photo%231.jpg',
    );
    expect(ThtClient.photoUrlFrom(''), isNull);
    expect(ThtClient.photoUrlFrom('   '), isNull);
    expect(ThtClient.photoUrlFrom(null), isNull);
    expect(ThtClient.photoUrlFrom(r'D:\pictures\'), isNull);

    final elig = ThtClient.rowToMember({
      'EligibilityStatus': 'ELIGIBLE',
      'FirstName': 'ADA',
      'LastName': 'OBI',
      'PixPath': r'D:\pictures\x1.jpg',
    });
    expect(elig.photoUrl, '${base}x1.jpg');
    expect(elig.hasPhoto, isTrue);
    final noPix = ThtClient.rowToMember({
      'EligibilityStatus': 'ELIGIBLE',
      'FirstName': 'ADA',
      'PixPath': '',
    });
    expect(noPix.photoUrl, isNull);
    expect(noPix.hasPhoto, isFalse);
    final search = ThtClient.searchRowToMember({
      'LegacyCode': '1110000000-01',
      'FirstName': 'ADA',
      'PixPath': r'D:\Pictures\x2.jpg',
    });
    expect(search.photoUrl, '${base}x2.jpg');
    expect(
      PhmlClient.rowToMember({'nhis_no': '1', 'firstname': 'A'}).photoUrl,
      isNull,
    );
  });

  test('THT IDs vs names', () {
    expect(ThtClient.looksLikeId('AF1234567890_1'), isTrue);
    expect(ThtClient.looksLikeId('1110000000-01'), isTrue);
    expect(ThtClient.looksLikeId('Ada Obi'), isFalse);
    expect(ThtClient.normaliseId('1110000000/01'), '1110000000-01');
    final m = ThtClient.searchRowToMember({
      'LegacyCode': '1110000000-01',
      'FirstName': 'ADA',
      'LastName': 'OBI',
      'DependantID': 1,
      'GenderName': 'Female',
      'dob': '2020-01-02T00:00:00',
      'IsTerminated': 'false',
      'Terminationdate': '2026-12-31T00:00:00',
    });
    expect(m.status, 'on list');
    expect(m.dateOfBirth, '02/01/2020');
    expect(m.coverEnds, '31/12/2026');
    expect(m.relationship, 'Dependant 1');
  });

  test('THT row normalises', () {
    final m = ThtClient.rowToMember({
      'EligibilityStatus': 'ELIGIBLE',
      'FirstName': 'JOHN',
      'OtherName': '',
      'LastName': 'DOE',
      'DateOfBirth': '2013-03-30T00:00:00',
      'MemberTermDate': '2026-11-30T00:00:00',
      'PlanName': 'FHIS Plan',
      'DependantType': 'Son',
      'Gender': 'Male',
      'LegacyCode': 'AF1_4',
    });
    expect(m.status, 'eligible');
    expect(m.name, 'John Doe');
    expect(m.coverEnds, '30/11/2026');
    expect(m.memberId, 'AF1_4');
    expect(
      ThtClient.rowToMember({'EligibilityStatus': 'INELIGIBLE'}).status,
      'not eligible',
    );
  });

  test('PHML row normalises and query has DataTables params', () {
    final m = PhmlClient.rowToMember({
      'nhis_no': '123',
      'firstname': 'JANE',
      'surname': 'DOE',
      'sex': 'Female',
      'date_of_birth': '13 May, 1983',
      'dependant_type': 'Spouse',
    });
    expect(m.status, 'on list');
    expect(m.dateOfBirth, '13/05/1983');
    final q = PhmlClient.datatablesQuery('123');
    expect(q['search[value]'], '123');
    expect(q['columns[5][data]'], 'dependant_type');
  });

  test('session is cached and re-login happens when it expires', () async {
    HmoRegistry.clearSessions();
    final fake = _FakeClient();
    HmoRegistry.clients['fake'] = fake;
    const creds = HmoCredentials('u', 'p');
    expect(
      (await HmoRegistry.lookup('fake', 'x', credentials: creds)).notice,
      'session 1',
    );
    expect(
      (await HmoRegistry.lookup('fake', 'x', credentials: creds)).notice,
      'session 1',
    );
    fake.expireNext = true;
    expect(
      (await HmoRegistry.lookup('fake', 'x', credentials: creds)).notice,
      'session 2',
    );
    expect(fake.logins, 2);
    HmoRegistry.clients.remove('fake');
    HmoRegistry.clearSessions();
  });

  // ---- Contact details and families (all data made up) ----

  test('filler values are dropped; phones and emails cleaned', () {
    for (final v in ['None', 'N/A', 'HOUSE', '&nbsp;', ' - ', 'null', '']) {
      expect(cleanValue(v), isNull, reason: v);
    }
    expect(cleanValue('Plot 5&nbsp; Gwagwa'), 'Plot 5 Gwagwa');
    expect(cleanPhone('0803 123 4567'), '08031234567');
    expect(cleanPhone('+234-803-123-4567'), '+2348031234567');
    expect(cleanPhone('&nbsp;'), isNull);
    expect(cleanPhone('00000000000'), isNull);
    expect(cleanPhone('123'), isNull);
    expect(cleanEmail(' Ada.Obi@Example.com '), 'ada.obi@example.com');
    expect(cleanEmail('test@gmail.com'), isNull);
    expect(cleanEmail('None'), isNull);
    expect(cleanEmail('not-an-email'), isNull);
  });

  test('THT family ID', () {
    expect(ThtClient.familyIdOf('1110000000-01'), '1110000000');
    expect(ThtClient.familyIdOf('1110000000-00'), '1110000000');
    expect(ThtClient.familyIdOf('af1234567890_3'), 'AF1234567890');
    expect(ThtClient.familyIdOf('AF1234567890'), 'AF1234567890');
    expect(ThtClient.familyIdOf('JBN123456G-02'), 'JBN123456G');
  });

  test('THT row: contact, employer and cover details', () {
    final m = ThtClient.rowToMember({
      'EligibilityStatus': 'ELIGIBLE',
      'FirstName': 'ADA',
      'LastName': 'OBI',
      'LegacyCode': '1110000000-00',
      'DependantID': 0,
      'DependantType': 'None',
      'Gender': 'Female',
      'Phone1': '0803 123 4567',
      'Phone2': '&nbsp;',
      'Email1': 'ADA@EXAMPLE.COM',
      'Email2': 'test@gmail.com',
      'Address1': 'HOUSE',
      'GroupName': 'ACME NIGERIA LIMITED',
      'DivisionName': 'ABUJA BRANCH',
      'ProviderName': 'THE CROWN HOSPITAL',
      'MemberEffDate': '2026-01-01T00:00:00',
      'MaritalStatusName': 'Unknown',
    });
    expect(m.relationship, 'Principal');
    expect(m.isPrincipal, isTrue);
    expect(m.familyId, '1110000000');
    expect(m.phones, ['08031234567']);
    expect(m.emails, ['ada@example.com']);
    expect(m.address, isNull);
    expect(m.employer, 'Acme Nigeria Limited');
    expect(m.primaryProvider, 'THE CROWN HOSPITAL');
    expect(m.coverStarts, '01/01/2026');
    expect(m.extra, {'Division': 'Abuja Branch'});
    expect(m.notes, isNull);

    final dep = ThtClient.searchRowToMember({
      'LegacyCode': '1110000000-02',
      'FirstName': 'NNEKA',
      'DependantID': 2,
      'Phone1': 'None',
      'Address1': '5 Gwagwa Road',
    });
    expect(dep.relationship, 'Dependant 2');
    expect(dep.dependantNo, 2);
    expect(dep.phones, isEmpty);
    expect(dep.address, '5 Gwagwa Road');
  });

  group('THT families (local fake portal)', () {
    late HttpServer server;
    late ThtClient client;
    final calls = <String>[];
    Map<String, dynamic> row(
      String code,
      int dep,
      String first, {
      String last = 'OBI',
    }) => {
      'LegacyCode': code,
      'DependantID': dep,
      'FirstName': first,
      'LastName': last,
      'IsTerminated': 'false',
      'Phone1': '0803123456$dep',
      'GroupName': 'ACME',
    };
    final members = [
      row('1110000000-00', 0, 'ADA'),
      row('1110000000-01', 1, 'EMEKA'),
      row('1110000000-02', 2, 'NNEKA', last: 'EZE'),
      // Contains the family number but is another family.
      row('21110000000-00', 0, 'ZED', last: 'ABA'),
      row('7770000000-00', 0, 'BOLA', last: 'OBI'),
    ];

    setUp(() async {
      calls.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final path = req.uri.path.replaceFirst('/portal/', '');
        final q = req.uri.queryParameters;
        calls.add('$path ${q['option'] ?? ''}${q['value'] ?? q['iid'] ?? ''}');
        final res = req.response..headers.contentType = ContentType.json;
        if (path == 'api/AccountLogin/SearchMembers') {
          final v = q['value']!.toUpperCase();
          res.write(
            jsonEncode([
              for (final m in members)
                if (q['option'] == 'IID'
                    ? (m['LegacyCode'] as String).contains(v)
                    : (m['LastName'] as String).contains(v))
                  m,
            ]),
          );
        } else if (path == 'api/AccountLogin/GetEligibilityIID') {
          final m = members.firstWhere((m) => m['LegacyCode'] == q['iid']);
          res.write(jsonEncode({...m, 'EligibilityStatus': 'ELIGIBLE'}));
        } else {
          res.headers.contentType = ContentType.html;
          res.write('<p>ok</p>');
        }
        await res.close();
      });
      client = ThtClient(base: 'http://127.0.0.1:${server.port}/portal');
    });
    tearDown(() => server.close(force: true));

    test(
      'name search adds the rest of the family, not look-alike IDs',
      () async {
        final s = await client.login(const HmoCredentials('u', 'p'));
        final r = await client.search(s, 'Ada Obi');
        expect(r.records.map((m) => m.memberId).toSet(), {
          '1110000000-00',
          '1110000000-01',
          '1110000000-02',
        });
        expect(r.records.every((m) => m.status == 'eligible'), isTrue);
        final result = HmoLookupResult(
          hmo: 'tht',
          label: 'THT',
          results: r.records,
          total: r.records.length,
        );
        final f = result.families.single;
        expect(f.id, '1110000000');
        expect(f.principal!.name, 'Ada Obi');
        expect(f.dependants.map((m) => m.name), ['Emeka Obi', 'Nneka Eze']);
        expect(f.principal!.phones, ['08031234560']);
        expect(f.principal!.employer, 'Acme');
        expect(calls, contains('api/AccountLogin/SearchMembers IID1110000000'));
      },
    );

    test('dependant ID search brings in the principal', () async {
      final s = await client.login(const HmoCredentials('u', 'p'));
      final r = await client.search(s, '1110000000/02');
      expect(r.records.first.memberId, '1110000000-02');
      expect(r.records.map((m) => m.memberId).toSet(), {
        '1110000000-00',
        '1110000000-01',
        '1110000000-02',
      });
    });

    test('family number search does not search the family twice', () async {
      final s = await client.login(const HmoCredentials('u', 'p'));
      final r = await client.search(s, '1110000000');
      expect(r.records, hasLength(3));
      expect(
        calls.where((c) => c.startsWith('api/AccountLogin/SearchMembers')),
        hasLength(1),
      );
    });
  });

  test('PHML rows: family order, sex letters, month-first dates', () {
    expect(PhmlClient.dependantNoOf('PRINCIPAL'), 0);
    expect(PhmlClient.dependantNoOf('SPOUSE'), 1);
    expect(PhmlClient.dependantNoOf('CHILD 3'), 4);
    expect(PhmlClient.monthFirstToDdMmYyyy('4/25/1990'), '25/04/1990');
    expect(PhmlClient.monthFirstToDdMmYyyy('12/1/2015'), '01/12/2015');
    final m = PhmlClient.familyRowToMember({
      'nhis_no': '123',
      'firstname': 'AMAKA',
      'surname': 'EZE',
      'sex': 'F',
      'date_of_birth': '4/25/1990',
      'dependant_type': 'CHILD 1',
      'primary_hcp': 'FCT/0001/P',
    }, providerName: 'The Crown Hospital');
    expect(m.sex, 'Female');
    expect(m.dateOfBirth, '25/04/1990');
    expect(m.relationship, 'Child 1');
    expect(m.dependantNo, 2);
    expect(m.familyId, '123');
    expect(m.primaryProvider, 'The Crown Hospital (FCT/0001/P)');
  });

  group('PHML families (local fake portal)', () {
    late HttpServer server;
    late PhmlClient client;
    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final path = req.uri.path;
        final q = req.uri.queryParameters;
        final res = req.response..headers.contentType = ContentType.json;
        if (path == '/hospital/auth') {
          res.headers.contentType = ContentType.html;
          res.write('<input name="_token" value="tok">');
        } else if (path == '/hospital/login') {
          res.write(jsonEncode({'status': true, 'message': 'ok'}));
        } else if (path == '/hospital/dashboard/enrollees/datatables') {
          res.write(
            jsonEncode({
              'recordsFiltered': 2,
              'data': [
                {
                  'nhis_no': '123',
                  'firstname': 'BAYO',
                  'surname': 'EZE',
                  'sex': 'Male',
                  'date_of_birth': '05 April, 1980',
                  'dependant_type': 'PRINCIPAL',
                },
                {
                  'nhis_no': '123',
                  'firstname': 'AMAKA',
                  'surname': 'EZE',
                  'sex': 'Female',
                  'date_of_birth': '25 April, 1990',
                  'dependant_type': 'SPOUSE',
                },
              ],
            }),
          );
        } else if (path == '/hospital/dashboard/request/search/enrollee') {
          final rows = [
            for (final (n, t, d, h) in [
              ('BAYO', 'PRINCIPAL', '4/5/1980', 'FCT/0001/P'),
              ('AMAKA', 'SPOUSE', '4/25/1990', 'FCT/0001/P'),
              ('CHIDI', 'CHILD 1', '1/2/2015', 'FCT/0002/P'),
            ])
              {
                'id': 1,
                'nhis_no': q['enrollee_nhis_no'],
                'firstname': n,
                'surname': 'EZE',
                'sex': 'M',
                'date_of_birth': d,
                'dependant_type': t,
                'primary_hcp': h,
              },
          ];
          res.write(jsonEncode({'status': true, 'message': jsonEncode(rows)}));
        } else if (path == '/hospital/dashboard/request/search/') {
          final name = q['enrolleeHcp'] == 'FCT/0001/P'
              ? 'THE CROWN HOSPITAL'
              : 'HCP Empty';
          res.write(jsonEncode({'status': true, 'message': jsonEncode(name)}));
        } else {
          res.statusCode = 404;
        }
        await res.close();
      });
      client = PhmlClient(base: 'http://127.0.0.1:${server.port}');
    });
    tearDown(() => server.close(force: true));

    test('adds family members and primary hospitals', () async {
      final s = await client.login(const HmoCredentials('u', 'p'));
      final r = await client.search(s, '123');
      expect(r.records.map((m) => m.name), [
        'Bayo Eze',
        'Amaka Eze',
        'Chidi Eze',
      ]);
      expect(
        r.records.first.primaryProvider,
        'The Crown Hospital (FCT/0001/P)',
      );
      expect(r.records.last.primaryProvider, 'FCT/0002/P');
      expect(r.records.last.notes, contains('Not on this hospital'));
      expect(r.records.last.dateOfBirth, '02/01/2015');
      expect(r.notice, contains(PhmlClient.familyNotice));
      final f = HmoLookupResult(
        hmo: 'phml',
        label: 'PHML',
        results: r.records,
        total: 3,
      ).families.single;
      expect(f.principal!.name, 'Bayo Eze');
      expect(f.dependants.map((m) => m.relationship), ['Spouse', 'Child 1']);
    });
  });
}
