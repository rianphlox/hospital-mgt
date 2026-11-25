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

    final provider = str(row['providername']);
    final notes = [
      ?reason,
      if (provider.isNotEmpty) 'Provider: ${cleanText(provider)}',
    ];
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
      dateOfBirth: toDdMmYyyy(str(row['dob'])),
      relationship: dep == null
          ? null
          : (dep == 0 ? 'Principal' : 'Dependant $dep'),
      status: reason == null ? 'eligible' : 'not eligible',
      coverEnds: endsText,
      notes: notes.isEmpty ? null : notes.join(' · '),
      photoUrl: photoUrl,
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

  @override
  Future<HmoSearchResult> search(Object session, String query) async {
    final s = session as _HygeiaSession;
    final q = query.trim();
    final now = _now();
    List<Map<String, dynamic>> rows;

    if (looksLikeId(q)) {
      final id = normaliseId(q);
      rows = await _post(s, 'member/searchwithenrolleenumber', id);
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
