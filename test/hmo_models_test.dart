import 'package:crownlog_flutter/models/hmo_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PHML family groups under one NHIS number', () {
    final r = HmoLookupResult.fromJson({
      'hmo': 'phml',
      'label': 'PHML',
      'total': 3,
      'notice': 'list',
      'results': [
        {
          'hmo': 'phml',
          'memberId': '111',
          'name': 'A',
          'relationship': 'Principal',
          'status': 'on list',
        },
        {
          'hmo': 'phml',
          'memberId': '111',
          'name': 'B',
          'relationship': 'Spouse',
          'status': 'on list',
        },
        {
          'hmo': 'phml',
          'memberId': '222',
          'name': 'C',
          'status': 'on list',
          'coverEnds': null,
        },
      ],
    });
    expect(r.results.length, 3);
    expect(r.byMemberId.keys, ['111', '222']);
    expect(r.byMemberId['111']!.map((m) => m.relationship), [
      'Principal',
      'Spouse',
    ]);
    expect(r.results.last.coverEnds, isNull);
  });

  test('THT eligible record parses', () {
    final m = HmoMember.fromJson({
      'hmo': 'tht',
      'memberId': 'AF1_4',
      'name': 'X',
      'status': 'eligible',
      'coverEnds': '30/11/2026',
      'plan': 'FHIS Plan',
    });
    expect(m.status, 'eligible');
    expect(m.coverEnds, '30/11/2026');
  });
}
