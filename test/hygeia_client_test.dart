import 'dart:convert';
import 'dart:io';

import 'package:crownlog_flutter/models/hmo_models.dart';
import 'package:crownlog_flutter/services/hmo/hmo_client.dart';
import 'package:crownlog_flutter/services/hmo/hmo_registry.dart';
import 'package:crownlog_flutter/services/hmo/hygeia_client.dart';
import 'package:flutter_test/flutter_test.dart';

// All data below is made up.
final _today = DateTime(2026, 11, 25);

Map<String, dynamic> _row({
  String legacy = '1234567',
  int dep = 0,
  String first = 'ADA',
  String other = '',
  String last = 'OBI',
  bool isterminated = false,
  int memberTerminated = 0,
  int groupTerminated = 0,
  String effective = '2026-01-01T00:00:00',
  String termination = '2026-12-31T00:00:00',
}) => {
  'nin': null,
  'memberid': 99,
  'lastname': last,
  'firstname': first,
  'othername': other,
  'providername': 'ROAMING',
  'legacycode': legacy,
  'dependantid': dep,
  'phoneno': '08000000000',
  'isterminated': isterminated,
  'groupeffectivedate': '2026-01-01T00:00:00',
  'groupterminationdate': '2026-12-31T00:00:00',
  'effectivedate': effective,
  'terminationdate': termination,
  'memberTerminated': memberTerminated,
  'groupTerminated': groupTerminated,
  'dob': '1990-05-13T00:00:00',
};

String _loginJson(String accessToken, {bool success = true}) => jsonEncode({
  'success': success,
  'message': success ? 'Login Successful' : 'Invalid username or password',
  'token': success
      ? jsonEncode({
          'token_type': 'bearer',
          'expires_in': 8639900,
          'access_token': accessToken,
        })
      : null,
  'provider': {'name': 'Test Hospital', 'providerId': 1},
});

/// A local stand-in for the Hygeia API.
class _FakeHygeia {
  late HttpServer server;
  final requests =
      <({String path, Map<String, String> headers, Object? body})>[];
  int logins = 0;
  bool rejectLogin = false;
  int expireNextSearches = 0;
  Map<String, List<Map<String, dynamic>>> byId = {};
  Map<String, List<Map<String, dynamic>>> byName = {};

  String get base => 'http://127.0.0.1:${server.port}/hygeiaapiservice/api';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final text = await utf8.decoder.bind(req).join();
      final body = text.isEmpty ? null : jsonDecode(text);
      final headers = <String, String>{};
      req.headers.forEach((k, v) => headers[k] = v.join(','));
      final path = req.uri.path.replaceFirst('/hygeiaapiservice/api/', '');
      requests.add((path: path, headers: headers, body: body));
      final res = req.response..headers.contentType = ContentType.json;

      if (path == 'providerlogin') {
        logins++;
        res.write(_loginJson('jwt-$logins', success: !rejectLogin));
      } else if (headers['authorization'] != 'Bearer jwt-$logins') {
        res.statusCode = 401;
      } else if (expireNextSearches > 0) {
        expireNextSearches--;
        res.statusCode = 401;
      } else {
        final target = (body as Map)['SearchTarget'] as String;
        final rows = path == 'member/searchwithenrolleenumber'
            ? byId[target]
            : byName[target];
        res.write(jsonEncode(rows ?? []));
      }
      await res.close();
    });
  }

  Future<void> stop() => server.close(force: true);
}

void main() {
  late _FakeHygeia api;
  late HygeiaClient client;
  const creds = HmoCredentials('user', 'pass');

  setUp(() async {
    api = _FakeHygeia();
    await api.start();
    client = HygeiaClient(base: api.base, clock: () => _today);
    HmoRegistry.clearSessions();
  });

  tearDown(() async {
    HmoRegistry.clients['hygeia'] = HygeiaClient();
    HmoRegistry.clearSessions();
    await api.stop();
  });

  test('registry has Hygeia', () {
    expect(HmoRegistry.clients.containsKey('hygeia'), isTrue);
  });

  test('token is parsed twice', () {
    expect(
      HygeiaClient.accessTokenFrom(jsonEncode({'access_token': 'abc'})),
      'abc',
    );
    expect(HygeiaClient.accessTokenFrom({'access_token': 'abc'}), 'abc');
    expect(HygeiaClient.accessTokenFrom(null), isNull);
    expect(HygeiaClient.accessTokenFrom('not json'), isNull);
  });

  test('ID vs name detection', () {
    expect(HygeiaClient.looksLikeId('1234567/0'), isTrue);
    expect(HygeiaClient.looksLikeId('1234567'), isTrue);
    expect(HygeiaClient.looksLikeId(' 1234567 / 2 '), isTrue);
    expect(HygeiaClient.looksLikeId('Ada Obi'), isFalse);
    expect(HygeiaClient.looksLikeId('AB1234'), isFalse);
    expect(HygeiaClient.normaliseId(' 1234567 / 2 '), '1234567/2');
  });

  test('row mapping: eligible principal, no phone shown', () {
    final m = HygeiaClient.rowToMember(
      _row(first: 'ADA', other: '&nbsp;', last: 'OBI'),
      _today,
    );
    expect(m.hmo, 'hygeia');
    expect(m.memberId, '1234567/0');
    expect(m.name, 'Ada Obi');
    expect(m.relationship, 'Principal');
    expect(m.dateOfBirth, '13/05/1990');
    expect(m.status, 'eligible');
    expect(m.coverEnds, '31/12/2026');
    expect(m.plan, isNull);
    expect(m.notes, 'Provider: ROAMING');
    expect('${m.name}${m.notes}', isNot(contains('08000000000')));
  });

  test('row mapping: not eligible reasons', () {
    HmoMember map(Map<String, dynamic> r) =>
        HygeiaClient.rowToMember(r, _today);
    expect(map(_row(dep: 2)).relationship, 'Dependant 2');
    expect(map(_row(dep: 2)).memberId, '1234567/2');

    final term = map(_row(isterminated: true));
    expect(term.status, 'not eligible');
    expect(term.notes, startsWith('Member terminated'));

    expect(
      map(_row(memberTerminated: 1)).notes,
      startsWith('Member terminated'),
    );
    expect(map(_row(groupTerminated: 1)).notes, startsWith('Group'));

    final ended = map(_row(termination: '2026-10-31T00:00:00'));
    expect(ended.status, 'not eligible');
    expect(ended.notes, startsWith('Cover ended 31/10/2026'));
    expect(ended.coverEnds, '31/10/2026');

    final future = map(_row(effective: '2027-01-01T00:00:00'));
    expect(future.status, 'not eligible');
    expect(future.notes, contains('not yet started'));

    // Last day of cover still counts.
    expect(map(_row(termination: '2026-11-25T00:00:00')).status, 'eligible');
  });

  test(
    'login sends JSON creds and headers; search sends Bearer token',
    () async {
      api.byId['1234567/0'] = [_row()];
      final session = await client.login(creds);
      final r = await client.search(session, '1234567/0');
      expect(r.records.single.status, 'eligible');

      final login = api.requests.first;
      expect(login.path, 'providerlogin');
      expect(login.body, {'UserName': 'user', 'Password': 'pass'});
      expect(login.headers['content-type'], startsWith('application/json'));
      expect(login.headers['origin'], 'https://online.hygeiahmo.com');

      final search = api.requests.last;
      expect(search.path, 'member/searchwithenrolleenumber');
      expect(search.body, {'SearchTarget': '1234567/0'});
      expect(search.headers['authorization'], 'Bearer jwt-1');
      expect(search.headers['accept'], 'application/json, text/plain, */*');
    },
  );

  test('ID without /n retries with /0 when nothing found', () async {
    api.byId['1234567/0'] = [_row(), _row(dep: 1, first: 'EMEKA')];
    final session = await client.login(creds);
    final r = await client.search(session, '1234567');
    expect(r.records.length, 2);
    final targets = [
      for (final q in api.requests.skip(1)) (q.body as Map)['SearchTarget'],
    ];
    expect(targets, ['1234567', '1234567/0']);
  });

  test('ID found as typed does not retry', () async {
    api.byId['1234567'] = [_row()];
    final session = await client.login(creds);
    await client.search(session, '1234567');
    expect(api.requests.length, 2);
  });

  test('name search posts the name; short names are refused', () async {
    api.byName['Ada Obi'] = [_row()];
    final session = await client.login(creds);
    final r = await client.search(session, '  Ada   Obi ');
    expect(r.records.single.name, 'Ada Obi');
    expect(api.requests.last.path, 'member/searchwithname');
    expect(() => client.search(session, 'Al'), throwsA(isA<HmoPortalError>()));
  });

  test('no match returns an empty list', () async {
    final session = await client.login(creds);
    expect((await client.search(session, 'Nobody Here')).records, isEmpty);
  });

  test('success false is a login error with the portal message', () async {
    api.rejectLogin = true;
    await expectLater(
      client.login(creds),
      throwsA(
        isA<HmoLoginFailed>().having(
          (e) => e.detail,
          'detail',
          'Invalid username or password',
        ),
      ),
    );
  });

  test('401 is session expired; registry logs in again once', () async {
    api.byId['1234567/0'] = [_row()];
    HmoRegistry.clients['hygeia'] = client;
    final first = await HmoRegistry.lookup(
      'hygeia',
      '1234567/0',
      credentials: creds,
    );
    expect(first.records, hasLength(1));
    expect(api.logins, 1);

    // Cached login is reused.
    await HmoRegistry.lookup('hygeia', '1234567/0', credentials: creds);
    expect(api.logins, 1);

    // Portal starts answering 401: one re-login, then success.
    api.expireNextSearches = 1;
    final again = await HmoRegistry.lookup(
      'hygeia',
      '1234567/0',
      credentials: creds,
    );
    expect(again.records, hasLength(1));
    expect(api.logins, 2);
  });

  test('search with a bad token throws HmoSessionExpired', () async {
    final session = await client.login(creds);
    api.logins++; // server now expects a different token
    await expectLater(
      client.search(session, '1234567/0'),
      throwsA(isA<HmoSessionExpired>()),
    );
  });
}
