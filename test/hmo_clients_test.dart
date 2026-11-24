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
