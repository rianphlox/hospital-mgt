import '../../models/hmo_models.dart';
import 'cookie_session.dart';
import 'hmo_client.dart';
import 'hmo_format.dart';

class _HygeiaSession {
  final CookieSession http;
  final String accessToken;
  _HygeiaSession(this.http, this.accessToken);
}

/// Hygeia HMO, on the Medismarts provider API behind online.hygeiahmo.com.
///
/// Login: POST {base}/providerlogin with JSON {UserName, Password}. The
/// `token` field of the answer is itself a JSON string holding
/// {token_type, expires_in, access_token}. Searches are JSON POSTs with a
/// Bearer token: member/searchwithenrolleenumber ("1234567/0") and
/// member/searchwithname. Eligibility is worked out from the termination
/// flags and the member's cover dates.
/// Photos: `member/memberimage/{memberid}` returns the photo URL, which loads
/// with a plain GET.
/// Family: a principal's dependants share the enrollee number ("1234567/1",
/// "1234567/2" ...). They are found by searching the bare number, then by
/// trying "/1".."/6" in parallel (see [_family]). Contact fields other than `phoneno` are read
/// under several likely names because only part of the answer was captured.
///
/// Built from the browser's network log; the API (port 1932) could not be
/// reached from the build machine, so this client is covered by offline
/// tests only.
class HygeiaClient implements HmoClient {
  static const defaultBase = 'https://medismarts.net:1932/hygeiaapiservice/api';
  static const _site = 'https://online.hygeiahmo.com';

  final String base;
  final DateTime Function() _now;

  HygeiaClient({this.base = defaultBase, DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  @override
  String get id => 'hygeia';
  @override
  String get label => 'Hygeia';
  @override
  String get queryHint => 'Hygeia enrollee no. (e.g. 1234567/0) or name';

  static const _jsonHeaders = {
    'Accept': 'application/json, text/plain, */*',
    'Origin': _site,
    'Referer': '$_site/',
  };

  /// Enrollee numbers: digits with an optional "/dependant".
  static bool looksLikeId(String q) =>
      RegExp(r'^\d+(\s*/\s*\d+)?$').hasMatch(q.trim());

  static String normaliseId(String q) => q.replaceAll(RegExp(r'\s+'), '');

  static DateTime? _date(Object? v) {
    final s = str(v);
    if (s.isEmpty) return null;
    final d = DateTime.tryParse(s);
    if (d == null || d.year < 1900) return null;
    return DateTime(d.year, d.month, d.day);
  }

  static bool _flag(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = str(v).toLowerCase();
    return s == 'true' || s == '1';
  }

  /// The family (enrollee) number of a row: `legacycode` without spaces or
  /// a trailing "/n", in case the portal ever puts the dependant number in
  /// it.
  static String familyOf(Map<String, dynamic> row) => str(
    row['legacycode'],
  ).replaceAll(RegExp(r'\s+'), '').replaceFirst(RegExp(r'/\d+$'), '');

  /// 0 for the principal, 1, 2, ... for dependants: `dependantid` ("0",
  /// "01", 1 ...), else the "/n" at the end of `legacycode`.
  static int? dependantNoOf(Map<String, dynamic> row) {
    final d = int.tryParse(str(row['dependantid']));
    if (d != null) return d;
    final m = RegExp(r'/(\d+)$').firstMatch(str(row['legacycode']));
    return m == null ? null : int.parse(m[1]!);
  }

  static String _key(Map<String, dynamic> r) =>
      '${familyOf(r)}/${dependantNoOf(r) ?? ''}';

  static HmoMember rowToMember(
    Map<String, dynamic> row,
    DateTime now, {
    String? photoUrl,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final dep = dependantNoOf(row);
    final legacy = familyOf(row);
    final starts = _date(row['effectivedate']);
    final ends = _date(row['terminationdate']);
    final endsText = toDdMmYyyy(str(row['terminationdate']));

    String? reason;
    if (_flag(row['isterminated']) || _flag(row['memberTerminated'])) {
      reason = 'Member terminated';
    } else if (_flag(row['groupTerminated'])) {
      reason = 'Group (employer) terminated';
    } else if (ends != null && today.isAfter(ends)) {
      reason = 'Cover ended $endsText';
    } else if (starts != null && today.isBefore(starts)) {
      reason =
          'Cover not yet started (starts ${toDdMmYyyy(str(row['effectivedate']))})';
    }

    String? text(List<String> keys) => cleanValue(pick(row, keys));
    final relation = text(['relationship', 'relationshipname', 'membertype']);
    final employer = text([
      'groupname',
      'companyname',
      'company',
      'employer',
      'employername',
      'clientname',
      'organisation',
      'organization',
    ]);
    final plan = text(['planname', 'plan', 'schemename', 'productname']);
    final sex = text(['gender', 'gendername', 'sex']);
    final marital = text(['maritalstatus', 'maritalstatusname']);
    final state = text(['state', 'statename']);
    return HmoMember(
      hmo: 'hygeia',
      memberId: dep == null ? legacy : '$legacy/$dep',
      name: titleCase(
        [
          row['firstname'],
          row['othername'],
          row['lastname'],
        ].map(str).where((s) => s.isNotEmpty).join(' '),
      ),
      sex: sex == null ? null : titleCase(sex),
      dateOfBirth: toDdMmYyyy(str(row['dob'])),
      relationship: relation != null
          ? titleCase(relation)
          : dep == null
          ? null
          : (dep == 0 ? 'Principal' : 'Dependant $dep'),
      plan: plan,
      status: reason == null ? 'eligible' : 'not eligible',
      coverEnds: endsText,
      notes: reason,
      photoUrl: photoUrl,
      familyId: legacy.isEmpty ? null : legacy,
      dependantNo: dep,
      phones: uniqueValues([
        for (final k in const [
          'phoneno',
          'phonenumber',
          'phone',
          'mobile',
          'mobileno',
          'phoneno2',
          'alternatephone',
        ])
          cleanPhone(pick(row, [k])),
      ]),
      emails: uniqueValues([
        for (final k in const ['email', 'emailaddress', 'email1', 'email2'])
          cleanEmail(pick(row, [k])),
      ]),
      address: text([
        'address',
        'homeaddress',
        'residentialaddress',
        'contactaddress',
        'address1',
      ]),
      employer: employer == null ? null : titleCase(employer),
      primaryProvider: text(['providername']),
      coverStarts: toDdMmYyyy(str(row['effectivedate'])),
      extra: {
        if (marital != null) 'Marital status': marital,
        if (state != null) 'State': state,
      },
    );
  }

  /// The login answer's `token` is a JSON string inside the JSON.
  static String? accessTokenFrom(Object? token) {
    Object? t = token;
    if (t is String) t = tryJson(t);
    if (t is Map) {
      final a = str(t['access_token']);
      return a.isEmpty ? null : a;
    }
    return null;
  }

  @override
  Future<Object> login(HmoCredentials creds) async {
    final http = CookieSession();
    final r = await http.request(
      'POST',
      '$base/providerlogin',
      json: {'UserName': creds.user, 'Password': creds.password},
      headers: _jsonHeaders,
    );
    final data = tryJson(r.body);
    if (data is! Map) {
      if (r.status == 401 || r.status == 403) {
        throw const HmoLoginFailed(
          'Hygeia',
          'the portal rejected the username or password',
        );
      }
      throw HmoPortalError(
        'Hygeia portal sent an unreadable login answer (${r.status})',
      );
    }
    if (!_flag(data['success'])) {
      final msg = str(data['message']);
      throw HmoLoginFailed(
        'Hygeia',
        msg.isEmpty ? 'the portal rejected the username or password' : msg,
      );
    }
    final token = accessTokenFrom(data['token']);
    if (token == null) {
      throw const HmoPortalError('Hygeia login answer had no access token');
    }
    return _HygeiaSession(http, token);
  }

  Future<List<Map<String, dynamic>>> _post(
    _HygeiaSession s,
    String path,
    String target,
  ) async {
    final r = await s.http.request(
      'POST',
      '$base/$path',
      json: {'SearchTarget': target},
      headers: {..._jsonHeaders, 'Authorization': 'Bearer ${s.accessToken}'},
    );
    if (r.status == 401 || r.status == 403) {
      throw const HmoSessionExpired('Hygeia');
    }
    if (r.status >= 400) {
      throw HmoPortalError('Hygeia portal error (${r.status})');
    }
    final data = tryJson(r.body);
    if (data is List) {
      return [
        for (final row in data)
          if (row is Map) Map<String, dynamic>.from(row),
      ];
    }
    if (data == null && r.body.trim().isEmpty) return const [];
    throw const HmoPortalError('Hygeia portal sent an unreadable answer');
  }

  /// Photos are one call per person, so only the first few are looked up.
  static const maxPhotoLookups = 10;
  static const _photoTimeout = Duration(seconds: 8);

  /// member/memberimage answers with the photo URL as a JSON string (or
  /// plain text); empty or null when there is no photo. Only http(s) URLs
  /// are accepted.
  static String? photoUrlFromResponse(String body) {
    Object? v = tryJson(body.trim());
    v ??= body;
    if (v is Map) v = v['url'] ?? v['imageUrl'] ?? v['data'];
    var url = str(v);
    while (url.length >= 2 &&
        ((url.startsWith('"') && url.endsWith('"')) ||
            (url.startsWith("'") && url.endsWith("'")))) {
      url = url.substring(1, url.length - 1).trim();
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      return null;
    }
    return url;
  }

  /// The photo URL for one member, or null. Never throws: a missing photo
  /// must not break the search.
  Future<String?> _photoUrl(_HygeiaSession s, Object? memberId) async {
    final id = str(memberId);
    if (!RegExp(r'^\d+$').hasMatch(id)) return null;
    try {
      final r = await s.http
          .request(
            'GET',
            '$base/member/memberimage/$id',
            headers: {
              ..._jsonHeaders,
              'Authorization': 'Bearer ${s.accessToken}',
            },
          )
          .timeout(_photoTimeout);
      if (r.status != 200) return null;
      return photoUrlFromResponse(r.body);
    } catch (_) {
      return null;
    }
  }

  /// Family lookups per search, and dependant numbers tried per family.
  static const maxFamilyLookups = 3;
  static const maxDependantProbes = 10;

  /// Dependant numbers tried at once; if either of the last two is found,
  /// the rest up to [maxDependantProbes] are tried too.
  static const firstProbeBatch = 6;

  /// One enrollee-number search that never throws except for an expired
  /// session: a 400/404/500 or unreadable answer counts as "nobody".
  Future<List<Map<String, dynamic>>> _tryNumber(
    _HygeiaSession s,
    String target,
  ) async {
    try {
      return await _post(s, 'member/searchwithenrolleenumber', target);
    } on HmoSessionExpired {
      rethrow;
    } catch (_) {
      return const [];
    }
  }

  /// Rows of [legacy]'s family not already in [have].
  ///
  /// 1. The bare enrollee number, which may return the whole family.
  /// 2. If that brings nobody new: "legacy/1" .. "legacy/6" in parallel
  ///    (one slow round trip on a phone instead of six), then /7 .. /10 if
  ///    /5 or /6 was found.
  /// 3. If still nobody: "legacy/01" and "legacy/02", in case the portal
  ///    wants zero-padded numbers.
  ///
  /// Each search fails on its own: an error on one number (deleted
  /// dependant, 400 for the bare number) does not stop the others. Only an
  /// expired session is thrown.
  Future<List<Map<String, dynamic>>> _family(
    _HygeiaSession s,
    String legacy,
    Set<String> have, {
    bool skipBare = false,
  }) async {
    final found = <Map<String, dynamic>>[];
    void add(List<Map<String, dynamic>> rows) {
      for (final r in rows) {
        if (familyOf(r) == legacy && have.add(_key(r))) found.add(r);
      }
    }

    Future<Set<int>> probe(Iterable<String> suffixes) async {
      final targets = [
        for (final x in suffixes)
          if (!have.contains('$legacy/${int.parse(x)}')) x,
      ];
      final answers = await Future.wait([
        for (final x in targets) _tryNumber(s, '$legacy/$x'),
      ]);
      final hits = <int>{};
      for (final (i, rows) in answers.indexed) {
        final before = found.length;
        add(rows);
        if (found.length > before || rows.any((r) => familyOf(r) == legacy)) {
          hits.add(int.parse(targets[i]));
        }
      }
      return hits;
    }

    if (!skipBare) {
      add(await _tryNumber(s, legacy));
      if (found.isNotEmpty) return found;
    }
    final hits = await probe([for (var d = 1; d <= firstProbeBatch; d++) '$d']);
    if (hits.contains(firstProbeBatch) || hits.contains(firstProbeBatch - 1)) {
      await probe([
        for (var d = firstProbeBatch + 1; d <= maxDependantProbes; d++) '$d',
      ]);
    }
    if (found.isEmpty) await probe(['01', '02']);
    return found;
  }

  @override
  Future<HmoSearchResult> search(Object session, String query) async {
    final s = session as _HygeiaSession;
    final q = query.trim();
    final now = _now();
    List<Map<String, dynamic>> rows;
    String? searchedBare;

    if (looksLikeId(q)) {
      final id = normaliseId(q);
      // A bare number may be refused (400) where "/0" works, so only the
      // "/0" retry reports portal errors.
      rows = id.contains('/')
          ? await _post(s, 'member/searchwithenrolleenumber', id)
          : await _tryNumber(s, id);
      if (!id.contains('/')) searchedBare = id;
      if (rows.isEmpty && !id.contains('/')) {
        rows = await _post(s, 'member/searchwithenrolleenumber', '$id/0');
      }
    } else {
      final letters = q.replaceAll(RegExp(r'[^A-Za-z]'), '');
      if (letters.length < 3) {
        throw const HmoPortalError(
          'type at least 3 letters of the name, or the enrollee number.',
        );
      }
      rows = await _post(
        s,
        'member/searchwithname',
        q.replaceAll(RegExp(r'\s+'), ' '),
      );
    }

    // Principals: look up the rest of the family, unless the portal already
    // returned more than one person for that enrollee number.
    final have = {for (final r in rows) _key(r)};
    final perFamily = <String, int>{};
    for (final r in rows) {
      final l = familyOf(r);
      perFamily[l] = (perFamily[l] ?? 0) + 1;
    }
    final principals = <String>{
      for (final r in rows)
        if (dependantNoOf(r) == 0 &&
            familyOf(r).isNotEmpty &&
            !(looksLikeId(q) && perFamily[familyOf(r)]! > 1))
          familyOf(r),
    }.take(maxFamilyLookups);
    final families = await Future.wait([
      for (final l in principals)
        _family(s, l, have, skipBare: l == searchedBare),
    ]);
    rows = [...rows, for (final f in families) ...f];

    final photos = await Future.wait([
      for (final (i, r) in rows.indexed)
        i < maxPhotoLookups ? _photoUrl(s, r['memberid']) : Future.value(null),
    ]);
    return HmoSearchResult([
      for (final (i, r) in rows.indexed)
        rowToMember(r, now, photoUrl: photos[i]),
    ]);
  }
}
