import 'dart:io';

import '../models/hmo_models.dart';
import 'hmo/hmo_client.dart';
import 'hmo/hmo_registry.dart';

/// Thrown with a message that can be shown to staff as-is.
class HmoLookupException implements Exception {
  final String message;
  const HmoLookupException(this.message);
  @override
  String toString() => message;
}

/// Looks patients up on the HMO provider portals (THT, PHML) directly from
/// the app. The portal logins are compiled into the build with
/// --dart-define-from-file (see lib/services/hmo/hmo_registry.dart).
class HmoService {
  /// True when this build has a login for [hmo].
  static bool isConfigured(String hmo) =>
      HmoRegistry.credentialsFor(hmo).isComplete;

  static Future<HmoLookupResult> lookup({
    required String hmo,
    required String query,
  }) async {
    final client = HmoRegistry.clients[hmo];
    if (client == null) throw HmoLookupException('Unknown HMO "$hmo".');
    final q = query.trim();
    if (q.length < 2) {
      throw const HmoLookupException('Enter at least 2 characters.');
    }
    if (!isConfigured(hmo)) {
      throw HmoLookupException(
        'The ${client.label} login is not configured in this build of the '
        'app. Ask whoever builds the app to add it.',
      );
    }
    try {
      final r = await HmoRegistry.lookup(hmo, q);
      return HmoLookupResult(
        hmo: hmo,
        label: client.label,
        results: r.records,
        total: r.total ?? r.records.length,
        notice: r.notice,
        message: r.records.isEmpty
            ? 'No ${client.label} enrollee found for "$q". '
                  'Check the ${client.queryHint}.'
            : null,
      );
    } on HmoLoginFailed {
      throw HmoLookupException(
        'Could not sign in to ${client.label}. The ${client.label} login '
        'saved in the app may have changed.',
      );
    } on HmoPortalError catch (e) {
      throw HmoLookupException('${client.label}: ${e.message}');
    } on HmoSessionExpired {
      throw HmoLookupException(
        '${client.label} keeps signing us out. Try again shortly.',
      );
    } on HttpException {
      throw HmoLookupException(
        'Could not reach the ${client.label} portal. Check the internet '
        'connection and try again.',
      );
    } on SocketException {
      throw HmoLookupException(
        'Could not reach the ${client.label} portal. Check the internet '
        'connection and try again.',
      );
    }
  }
}
