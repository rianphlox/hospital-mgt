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

  test('families: principal first, dependants by number', () {
    HmoMember m(String id, String name, int? dep, {String? fam}) => HmoMember(
      hmo: 'tht',
      memberId: id,
      name: name,
      status: 'on list',
      familyId: fam,
      dependantNo: dep,
    );
    final r = HmoLookupResult(
      hmo: 'tht',
      label: 'THT',
      total: 5,
      results: [
        m('F1-02', 'Child', 2, fam: 'F1'),
        m('X9', 'Loner', null),
        m('F1-00', 'Parent', 0, fam: 'F1'),
        m('F1-01', 'Spouse', 1, fam: 'F1'),
        m('F2-03', 'Dependant only', 3, fam: 'F2'),
      ],
    );
    final f = r.families;
    expect(f.map((x) => x.id), ['F1', 'X9', 'F2']);
    expect(f[0].principal!.name, 'Parent');
    expect(f[0].dependants.map((x) => x.name), ['Spouse', 'Child']);
    expect(f[0].everyone, hasLength(3));
    expect(f[1].principal, isNull);
    expect(f[2].principal, isNull);
    expect(f[2].dependants.single.name, 'Dependant only');
  });
}
