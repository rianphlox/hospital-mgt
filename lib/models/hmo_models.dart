/// One person returned by an HMO lookup (see lib/services/hmo/).
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

  /// Member photo, if the HMO has one (THT only for now).
  final String? photoUrl;

  /// Extra headers needed to load [photoUrl] (e.g. a Bearer token), if any.
  final Map<String, String>? photoHeaders;

  /// Photo bytes, for HMOs that return the image inline instead of a URL.
  final List<int>? photoBytes;

  /// The family this person belongs to (THT: the enrollee ID without its
  /// -NN / _N suffix; Hygeia: the enrollee number before "/"; PHML: the
  /// NHIS number). Principal and dependants share it.
  final String? familyId;

  /// 0 for the principal, 1, 2, ... for dependants, when the HMO says.
  final int? dependantNo;

  final List<String> phones;
  final List<String> emails;
  final String? address;

  /// Employer / company / group the cover comes through.
  final String? employer;

  /// The hospital (HCP) the member is registered with.
  final String? primaryProvider;

  final String? coverStarts; // dd/mm/yyyy

  /// Anything else worth showing, label -> value, in display order.
  final Map<String, String> extra;

  bool get hasPhoto => photoUrl != null || photoBytes != null;

  bool get isPrincipal =>
      dependantNo == 0 || relationship?.toLowerCase() == 'principal';

  /// True when there is something to show beyond the summary line.
  bool get hasDetails =>
      phones.isNotEmpty ||
      emails.isNotEmpty ||
      address != null ||
      employer != null ||
      primaryProvider != null ||
      coverStarts != null ||
      extra.isNotEmpty;

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
    this.photoUrl,
    this.photoHeaders,
    this.photoBytes,
    this.familyId,
    this.dependantNo,
    this.phones = const [],
    this.emails = const [],
    this.address,
    this.employer,
    this.primaryProvider,
    this.coverStarts,
    this.extra = const {},
  });

  HmoMember copyWith({
    String? status,
    String? primaryProvider,
    String? notes,
    String? photoUrl,
  }) => HmoMember(
    hmo: hmo,
    memberId: memberId,
    name: name,
    status: status ?? this.status,
    sex: sex,
    dateOfBirth: dateOfBirth,
    relationship: relationship,
    plan: plan,
    coverEnds: coverEnds,
    notes: notes ?? this.notes,
    photoUrl: photoUrl ?? this.photoUrl,
    photoHeaders: photoHeaders,
    photoBytes: photoBytes,
    familyId: familyId,
    dependantNo: dependantNo,
    phones: phones,
    emails: emails,
    address: address,
    employer: employer,
    primaryProvider: primaryProvider ?? this.primaryProvider,
    coverStarts: coverStarts,
    extra: extra,
  );

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
    photoUrl: _s(j['photoUrl']),
    familyId: _s(j['familyId']),
    dependantNo: (j['dependantNo'] as num?)?.toInt(),
    phones: [for (final p in (j['phones'] as List?) ?? const []) '$p'],
    emails: [for (final e in (j['emails'] as List?) ?? const []) '$e'],
    address: _s(j['address']),
    employer: _s(j['employer']),
    primaryProvider: _s(j['primaryProvider']),
    coverStarts: _s(j['coverStarts']),
  );
}

/// A principal with their dependants, or people who share an ID but have no
/// principal in the results.
class HmoFamily {
  final String id;

  /// Null when the principal is not among the results.
  final HmoMember? principal;
  final List<HmoMember> dependants;

  const HmoFamily(this.id, this.principal, this.dependants);

  List<HmoMember> get everyone => [?principal, ...dependants];
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
  /// People grouped into families (see [HmoMember.familyId]), keeping the
  /// order in which each family first appears. Within a family the principal
  /// comes first, then dependants by number.
  List<HmoFamily> get families {
    final groups = <String, List<HmoMember>>{};
    for (final m in results) {
      groups.putIfAbsent(m.familyId ?? m.memberId, () => []).add(m);
    }
    return [for (final e in groups.entries) _family(e.key, e.value)];
  }

  static HmoFamily _family(String id, List<HmoMember> people) {
    final principals = people.where((m) => m.isPrincipal).toList();
    final principal = principals.isEmpty ? null : principals.first;
    final rest = [
      for (final m in people)
        if (!identical(m, principal)) m,
    ];
    // Stable sort by dependant number; unknown numbers keep their place last.
    final indexed = rest.indexed.toList()
      ..sort((a, b) {
        final da = a.$2.dependantNo ?? 1 << 20;
        final db = b.$2.dependantNo ?? 1 << 20;
        return da != db ? da.compareTo(db) : a.$1.compareTo(b.$1);
      });
    return HmoFamily(id, principal, [for (final (_, m) in indexed) m]);
  }

  Map<String, List<HmoMember>> get byMemberId {
    final groups = <String, List<HmoMember>>{};
    for (final m in results) {
      groups.putIfAbsent(m.memberId, () => []).add(m);
    }
    return groups;
  }
}

/// HMOs the app can check. Ids must match HmoRegistry.clients in
/// lib/services/hmo/hmo_registry.dart.
class HmoOption {
  final String id;
  final String label;
  final String hint;
  const HmoOption(this.id, this.label, this.hint);

  static const all = [
    HmoOption(
      'tht',
      'THT (Total Health Trust)',
      'Enrollee ID (AF1234567890_1, 1110000000-01) or name',
    ),
    HmoOption('phml', 'PHML', 'NHIS number or name'),
    HmoOption('hygeia', 'Hygeia', 'Enrollee no. (1234567/0) or name'),
  ];
}
