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
  int memberid = 99,
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
  'memberid': memberid,
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

  /// SearchTargets that answer 500.
  Set<String> failTargets = {};

  /// SearchTargets that answer with this HTTP status (e.g. 400, 404).
  Map<String, int> statusFor = {};

  /// memberid -> raw body of member/memberimage (missing = 404).
  Map<String, String> photos = {};
  Set<String> slowPhotos = {};

  /// Requests other than photo lookups.
  List<({String path, Map<String, String> headers, Object? body})>
  get nonPhoto => [
    for (final q in requests)
      if (!q.path.startsWith('member/memberimage/')) q,
  ];

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
      } else if (path.startsWith('member/memberimage/')) {
        final id = path.split('/').last;
        if (slowPhotos.contains(id)) {
          await Future<void>.delayed(const Duration(seconds: 10));
        }
        if (photos.containsKey(id)) {
          res.write(photos[id]);
        } else {
          res.statusCode = 404;
        }
      } else if (expireNextSearches > 0) {
        expireNextSearches--;
        res.statusCode = 401;
      } else {
        final target = (body as Map)['SearchTarget'] as String;
        if (failTargets.contains(target) || statusFor.containsKey(target)) {
          res.statusCode = statusFor[target] ?? 500;
          await res.close();
          return;
        }
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

  test('row mapping: eligible principal with contact details', () {
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
    expect(m.notes, isNull);
    expect(m.primaryProvider, 'ROAMING');
    expect(m.phones, ['08000000000']);
    expect(m.emails, isEmpty);
    expect(m.familyId, '1234567');
    expect(m.dependantNo, 0);
    expect(m.isPrincipal, isTrue);
    expect(m.coverStarts, '01/01/2026');
    expect(m.hasDetails, isTrue);
  });

  test('row mapping: other contact fields under likely names', () {
    final m = HygeiaClient.rowToMember({
      ..._row(dep: 1),
      'phoneno': 'N/A',
      'mobile': '+234 803 123 4567',
      'EmailAddress': 'Ada.Obi@Example.COM',
      'address': 'Plot 5, Gwagwa&nbsp;Road',
      'groupname': 'ACME NIGERIA LTD',
      'gender': 'FEMALE',
      'relationship': 'SPOUSE',
      'maritalstatus': 'Married',
    }, _today);
    expect(m.phones, ['+2348031234567']);
    expect(m.emails, ['ada.obi@example.com']);
    expect(m.address, 'Plot 5, Gwagwa Road');
    expect(m.employer, 'Acme Nigeria Ltd');
    expect(m.sex, 'Female');
    expect(m.relationship, 'Spouse');
    expect(m.dependantNo, 1);
    expect(m.extra, {'Marital status': 'Married'});

    final filler = HygeiaClient.rowToMember({
      ..._row(),
      'phoneno': '00000000000',
      'email': 'test@gmail.com',
      'address': 'None',
      'providername': '',
    }, _today);
    expect(filler.phones, isEmpty);
    expect(filler.emails, isEmpty);
    expect(filler.address, isNull);
    expect(filler.primaryProvider, isNull);
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

      final search = api.nonPhoto[1];
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
      for (final q in api.nonPhoto.skip(1)) (q.body as Map)['SearchTarget'],
    ];
    expect(targets, ['1234567', '1234567/0']);
  });

  test('ID found as typed does not retry with /0', () async {
    api.byId['1234567'] = [_row()];
    final session = await client.login(creds);
    await client.search(session, '1234567');
    final targets = [
      for (final q in api.nonPhoto.skip(1)) (q.body as Map)['SearchTarget'],
    ];
    expect(targets.first, '1234567');
    expect(targets, isNot(contains('1234567/0')));
  });

  test(
    'principal found by ID: dependants found by trying /1 .. /6 at once',
    () async {
      api.byId['1234567/0'] = [_row(memberid: 1)];
      api.byId['1234567/1'] = [_row(memberid: 2, dep: 1, first: 'EMEKA')];
      api.byId['1234567/2'] = [_row(memberid: 3, dep: 2, first: 'NNEKA')];
      final session = await client.login(creds);
      final r = await client.search(session, '1234567/0');
      expect(r.records.map((m) => m.name), [
        'Ada Obi',
        'Emeka Obi',
        'Nneka Obi',
      ]);
      expect(r.records.map((m) => m.familyId).toSet(), {'1234567'});
      final targets = [
        for (final q in api.nonPhoto.skip(1)) (q.body as Map)['SearchTarget'],
      ];
      // Bare number first, then /1 .. /6 (in parallel, any order). /5 and
      // /6 missed, so /7 .. /10 and the zero-padded fallback are not tried.
      expect(targets.take(2), ['1234567/0', '1234567']);
      expect(targets.skip(2).toSet(), {
        for (var d = 1; d <= 6; d++) '1234567/$d',
      });
      expect(targets, hasLength(8));
    },
  );

  test('bare number returning the family skips the /n probes', () async {
    api.byName['Ada Obi'] = [_row(memberid: 1)];
    api.byId['1234567'] = [
      _row(memberid: 1),
      _row(memberid: 2, dep: 1, first: 'EMEKA'),
    ];
    final session = await client.login(creds);
    final r = await client.search(session, 'Ada Obi');
    expect(r.records.map((m) => m.memberId), ['1234567/0', '1234567/1']);
    final targets = [
      for (final q in api.nonPhoto.skip(1)) (q.body as Map)['SearchTarget'],
    ];
    expect(targets, ['Ada Obi', '1234567']);
  });

  test(
    'an ID search that already returns the family looks up nothing more',
    () async {
      api.byId['1234567/0'] = [_row(), _row(dep: 1, first: 'EMEKA')];
      final session = await client.login(creds);
      final r = await client.search(session, '1234567/0');
      expect(r.records, hasLength(2));
      expect(api.nonPhoto, hasLength(2)); // login + one search
    },
  );

  test('a failing family lookup still returns the people found', () async {
    api.byName['Ada Obi'] = [_row()];
    api.failTargets.add('1234567');
    final session = await client.login(creds);
    final r = await client.search(session, 'Ada Obi');
    expect(r.records.single.name, 'Ada Obi');
  });

  test('name search posts the name; short names are refused', () async {
    api.byName['Ada Obi'] = [_row()];
    final session = await client.login(creds);
    final r = await client.search(session, '  Ada   Obi ');
    expect(r.records.single.name, 'Ada Obi');
    expect(api.nonPhoto[1].path, 'member/searchwithname');
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

  test('memberimage response parsing', () {
    const url = 'https://example.test/uploads/pictures/20200101000000.jpg';
    expect(HygeiaClient.photoUrlFromResponse(jsonEncode(url)), url);
    expect(HygeiaClient.photoUrlFromResponse(url), url);
    expect(HygeiaClient.photoUrlFromResponse('  "$url"  '), url);
    expect(HygeiaClient.photoUrlFromResponse("'$url'"), url);
    expect(HygeiaClient.photoUrlFromResponse(jsonEncode('"$url"')), url);
    expect(
      HygeiaClient.photoUrlFromResponse('http://example.test/a.png'),
      'http://example.test/a.png',
    );
    expect(HygeiaClient.photoUrlFromResponse(''), isNull);
    expect(HygeiaClient.photoUrlFromResponse('null'), isNull);
    expect(HygeiaClient.photoUrlFromResponse('""'), isNull);
    expect(HygeiaClient.photoUrlFromResponse('no photo'), isNull);
    expect(HygeiaClient.photoUrlFromResponse('/uploads/a.jpg'), isNull);
    expect(HygeiaClient.photoUrlFromResponse('javascript:alert(1)'), isNull);
    expect(
      HygeiaClient.photoUrlFromResponse('ftp://example.test/a.jpg'),
      isNull,
    );
  });

  test('search fetches photos with the Bearer token', () async {
    const url = 'https://example.test/uploads/pictures/p1.jpg';
    api.byId['1234567/0'] = [
      _row(memberid: 11),
      _row(memberid: 12, dep: 1),
      _row(memberid: 13, dep: 2),
      _row(memberid: 14, dep: 3),
    ];
    api.photos['11'] = jsonEncode(url); // JSON string
    api.photos['12'] = 'null'; // no photo
    api.photos['13'] = 'not a url';
    // 14: 404
    final session = await client.login(creds);
    final r = await client.search(session, '1234567/0');
    expect(r.records.map((m) => m.photoUrl).toList(), [url, null, null, null]);
    expect(r.records.first.hasPhoto, isTrue);
    final photoReqs = api.requests
        .where((q) => q.path.startsWith('member/memberimage/'))
        .toList();
    expect(photoReqs, hasLength(4));
    expect(
      photoReqs.every((q) => q.headers['authorization'] == 'Bearer jwt-1'),
      isTrue,
    );
  });

  test('photo lookups are capped at the first 10 people', () async {
    api.byName['Ada Obi'] = [
      for (var i = 0; i < 12; i++) _row(memberid: 100 + i, dep: i),
    ];
    for (var i = 0; i < 12; i++) {
      api.photos['${100 + i}'] = jsonEncode('https://example.test/$i.jpg');
    }
    final session = await client.login(creds);
    final r = await client.search(session, 'Ada Obi');
    expect(r.records, hasLength(12));
    expect(r.records.where((m) => m.photoUrl != null), hasLength(10));
    expect(r.records.last.photoUrl, isNull);
    expect(
      api.requests.where((q) => q.path.startsWith('member/memberimage/')),
      hasLength(HygeiaClient.maxPhotoLookups),
    );
  });

  test('a slow or broken photo call does not break the search', () async {
    api.byId['1234567/0'] = [_row(memberid: 21), _row(memberid: 22, dep: 1)];
    api.slowPhotos.add('21');
    api.photos['21'] = jsonEncode('https://example.test/slow.jpg');
    api.photos['22'] = jsonEncode('https://example.test/fast.jpg');
    final session = await client.login(creds);
    final sw = Stopwatch()..start();
    final r = await client.search(session, '1234567/0');
    expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
    expect(r.records.first.photoUrl, isNull);
    expect(r.records.last.photoUrl, 'https://example.test/fast.jpg');
  });

  test('missing or non-numeric memberid skips the photo call', () async {
    final row = _row()..remove('memberid');
    api.byId['1234567/0'] = [row];
    final session = await client.login(creds);
    final r = await client.search(session, '1234567/0');
    expect(r.records.single.photoUrl, isNull);
    expect(
      api.requests.where((q) => q.path.startsWith('member/memberimage/')),
      isEmpty,
    );
  });

  // ---- Family lookups that hit errors (all data made up) ----

  Map<String, List<Map<String, dynamic>>> family(String legacy) => {
    for (final (dep, first) in [
      (1, 'AMINA'),
      (2, 'MUSA'),
      (3, 'HAUWA'),
      (4, 'YUSUF'),
      (5, 'FATIMA'),
    ])
      '$legacy/$dep': [
        _row(memberid: 50 + dep, legacy: legacy, dep: dep, first: first),
      ],
  };

  for (final status in [400, 500]) {
    test('bare number answering $status: /1, /2 ... still found', () async {
      api.byId['7654321/0'] = [_row(memberid: 50, legacy: '7654321')];
      api.byId.addAll(family('7654321'));
      api.statusFor['7654321'] = status;
      final session = await client.login(creds);
      final r = await client.search(session, '7654321/0');
      expect(r.records, hasLength(6));
    });
  }

  test(
    'bare ID search answering 400 falls back to /0, then the family',
    () async {
      api.byId['7654321/0'] = [_row(memberid: 50, legacy: '7654321')];
      api.byId.addAll(family('7654321'));
      api.statusFor['7654321'] = 400;
      final session = await client.login(creds);
      final r = await client.search(session, '7654321');
      expect(r.records, hasLength(6));
    },
  );

  for (final status in [404, 400, 500]) {
    test('dependant slot answering $status does not stop the others', () async {
      api.byId['7654321/0'] = [_row(memberid: 50, legacy: '7654321')];
      api.byId.addAll(family('7654321'));
      api.byId.remove('7654321/2'); // deleted dependant
      api.statusFor['7654321/2'] = status;
      final session = await client.login(creds);
      final r = await client.search(session, '7654321/0');
      expect(r.records.map((m) => m.memberId).toSet(), {
        '7654321/0',
        '7654321/1',
        '7654321/3',
        '7654321/4',
        '7654321/5',
      });
    });
  }

  test('/5 or /6 found: /7 .. /10 are tried too', () async {
    api.byId['7654321/0'] = [_row(memberid: 50, legacy: '7654321')];
    api.byId.addAll(family('7654321'));
    api.byId['7654321/8'] = [
      _row(memberid: 58, legacy: '7654321', dep: 8, first: 'ZAINAB'),
    ];
    final session = await client.login(creds);
    final r = await client.search(session, '7654321/0');
    expect(r.records.map((m) => m.memberId), contains('7654321/8'));
    final targets = [
      for (final q in api.nonPhoto) (q.body as Map?)?['SearchTarget'],
    ];
    expect(targets, contains('7654321/10'));
    expect(targets, isNot(contains('7654321/11')));
  });

  test('zero-padded /01 is tried when /1 .. /6 find nobody', () async {
    api.byId['7654321/0'] = [_row(memberid: 50, legacy: '7654321')];
    api.byId['7654321/01'] = [
      _row(memberid: 51, legacy: '7654321', dep: 1, first: 'AMINA'),
    ];
    final session = await client.login(creds);
    final r = await client.search(session, '7654321/0');
    expect(r.records.map((m) => m.memberId), ['7654321/0', '7654321/1']);
  });

  test('expired session during a family lookup is still reported', () async {
    api.byId['7654321/0'] = [_row(memberid: 50, legacy: '7654321')];
    api.statusFor['7654321/3'] = 401;
    final session = await client.login(creds);
    await expectLater(
      client.search(session, '7654321/0'),
      throwsA(isA<HmoSessionExpired>()),
    );
  });

  test('principal, spouse and 4 children group as one family', () async {
    api.byId['7654321/0'] = [
      _row(memberid: 50, legacy: '7654321', first: 'ABDUL', last: 'SANI'),
    ];
    api.byId.addAll(family('7654321'));
    final session = await client.login(creds);
    final r = await client.search(session, '7654321/0');
    final result = HmoLookupResult(
      hmo: 'hygeia',
      label: 'Hygeia',
      results: r.records,
      total: r.records.length,
    );
    final f = result.families.single;
    expect(f.id, '7654321');
    expect(f.principal!.memberId, '7654321/0');
    expect(f.principal!.relationship, 'Principal');
    expect(f.dependants.map((m) => m.memberId), [
      for (var d = 1; d <= 5; d++) '7654321/$d',
    ]);
    expect(f.dependants.map((m) => m.dependantNo), [1, 2, 3, 4, 5]);
  });

  test('dependant number inside legacycode still groups by family', () {
    final m = HygeiaClient.rowToMember({
      ..._row(legacy: ' 7654321/3 '),
      'dependantid': null,
    }, _today);
    expect(m.familyId, '7654321');
    expect(m.memberId, '7654321/3');
    expect(m.dependantNo, 3);
    expect(
      HygeiaClient.dependantNoOf({
        'legacycode': '7654321',
        'dependantid': '00',
      }),
      0,
    );
  });
}
