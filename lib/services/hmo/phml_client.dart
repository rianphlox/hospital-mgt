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
///
/// The "New request" page's enrollee search
/// (/hospital/dashboard/request/search/enrollee?enrollee_nhis_no=) returns
/// the whole family, including members registered at other hospitals, with
/// each one's primary hospital code (HCP); /hospital/dashboard/request/search/
/// ?enrolleeHcp= turns the code into a name. PHML shares no phone, email,
/// address or employer with hospitals.
class PhmlClient implements HmoClient {
  static const defaultBase = 'https://erp.phmlnigeria.com';

  final String base;
  PhmlClient({this.base = defaultBase});
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

  /// "PRINCIPAL" -> 0, "SPOUSE" -> 1, "CHILD 2" -> 3 (for ordering).
  static int? dependantNoOf(String type) {
    final t = type.trim().toUpperCase();
    if (t.isEmpty) return null;
    if (t == 'PRINCIPAL') return 0;
    if (t.startsWith('SPOUSE')) return 1;
    final child = RegExp(r'(\d+)').firstMatch(t);
    if (t.startsWith('CHILD')) return 1 + (int.tryParse(child?[1] ?? '') ?? 9);
    return null;
  }

  static String? _sex(Object? v) {
    final s = cleanValue(v);
    if (s == null) return null;
    return switch (s.toUpperCase()) {
      'M' => 'Male',
      'F' => 'Female',
      _ => titleCase(s),
    };
  }

  static HmoMember rowToMember(Map<String, dynamic> row) {
    final nhis = str(row['nhis_no']);
    final type = cleanValue(row['dependant_type']) ?? '';
    return HmoMember(
      hmo: 'phml',
      memberId: nhis,
      name: titleCase(
        [
          row['firstname'],
          row['surname'],
        ].map((v) => cleanValue(v) ?? '').where((s) => s.isNotEmpty).join(' '),
      ),
      sex: _sex(row['sex']),
      dateOfBirth: toDdMmYyyy(row['date_of_birth']),
      relationship: type.isEmpty ? null : titleCase(type),
      status: 'on list',
      familyId: nhis.isEmpty ? null : nhis,
      dependantNo: dependantNoOf(type),
    );
  }

  /// "4/25/1990" (month first, as the request page's enrollee search sends
  /// it) -> "25/04/1990".
  static String? monthFirstToDdMmYyyy(Object? raw) {
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(str(raw));
    if (m == null) return toDdMmYyyy(raw);
    return '${m[2]!.padLeft(2, '0')}/${m[1]!.padLeft(2, '0')}/${m[3]}';
  }

  /// A row from the request page's enrollee search (the whole family, with
  /// the primary hospital's code).
  static HmoMember familyRowToMember(
    Map<String, dynamic> row, {
    String? providerName,
  }) {
    final code = cleanValue(row['primary_hcp']);
    final base = rowToMember({
      ...row,
      'date_of_birth': monthFirstToDdMmYyyy(row['date_of_birth']),
    });
    return base.copyWith(
      primaryProvider: code == null
          ? null
          : (providerName == null ? code : '$providerName ($code)'),
    );
  }

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
    var people = records;
    var familyAdded = false;
    try {
      final ids = <String>{
        for (final m in records) m.memberId,
        if (records.isEmpty && RegExp(r'^\d{4,}$').hasMatch(query.trim()))
          query.trim(),
      }.where((id) => id.isNotEmpty).take(maxFamilyLookups);
      final families = await Future.wait([
        for (final id in ids) _familyRows(s, id),
      ]);
      final codes = <String>{
        for (final f in families)
          for (final r in f)
            if (cleanValue(r['primary_hcp']) != null)
              cleanValue(r['primary_hcp'])!,
      }.take(maxFamilyLookups);
      final names = <String, String?>{
        for (final (i, n) in (await Future.wait([
          for (final c in codes) _providerName(s, c),
        ])).indexed)
          codes.elementAt(i): n,
      };
      people = [...records];
      for (final f in families) {
        for (final r in f) {
          final fm = familyRowToMember(
            r,
            providerName: names[cleanValue(r['primary_hcp'])],
          );
          final i = people.indexWhere(
            (m) =>
                m.memberId == fm.memberId &&
                m.name.toLowerCase() == fm.name.toLowerCase(),
          );
          if (i >= 0) {
            people[i] = people[i].copyWith(primaryProvider: fm.primaryProvider);
          } else {
            people.add(
              fm.copyWith(
                notes: "Not on this hospital's PHML list (family member)",
              ),
            );
            familyAdded = true;
          }
        }
      }
    } on HmoSessionExpired {
      rethrow;
    } catch (_) {
      people = records; // Family details are a bonus; keep the list.
    }
    return HmoSearchResult(
      people,
      total: total != null && total > records.length ? total : null,
      notice: familyAdded ? '$notice $familyNotice' : notice,
    );
  }

  /// Families looked up per search (one call each).
  static const maxFamilyLookups = 5;
  static const familyNotice =
      'Family members registered at another hospital are marked.';

  /// The whole family for one NHIS number, from the "New request" page's
  /// enrollee search. Its `message` is a JSON string: a list of rows, or
  /// "No Enrollee Found!".
  Future<List<Map<String, dynamic>>> _familyRows(
    _PhmlSession s,
    String nhis,
  ) async {
    final r = await s.http.request(
      'GET',
      '$base/hospital/dashboard/request/search/enrollee',
      query: {'_token': s.token, 'enrollee_nhis_no': nhis},
      headers: _ajax,
    );
    if (r.status == 401 || r.status == 419) {
      throw const HmoSessionExpired('PHML');
    }
    final data = tryJson(r.body);
    if (data is! Map) return const [];
    final msg = data['message'];
    final list = msg is String ? tryJson(msg) : msg;
    if (list is! List) return const [];
    return [
      for (final row in list)
        if (row is Map && str(row['nhis_no']) == nhis)
          Map<String, dynamic>.from(row),
    ];
  }

  /// A hospital's name from its HCP code, or null.
  Future<String?> _providerName(_PhmlSession s, String code) async {
    try {
      final r = await s.http.request(
        'GET',
        '$base/hospital/dashboard/request/search/',
        query: {'enrolleeHcp': code, '_token': s.token},
        headers: _ajax,
      );
      final data = tryJson(r.body);
      if (data is! Map) return null;
      final msg = data['message'];
      final name = cleanValue(msg is String ? (tryJson(msg) ?? msg) : msg);
      if (name == null || name.toLowerCase() == 'hcp empty') return null;
      return titleCase(name);
    } catch (_) {
      return null;
    }
  }
}
