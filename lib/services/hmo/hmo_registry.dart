import 'hmo_client.dart';
import 'hygeia_client.dart';
import 'phml_client.dart';
import 'tht_client.dart';

/// HMO credentials, compiled in at build time:
///   flutter build apk --dart-define-from-file=hmo_defines.json
/// with keys THT_USER, THT_PASSWORD, PHML_EMAIL, PHML_PASSWORD,
/// HYGEIA_USER, HYGEIA_PASSWORD.
/// Keep that file outside the repo.
const _thtUser = String.fromEnvironment('THT_USER');
const _thtPassword = String.fromEnvironment('THT_PASSWORD');
const _phmlEmail = String.fromEnvironment('PHML_EMAIL');
const _phmlPassword = String.fromEnvironment('PHML_PASSWORD');
const _hygeiaUser = String.fromEnvironment('HYGEIA_USER');
const _hygeiaPassword = String.fromEnvironment('HYGEIA_PASSWORD');

/// HMO clients plus the in-memory session cache.
///
/// To add an HMO: write a client (see tht_client.dart / phml_client.dart),
/// add it to [clients], give it credentials in [credentialsFor], and add an
/// HmoOption in lib/models/hmo_models.dart.
class HmoRegistry {
  HmoRegistry._();

  /// How long a portal login is reused before logging in again.
  static const sessionTtl = Duration(minutes: 20);

  static final Map<String, HmoClient> clients = {
    for (final c in <HmoClient>[ThtClient(), PhmlClient(), HygeiaClient()])
      c.id: c,
  };

  static HmoCredentials credentialsFor(String hmo) {
    switch (hmo) {
      case 'tht':
        return const HmoCredentials(_thtUser, _thtPassword);
      case 'phml':
        return const HmoCredentials(_phmlEmail, _phmlPassword);
      case 'hygeia':
        return const HmoCredentials(_hygeiaUser, _hygeiaPassword);
      default:
        return const HmoCredentials('', '');
    }
  }

  static final Map<String, _Cached> _sessions = {};

  static void clearSessions() => _sessions.clear();

  static Future<Object> _session(HmoClient c, HmoCredentials creds) {
    final cached = _sessions[c.id];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.session;
    }
    // Store the future so parallel searches share one login.
    final session = c.login(creds);
    _sessions[c.id] = _Cached(session, DateTime.now().add(sessionTtl));
    session.then(
      (_) {},
      onError: (Object _) {
        if (identical(_sessions[c.id]?.session, session)) {
          _sessions.remove(c.id);
        }
      },
    );
    return session;
  }

  /// Runs a lookup with a cached login. If the portal has logged us out (or
  /// the search fails in any way on a reused session), logs in again and
  /// retries once.
  static Future<HmoSearchResult> lookup(
    String hmo,
    String query, {
    HmoCredentials? credentials,
  }) async {
    final c = clients[hmo];
    if (c == null) throw ArgumentError('Unknown HMO: $hmo');
    final creds = credentials ?? credentialsFor(hmo);
    final cached = _sessions[c.id];
    final reused = cached != null && cached.expiresAt.isAfter(DateTime.now());
    try {
      return await c.search(await _session(c, creds), query);
    } catch (e) {
      if (e is! HmoSessionExpired && !reused) rethrow;
      _sessions.remove(c.id);
      return await c.search(await _session(c, creds), query);
    }
  }
}

class _Cached {
  final Future<Object> session;
  final DateTime expiresAt;
  _Cached(this.session, this.expiresAt);
}
