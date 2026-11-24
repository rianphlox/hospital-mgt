// Live check against the real HMO portals. Skipped unless the logins are
// supplied at run time (keep the defines file outside the repo):
//   flutter test test/hmo_live_test.dart \
//     --dart-define-from-file=/path/outside/repo/hmo_defines.json \
//     --dart-define=THT_ID=... --dart-define=PHML_ID=...
// Prints counts and statuses only, never names.
import 'package:crownlog_flutter/services/hmo/hmo_client.dart';
import 'package:crownlog_flutter/services/hmo/hmo_registry.dart';
import 'package:flutter_test/flutter_test.dart';

const _thtId = String.fromEnvironment('THT_ID');
const _phmlId = String.fromEnvironment('PHML_ID');

void main() {
  for (final (hmo, query) in [('tht', _thtId), ('phml', _phmlId)]) {
    final configured =
        HmoRegistry.credentialsFor(hmo).isComplete && query.isNotEmpty;
    test(
      '$hmo live lookup',
      skip: configured ? false : 'no login/query',
      () async {
        HmoRegistry.clearSessions();
        final sw = Stopwatch()..start();
        final r = await HmoRegistry.lookup(hmo, query);
        final first = sw.elapsedMilliseconds;
        await HmoRegistry.lookup(hmo, query);
        final cached = sw.elapsedMilliseconds - first;
        // ignore: avoid_print
        print(
          '$hmo: count=${r.records.length} '
          'statuses=${r.records.map((m) => m.status).toList()} '
          'relationships=${r.records.map((m) => m.relationship).toList()} '
          'memberIds=${r.records.map((m) => m.memberId).toSet().length} '
          'coverEnds=${r.records.map((m) => m.coverEnds).toList()} '
          'firstMs=$first cachedMs=$cached',
        );
        expect(r.records, isNotEmpty);
      },
    );

    test(
      '$hmo wrong password is a login error',
      skip: configured ? false : 'no login/query',
      () async {
        HmoRegistry.clearSessions();
        final creds = HmoCredentials(
          HmoRegistry.credentialsFor(hmo).user,
          'wrong-password',
        );
        await expectLater(
          HmoRegistry.lookup(hmo, query, credentials: creds),
          throwsA(isA<HmoLoginFailed>()),
        );
        HmoRegistry.clearSessions();
      },
    );

    test(
      '$hmo unknown id returns nothing',
      skip: configured ? false : 'no login/query',
      () async {
        final r = await HmoRegistry.lookup(
          hmo,
          hmo == 'tht' ? 'ZZ0000000000_9' : 'zzqxnotaname',
        );
        expect(r.records, isEmpty);
      },
    );
  }
}
