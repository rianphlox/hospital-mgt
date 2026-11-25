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
  static const base = 'https://totalhealthtrust.tangerine.africa/portal';

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

  static HmoMember rowToMember(Map<String, dynamic> row) {
    final eligible = str(row['EligibilityStatus']).toUpperCase() == 'ELIGIBLE';
    final name = titleCase(
      [
        row['FirstName'],
        row['OtherName'],
        row['LastName'],
      ].map(str).where((s) => s.isNotEmpty).join(' '),
    );
    final notes = [
      str(row['IneligibilityReason']),
      if (str(row['ProviderName']).isNotEmpty)
        'Provider: ${str(row['ProviderName'])}',
      if (str(row['GroupName']).isNotEmpty) 'Group: ${str(row['GroupName'])}',
    ].where((s) => s.isNotEmpty).toList();
    final legacy = str(row['LegacyCode']);
    return HmoMember(
      hmo: 'tht',
      memberId: legacy.isNotEmpty ? legacy : str(row['InsuredID']),
      name: name,
      sex: orNull(str(row['Gender'])),
      dateOfBirth: toDdMmYyyy(row['DateOfBirth']),
      relationship: orNull(str(row['DependantType'])),
      plan: orNull(str(row['PlanName'])),
      status: eligible ? 'eligible' : 'not eligible',
      coverEnds:
          toDdMmYyyy(row['MemberTermDate']) ?? toDdMmYyyy(row['GroupTermDate']),
      notes: notes.isEmpty ? null : notes.join(' · '),
      photoUrl: photoUrlFrom(row['PixPath']),
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
    final name = titleCase(
      [
        row['FirstName'],
        row['OtherName'],
        row['LastName'],
      ].map(str).where((s) => s.isNotEmpty).join(' '),
    );
    final dep = str(row['DependantID']);
    final terminated = str(row['IsTerminated']).toLowerCase() == 'true';
    return HmoMember(
      hmo: 'tht',
      memberId: str(row['LegacyCode']),
      name: name,
      sex: orNull(str(row['GenderName'])),
      dateOfBirth: toDdMmYyyy(row['dob']),
      relationship: dep.isEmpty
          ? null
          : (dep == '0' ? 'Principal' : 'Dependant $dep'),
      plan: orNull(str(row['PlanName'])),
      status: terminated ? 'not eligible' : 'on list',
      coverEnds: toDdMmYyyy(row['Terminationdate']),
      notes: terminated
          ? 'Terminated on the THT list'
          : 'Search this member ID to check eligibility',
      photoUrl: photoUrlFrom(row['PixPath'] ?? row['pixpath']),
    );
  }

  /// Eligibility is fetched one call per person, so it is capped.
  static const maxEligibilityChecks = 10;

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
        ).then((m) => m ?? searchRowToMember(row)),
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

  @override
  Future<HmoSearchResult> search(Object session, String query) async {
    final s = session as CookieSession;
    final q = query.trim();

    if (looksLikeId(q)) {
      final id = normaliseId(q);
      final rows = await _searchMembers(s, 'IID', id);
      if (rows.isNotEmpty) {
        return HmoSearchResult(await _withEligibility(s, rows));
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
        return HmoSearchResult(
          await _withEligibility(s, matches.take(limit).toList()),
          total: matches.length > limit ? matches.length : null,
          notice: matches.length > maxEligibilityChecks
              ? 'Live eligibility shown for the first $maxEligibilityChecks '
                    'people. Search a member ID to check the others.'
              : null,
        );
      }
    }
    return const HmoSearchResult([]);
  }
}
