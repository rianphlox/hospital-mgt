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
  String get queryHint => 'THT enrollee ID, e.g. AF1234567890_1';

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

  @override
  Future<HmoSearchResult> search(Object session, String query) async {
    final s = session as CookieSession;
    final r = await s.request(
      'GET',
      '$base/api/AccountLogin/GetEligibilityIID',
      query: {'iid': query},
      headers: {'Accept': 'application/json'},
    );
    if (r.status == 401 || r.status == 403 || r.redirects.isNotEmpty) {
      throw const HmoSessionExpired('THT');
    }
    if (r.status >= 400) throw HmoPortalError('THT portal error (${r.status})');
    final data = tryJson(r.body);
    if (data == null) {
      // An HTML page instead of JSON means we were bounced to the login page.
      if (RegExp(r'<html', caseSensitive: false).hasMatch(r.body)) {
        throw const HmoSessionExpired('THT');
      }
      throw const HmoPortalError('THT portal sent an unreadable answer');
    }
    final rows = data is List
        ? data
        : data is Map
        ? [data]
        : const [];
    final records = [
      for (final row in rows)
        if (row is Map &&
            (str(row['FirstName']).isNotEmpty ||
                str(row['LastName']).isNotEmpty ||
                str(row['LegacyCode']).isNotEmpty))
          rowToMember(Map<String, dynamic>.from(row)),
    ];
    return HmoSearchResult(records);
  }
}
