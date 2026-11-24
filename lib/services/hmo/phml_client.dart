import '../../models/hmo_models.dart';
import 'cookie_session.dart';
import 'hmo_client.dart';
import 'hmo_format.dart';

class _PhmlSession {
  final CookieSession http;
  final String token;
  _PhmlSession(this.http, this.token);
}

/// PHML, on its Laravel provider ERP.
///
/// Login: GET /hospital/auth for a fresh CSRF `_token`, then an AJAX POST to
/// /hospital/login that answers {status, message}. The search is the
/// DataTables feed behind the "Enrollees" page: the lives assigned to this
/// hospital, searchable by NHIS number or name. It does NOT say whether cover
/// is active, so rows come back as "on list". A family (principal, spouse,
/// children) shares one NHIS number.
class PhmlClient implements HmoClient {
  static const base = 'https://erp.phmlnigeria.com';
  static const _limit = 50;
  static const _cols = [
    'nhis_no',
    'firstname',
    'surname',
    'sex',
    'date_of_birth',
    'dependant_type',
  ];
  static const notice =
      "PHML enrollees assigned to this hospital. PHML's "
      'list does not show whether cover is active.';

  @override
  String get id => 'phml';
  @override
  String get label => 'PHML';
  @override
  String get queryHint => 'NHIS number or name';

  static HmoMember rowToMember(Map<String, dynamic> row) => HmoMember(
    hmo: 'phml',
    memberId: str(row['nhis_no']),
    name: titleCase(
      [
        row['firstname'],
        row['surname'],
      ].map(str).where((s) => s.isNotEmpty).join(' '),
    ),
    sex: orNull(str(row['sex'])),
    dateOfBirth: toDdMmYyyy(row['date_of_birth']),
    relationship: orNull(str(row['dependant_type'])),
    status: 'on list',
  );

  static Map<String, String> datatablesQuery(String text) {
    final p = <String, String>{
      'draw': '1',
      'start': '0',
      'length': '$_limit',
      'search[value]': text,
      'search[regex]': 'false',
      'order[0][column]': '2',
      'order[0][dir]': 'asc',
    };
    for (var i = 0; i < _cols.length; i++) {
      final c = _cols[i];
      p['columns[$i][data]'] = c;
      p['columns[$i][name]'] = c;
      p['columns[$i][searchable]'] = 'true';
      p['columns[$i][orderable]'] = 'true';
      p['columns[$i][search][value]'] = '';
      p['columns[$i][search][regex]'] = 'false';
    }
    return p;
  }

  static const _ajax = {
    'X-Requested-With': 'XMLHttpRequest',
    'Accept': 'application/json',
  };

  @override
  Future<Object> login(HmoCredentials creds) async {
    final http = CookieSession();
    final page = await http.request('GET', '$base/hospital/auth');
    if (page.status >= 400) {
      throw HmoPortalError(
        'PHML portal error (${page.status}) on the login page',
      );
    }
    final token = RegExp(
      r'name="_token"\s+value="([^"]+)"',
    ).firstMatch(page.body)?.group(1);
    if (token == null) {
      throw const HmoPortalError(
        'PHML login page changed: no _token field found',
      );
    }
    final r = await http.request(
      'POST',
      '$base/hospital/login',
      form: {'_token': token, 'email': creds.user, 'password': creds.password},
      headers: _ajax,
    );
    final data = tryJson(r.body);
    if (data is! Map) {
      throw HmoPortalError(
        'PHML portal sent an unreadable login answer (${r.status})',
      );
    }
    final ok = data['status'];
    if (ok == null || ok == false || ok == 0 || ok == '') {
      final msg = str(data['message']);
      throw HmoLoginFailed(
        'PHML',
        msg.isEmpty ? 'the portal rejected the email or password' : msg,
      );
    }
    return _PhmlSession(http, token);
  }

  @override
  Future<HmoSearchResult> search(Object session, String query) async {
    final s = session as _PhmlSession;
    final r = await s.http.request(
      'GET',
      '$base/hospital/dashboard/enrollees/datatables',
      query: {
        ...datatablesQuery(query),
        '_': '${DateTime.now().millisecondsSinceEpoch}',
      },
      headers: {..._ajax, 'X-CSRF-TOKEN': s.token},
    );
    if (r.status == 401 || r.status == 419 || r.redirects.isNotEmpty) {
      throw const HmoSessionExpired('PHML');
    }
    if (r.status >= 400) {
      throw HmoPortalError('PHML portal error (${r.status})');
    }
    final data = tryJson(r.body);
    if (data is! Map || data['data'] is! List) {
      if (RegExp(r'<html', caseSensitive: false).hasMatch(r.body)) {
        throw const HmoSessionExpired('PHML');
      }
      throw const HmoPortalError('PHML portal sent an unreadable answer');
    }
    final records = [
      for (final row in data['data'] as List)
        if (row is Map) rowToMember(Map<String, dynamic>.from(row)),
    ];
    final total = int.tryParse(str(data['recordsFiltered']));
    return HmoSearchResult(
      records,
      total: total != null && total > records.length ? total : null,
      notice: notice,
    );
  }
}
