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
/// trying each "/n" in turn. Contact fields other than `phoneno` are read
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

  static HmoMember rowToMember(
    Map<String, dynamic> row,
    DateTime now, {
    String? photoUrl,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final dep = int.tryParse(str(row['dependantid']));
    final legacy = str(row['legacycode']);
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

  /// Rows of [legacy]'s family not already in [have]. First the bare
  /// enrollee number (which may return the whole family); if that brings
  /// nobody new, tries "legacy/1", "legacy/2", ... one at a time and stops
  /// after two misses in a row. Never throws except for an expired session.
  Future<List<Map<String, dynamic>>> _family(
    _HygeiaSession s,
    String legacy,
    Set<String> have, {
    bool skipBare = false,
  }) async {
    String key(Map<String, dynamic> r) =>
        '${str(r['legacycode'])}/${str(r['dependantid'])}';
    bool ours(Map<String, dynamic> r) => str(r['legacycode']) == legacy;
    final found = <Map<String, dynamic>>[];
    void add(List<Map<String, dynamic>> rows) {
      for (final r in rows) {
        if (ours(r) && have.add(key(r))) found.add(r);
      }
    }

    try {
      if (!skipBare) {
        add(await _post(s, 'member/searchwithenrolleenumber', legacy));
        if (found.isNotEmpty) return found;
      }
      var misses = 0;
      for (var dep = 1; dep <= maxDependantProbes && misses < 2; dep++) {
        if (have.contains('$legacy/$dep')) {
          misses = 0;
          continue;
        }
        final rows = await _post(
          s,
          'member/searchwithenrolleenumber',
          '$legacy/$dep',
        );
        final before = found.length;
        add(rows);
        misses = found.length > before ? 0 : misses + 1;
      }
    } on HmoSessionExpired {
      rethrow;
    } catch (_) {
      // A failed family lookup must not hide the people already found.
    }
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
      rows = await _post(s, 'member/searchwithenrolleenumber', id);
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
    final have = {
      for (final r in rows) '${str(r['legacycode'])}/${str(r['dependantid'])}',
    };
    final perFamily = <String, int>{};
    for (final r in rows) {
      final l = str(r['legacycode']);
      perFamily[l] = (perFamily[l] ?? 0) + 1;
    }
    final principals = <String>{
      for (final r in rows)
        if (str(r['dependantid']) == '0' &&
            str(r['legacycode']).isNotEmpty &&
            !(looksLikeId(q) && perFamily[str(r['legacycode'])]! > 1))
          str(r['legacycode']),
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
