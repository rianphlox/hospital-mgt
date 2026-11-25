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
}
