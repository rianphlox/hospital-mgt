import '../../models/hmo_models.dart';
import 'cookie_session.dart';
import 'hmo_client.dart';
import 'hmo_format.dart';

/// Total Health Trust (THT), on the Tangerine "Medicloud" provider portal.
///
/// Login is a plain form POST to /portal/Main/Login; the portal then keeps us
/// signed in with the ASP.NET_SessionId cookie. A failed login sends the
/// login form back. Eligibility is a JSON GET by enrollee ID.
class ThtClient implements HmoClient {
  static const defaultBase =
      'https://totalhealthtrust.tangerine.africa/portal';

  final String base;
  ThtClient({this.base = defaultBase});

  @override
  String get id => 'tht';
  @override
  String get label => 'THT';
  @override
  String get queryHint =>
      'THT enrollee ID (e.g. AF1234567890_1 or 1110000000-01) or name';

  /// Where the THT portal loads member photos from (a different server from
  /// the portal; no session cookie needed).
  static const photoBase =
      'https://medismarts.net:1913/medicloud/uploads/enrolment-uploads/pictures/';

  /// PixPath looks like `X:\\pictures\\<file>.jpg`; the portal keeps only the
  /// file name (the folder is sometimes "Pictures").
  static String? photoUrlFrom(Object? pixPath) {
    final p = str(pixPath);
    if (p.isEmpty) return null;
    final file = p.split(RegExp(r'[\\/]')).last.trim();
    if (file.isEmpty) return null;
    return '$photoBase${Uri.encodeComponent(file)}';
  }

  /// The family part of a THT ID: "1110000000-01" -> "1110000000",
  /// "AF1234567890_1" -> "AF1234567890". The principal's ID often has no
  /// suffix at all.
  static String familyIdOf(String legacyCode) =>
      legacyCode.trim().toUpperCase().replaceFirst(RegExp(r'[-_/]\d+$'), '');

  static int? _int(Object? v) => v is num ? v.toInt() : int.tryParse(str(v));

  static String _relationship(int? dep, Object? dependantType) {
    final t = cleanValue(dependantType);
    if (t != null) return titleCase(t);
    if (dep == null) return '';
    return dep == 0 ? 'Principal' : 'Dependant $dep';
  }

  /// Contact, employer and cover details found in both SearchMembers and
  /// GetEligibilityIID rows. Filler ("None", "N/A", "HOUSE",
  /// test@gmail.com) is dropped.
  static HmoMember _member(
    Map<String, dynamic> row, {
    required String status,
    String? sex,
    String? dateOfBirth,
    String? coverEnds,
    String? notes,
  }) {
    final legacy = str(row['LegacyCode']);
    final id = legacy.isNotEmpty ? legacy : str(row['InsuredID']);
    final dep = _int(row['DependantID']);
    final division = cleanValue(row['DivisionName']);
    final group = cleanValue(row['GroupName']);
    final marital = cleanValue(row['MaritalStatusName']);
    final altCode = cleanValue(row['AlternateCode']);
    return HmoMember(
      hmo: 'tht',
      memberId: id,
      name: titleCase(
        [
          row['FirstName'],
          row['OtherName'],
          row['LastName'],
        ].map((v) => cleanValue(v) ?? '').where((s) => s.isNotEmpty).join(' '),
      ),
      sex: sex,
      dateOfBirth: dateOfBirth,
      relationship: orNull(_relationship(dep, row['DependantType'])),
      plan: cleanValue(row['PlanName']),
      status: status,
      coverEnds: coverEnds,
      notes: notes,
      photoUrl: photoUrlFrom(row['PixPath'] ?? row['pixpath']),
      familyId: id.isEmpty ? null : familyIdOf(id),
      dependantNo: dep,
      phones: uniqueValues([
        cleanPhone(row['Phone1']),
        cleanPhone(row['Phone2']),
      ]),
      emails: uniqueValues([
        cleanEmail(row['Email1']),
        cleanEmail(row['Email2']),
      ]),
      address: cleanValue(row['Address1']),
      employer: group == null ? null : titleCase(group),
      primaryProvider: cleanValue(row['ProviderName']),
      coverStarts: toDdMmYyyy(row['MemberEffDate']),
      extra: {
        if (division != null && division.toUpperCase() != group?.toUpperCase())
          'Division': titleCase(division),
        if (marital != null) 'Marital status': marital,
        if (altCode != null) 'Other ID': altCode,
      },
    );
  }

  /// A GetEligibilityIID row (live eligibility).
  static HmoMember rowToMember(Map<String, dynamic> row) {
    final eligible = str(row['EligibilityStatus']).toUpperCase() == 'ELIGIBLE';
    return _member(
      row,
      status: eligible ? 'eligible' : 'not eligible',
      sex: cleanValue(row['Gender']) ?? cleanValue(row['GenderName']),
      dateOfBirth: toDdMmYyyy(row['DateOfBirth']) ?? toDdMmYyyy(row['dob']),
      coverEnds:
          toDdMmYyyy(row['MemberTermDate']) ?? toDdMmYyyy(row['GroupTermDate']),
      notes: cleanValue(row['IneligibilityReason']),
    );
  }

  @override
  Future<Object> login(HmoCredentials creds) async {
    final s = CookieSession();
    await s.request('GET', '$base/');
    final r = await s.request(
      'POST',
      '$base/Main/Login',
      form: {'loginUser': creds.user, 'loginPassword': creds.password},
    );
    if (r.status >= 500) {
      throw HmoPortalError('THT portal error (${r.status}) during login');
    }
    if (r.body.contains('id="loginForm"')) {
      throw const HmoLoginFailed(
        'THT',
        'the portal rejected the username or password',
      );
    }
    return s;
  }

  /// Turns a SearchMembers row (no eligibility fields) into a member with
  /// status "on list". Used when the eligibility call gives nothing back, and
  /// for name matches beyond [maxEligibilityChecks].
  static HmoMember searchRowToMember(Map<String, dynamic> row) {
    final terminated = str(row['IsTerminated']).toLowerCase() == 'true';
    return _member(
      row,
      status: terminated ? 'not eligible' : 'on list',
      sex: cleanValue(row['GenderName']) ?? cleanValue(row['Gender']),
      dateOfBirth: toDdMmYyyy(row['dob']) ?? toDdMmYyyy(row['DateOfBirth']),
      coverEnds: toDdMmYyyy(row['Terminationdate']),
      notes: terminated
          ? 'Terminated on the THT list'
          : 'Search this member ID to check eligibility',
    );
  }

  /// Eligibility is fetched one call per person, so it is capped.
  static const maxEligibilityChecks = 12;

  /// Families looked up per search (one SearchMembers call each).
  static const maxFamilyLookups = 5;

  /// THT IDs: legacy "AF1234567890_1" or "1110000000-03"; a bare family
  /// number like "1110000000" returns the whole family. Anything with a
  /// digit and no spaces is treated as an ID; everything else as a name.
  static bool looksLikeId(String q) =>
      RegExp(r'\d').hasMatch(q) && !RegExp(r'\s').hasMatch(q.trim());

  /// "1110000000/03" (as some cards print it) -> "1110000000-03".
  static String normaliseId(String q) {
    final t = q.trim().toUpperCase();
    final m = RegExp(r'^(\d+)/(\d+)$').firstMatch(t);
    return m == null ? t : '${m[1]}-${m[2]}';
  }

  Future<Object?> _getJson(
    CookieSession s,
    String path,
    Map<String, String> query,
  ) async {
    final r = await s.request(
      'GET',
      '$base/$path',
      query: query,
      headers: {'Accept': 'application/json'},
    );
    if (r.status == 401 || r.status == 403 || r.redirects.isNotEmpty) {
      throw const HmoSessionExpired('THT');
    }
    final data = tryJson(r.body);
    if (data == null) {
      // An HTML page instead of JSON means we were bounced to the login page.
      if (RegExp(r'<html', caseSensitive: false).hasMatch(r.body)) {
        throw const HmoSessionExpired('THT');
      }
      throw HmoPortalError(
        'THT portal sent an unreadable answer (${r.status})',
      );
    }
    if (r.status >= 400 && data is! Map) {
      throw HmoPortalError('THT portal error (${r.status})');
    }
    return data;
  }

  /// SearchMembers, as used by the portal's "Enrollee No / Last Name" search.
  /// `option` is "IID" or "lastname" (lastname is a contains-match across all
  /// THT members). Rows without a LegacyCode are empty placeholders.
  Future<List<Map<String, dynamic>>> _searchMembers(
    CookieSession s,
    String option,
    String value,
  ) async {
    final data = await _getJson(s, 'api/AccountLogin/SearchMembers', {
      'option': option,
      'value': value,
    });
    if (data is! List) {
      // The portal answers huge searches with a .NET error object.
      throw const HmoPortalError(
        'too many THT members match. Type more of the name.',
      );
    }
    return [
      for (final row in data)
        if (row is Map && str(row['LegacyCode']).isNotEmpty)
          Map<String, dynamic>.from(row),
    ];
  }

  /// Live eligibility for one enrollee ID, or null if THT has no record.
  Future<HmoMember?> _eligibility(CookieSession s, String iid) async {
    final data = await _getJson(s, 'api/AccountLogin/GetEligibilityIID', {
      'iid': iid,
    });
    final rows = data is List
        ? data
        : data is Map
        ? [data]
        : const [];
    for (final row in rows) {
      if (row is Map &&
          str(row['EligibilityStatus']).isNotEmpty &&
          (str(row['FirstName']).isNotEmpty ||
              str(row['LastName']).isNotEmpty)) {
        return rowToMember(Map<String, dynamic>.from(row));
      }
    }
    return null;
  }

  /// Adds live eligibility to the first [maxEligibilityChecks] rows.
  Future<List<HmoMember>> _withEligibility(
    CookieSession s,
    List<Map<String, dynamic>> rows,
  ) async {
    final checked = await Future.wait([
      for (final row in rows.take(maxEligibilityChecks))
        _eligibility(
          s,
          str(row['LegacyCode']),
        ).then((m) => m ?? searchRowToMember(row)).catchError((Object e) {
          if (e is HmoSessionExpired) throw e;
          return searchRowToMember(row);
        }),
    ]);
    return [
      ...checked,
      for (final row in rows.skip(maxEligibilityChecks)) searchRowToMember(row),
    ];
  }

  static String _fullName(Map<String, dynamic> row) => [
    row['FirstName'],
    row['OtherName'],
    row['LastName'],
  ].map((v) => cleanText(str(v))).join(' ').toUpperCase();

  /// Adds the rest of each family to [rows]: one SearchMembers call per
  /// family (the portal's IID search is a contains-match, so a family ID
  /// returns the principal and every dependant; rows from other families
  /// that merely contain the digits are dropped). Never throws on a family
  /// lookup error other than an expired session; the matches still show.
  Future<List<Map<String, dynamic>>> _withFamilies(
    CookieSession s,
    List<Map<String, dynamic>> rows, {
    String? alreadySearched,
  }) async {
    final seen = {for (final r in rows) str(r['LegacyCode']).toUpperCase()};
    final families = <String>[];
    for (final r in rows) {
      final f = familyIdOf(str(r['LegacyCode']));
      if (f.isEmpty || families.contains(f) || f == alreadySearched) continue;
      families.add(f);
    }
    final found = await Future.wait([
      for (final f in families.take(maxFamilyLookups))
        _searchMembers(s, 'IID', f)
            .then(
              (list) => [
                for (final r in list)
                  if (familyIdOf(str(r['LegacyCode'])) == f) r,
              ],
            )
            .catchError((Object e) {
              if (e is HmoSessionExpired) throw e;
              return <Map<String, dynamic>>[];
            }),
    ]);
    final extra = <Map<String, dynamic>>[];
    for (final list in found) {
      for (final r in list) {
        if (seen.add(str(r['LegacyCode']).toUpperCase())) extra.add(r);
      }
    }
    return [...rows, ...extra];
  }

  HmoSearchResult _result(List<HmoMember> people, {int? total}) =>
      HmoSearchResult(
        people,
        total: total,
        notice: people.length > maxEligibilityChecks
            ? 'Live eligibility shown for the first $maxEligibilityChecks '
                  'people. Search a member ID to check the others.'
            : null,
      );

  @override
  Future<HmoSearchResult> search(Object session, String query) async {
    final s = session as CookieSession;
    final q = query.trim();

    if (looksLikeId(q)) {
      final id = normaliseId(q);
      final rows = await _searchMembers(s, 'IID', id);
      if (rows.isNotEmpty) {
        // Keep only this family's rows when the contains-match also hit
        // other IDs, then add any family members not returned yet.
        final exact = [
          for (final r in rows)
            if (str(r['LegacyCode']).toUpperCase() == id ||
                familyIdOf(str(r['LegacyCode'])) == familyIdOf(id))
              r,
        ];
        final mine = exact.isEmpty ? rows : exact;
        final all = await _withFamilies(
          s,
          mine,
          alreadySearched: familyIdOf(id) == id ? id : null,
        );
        return _result(await _withEligibility(s, all));
      }
      // Fall back to the direct eligibility call (older IDs).
      final m = await _eligibility(s, id);
      return HmoSearchResult(m == null ? const [] : [m]);
    }

    // Name search. The portal only searches last names, so try each word
    // (longest first) as the last name and keep people whose full name has
    // every word typed.
    final words = q
        .toUpperCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3)
        .toSet()
        .toList();
    if (words.isEmpty) {
      throw const HmoPortalError(
        'type at least 3 letters of the surname, or the enrollee ID.',
      );
    }
    words.sort((a, b) => b.length.compareTo(a.length));

    for (final w in words.take(3)) {
      final rows = await _searchMembers(s, 'lastname', w);
      final matches = [
        for (final row in rows)
          if (words.every(_fullName(row).contains)) row,
      ];
      if (matches.isNotEmpty) {
        // Active members first, so the live checks go to likely patients.
        bool terminated(Map<String, dynamic> r) =>
            str(r['IsTerminated']).toLowerCase() == 'true';
        final active = [...matches.where((r) => !terminated(r))];
        matches
          ..removeWhere((r) => !terminated(r))
          ..insertAll(0, active);
        const limit = 50;
        final shown = await _withFamilies(s, matches.take(limit).toList());
        return _result(
          await _withEligibility(s, shown),
          total: matches.length > limit ? matches.length : null,
        );
      }
    }
    return const HmoSearchResult([]);
  }
}
