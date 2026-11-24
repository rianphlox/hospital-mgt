/// One person returned by an HMO lookup (functions/src/hmo/types.ts HmoRecord).
class HmoMember {
  final String hmo;
  final String memberId;
  final String name;
  final String? sex;
  final String? dateOfBirth; // dd/mm/yyyy
  final String? relationship;
  final String? plan;
  final String status; // 'eligible' | 'not eligible' | 'on list'
  final String? coverEnds; // dd/mm/yyyy
  final String? notes;

  const HmoMember({
    required this.hmo,
    required this.memberId,
    required this.name,
    required this.status,
    this.sex,
    this.dateOfBirth,
    this.relationship,
    this.plan,
    this.coverEnds,
    this.notes,
  });

  static String? _s(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory HmoMember.fromJson(Map<String, dynamic> j) => HmoMember(
    hmo: _s(j['hmo']) ?? '',
    memberId: _s(j['memberId']) ?? '',
    name: _s(j['name']) ?? '',
    sex: _s(j['sex']),
    dateOfBirth: _s(j['dateOfBirth']),
    relationship: _s(j['relationship']),
    plan: _s(j['plan']),
    status: _s(j['status']) ?? 'on list',
    coverEnds: _s(j['coverEnds']),
    notes: _s(j['notes']),
  );
}

class HmoLookupResult {
  final String hmo;
  final String label;
  final List<HmoMember> results;
  final int total;
  final String? notice;
  final String? message;

  const HmoLookupResult({
    required this.hmo,
    required this.label,
    required this.results,
    required this.total,
    this.notice,
    this.message,
  });

  factory HmoLookupResult.fromJson(Map<String, dynamic> j) {
    final raw = (j['results'] as List?) ?? const [];
    final results = [
      for (final r in raw)
        HmoMember.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
    return HmoLookupResult(
      hmo: j['hmo']?.toString() ?? '',
      label: j['label']?.toString() ?? '',
      results: results,
      total: (j['total'] as num?)?.toInt() ?? results.length,
      notice: j['notice'] as String?,
      message: j['message'] as String?,
    );
  }

  /// Members grouped by member ID, keeping the portal's order. A PHML family
  /// (principal, spouse, children) shares one NHIS number, so it lands in one
  /// group.
  Map<String, List<HmoMember>> get byMemberId {
    final groups = <String, List<HmoMember>>{};
    for (final m in results) {
      groups.putIfAbsent(m.memberId, () => []).add(m);
    }
    return groups;
  }
}

/// HMOs the app can check. Ids must match ADAPTERS in functions/src/hmo/registry.ts.
class HmoOption {
  final String id;
  final String label;
  final String hint;
  const HmoOption(this.id, this.label, this.hint);

  static const all = [
    HmoOption(
      'tht',
      'THT (Total Health Trust)',
      'Enrollee ID, e.g. AF1234567890_1',
    ),
    HmoOption('phml', 'PHML', 'NHIS number or name'),
  ];
}
