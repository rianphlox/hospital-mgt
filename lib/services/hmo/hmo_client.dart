import '../../models/hmo_models.dart';

/// Credentials for one HMO portal.
class HmoCredentials {
  final String user;
  final String password;
  const HmoCredentials(this.user, this.password);

  bool get isComplete => user.isNotEmpty && password.isNotEmpty;
}

/// What one portal search returns.
class HmoSearchResult {
  final List<HmoMember> records;

  /// Total matches on the portal, when larger than [records].
  final int? total;

  /// A short line shown above the results (e.g. what the list means).
  final String? notice;

  const HmoSearchResult(this.records, {this.total, this.notice});
}

/// One client per HMO. [login] returns an opaque logged-in session; [search]
/// runs the lookup with it and throws [HmoSessionExpired] when the portal has
/// logged us out, so the registry can log in again and retry once.
abstract class HmoClient {
  String get id;
  String get label;

  /// What the query box accepts, used in "not found" messages.
  String get queryHint;

  Future<Object> login(HmoCredentials creds);
  Future<HmoSearchResult> search(Object session, String query);
}

/// Wrong username/password, or the portal refused the login.
class HmoLoginFailed implements Exception {
  final String hmo;
  final String? detail;
  const HmoLoginFailed(this.hmo, [this.detail]);
  @override
  String toString() => '$hmo login failed${detail == null ? '' : ': $detail'}';
}

/// The portal answered like a logged-out user.
class HmoSessionExpired implements Exception {
  final String hmo;
  const HmoSessionExpired(this.hmo);
  @override
  String toString() => '$hmo session expired';
}

/// The portal is down or answered with something we cannot read.
class HmoPortalError implements Exception {
  final String message;
  const HmoPortalError(this.message);
  @override
  String toString() => message;
}
