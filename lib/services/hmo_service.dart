import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/hmo_models.dart';

/// Thrown with a message that can be shown to staff as-is.
class HmoLookupException implements Exception {
  final String message;
  const HmoLookupException(this.message);
  @override
  String toString() => message;
}

/// Calls the `hmoLookup` Cloud Function (functions/src/hmoLookup.ts), which
/// signs in to the HMO portals. The portal logins stay on the server.
class HmoService {
  /// Must match REGION in functions/src/index.ts.
  static const String region = 'europe-west1';

  static Future<HmoLookupResult> lookup({
    required String hmo,
    required String query,
  }) async {
    try {
      final callable =
          FirebaseFunctions.instanceFor(
            app: Firebase.app(),
            region: region,
          ).httpsCallable(
            'hmoLookup',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
          );
      final result = await callable.call<Map<Object?, Object?>>({
        'hmo': hmo,
        'query': query.trim(),
      });
      return HmoLookupResult.fromJson(Map<String, dynamic>.from(result.data));
    } on FirebaseFunctionsException catch (e) {
      throw HmoLookupException(_friendly(e));
    }
  }

  static String _friendly(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'Please sign in again.';
      case 'not-found':
        return 'HMO check is not set up on the server yet.';
      case 'deadline-exceeded':
        return 'The HMO portal took too long. Try again.';
      case 'unavailable':
        return e.message ?? 'Could not reach the HMO portal. Try again.';
      default:
        return e.message ?? 'Something went wrong (${e.code}).';
    }
  }
}
