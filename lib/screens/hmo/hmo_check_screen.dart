import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/hmo_models.dart';
import '../../services/hmo_service.dart';

const _stone200 = Color(0xFFE7E5E4);
const _stone500 = Color(0xFF78716C);
const _stone900 = Color(0xFF1C1917);
const _emeraldBg = Color(0xFFD1FAE5);
const _emeraldDark = Color(0xFF047857);
const _redBg = Color(0xFFFEE2E2);
const _red = Color(0xFFDC2626);
const _stoneBg = Color(0xFFF5F5F4);

/// Front-desk HMO check: pick the HMO, type a member ID / NHIS number or name,
/// and see who is on that HMO's records. THT and Hygeia answer with
/// eligibility; PHML answers with the hospital's assigned-lives list. Results
/// are grouped by family: the principal, then their dependants. Tap anyone
/// for their contact, employer and cover details.
class HmoCheckScreen extends StatefulWidget {
  const HmoCheckScreen({super.key});

  @override
  State<HmoCheckScreen> createState() => _HmoCheckScreenState();
}

class _HmoCheckScreenState extends State<HmoCheckScreen> {
  final _query = TextEditingController();
  HmoOption _hmo = HmoOption.all.first;
  bool _busy = false;
  String? _error;
  HmoLookupResult? _result;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) {
      setState(() => _error = 'Enter a member ID or name.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final r = await HmoService.lookup(hmo: _hmo.id, query: q);
      if (!mounted) return;
      setState(() => _result = r);
    } on HmoLookupException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('HMO Check'),
        backgroundColor: Colors.white,
        foregroundColor: _stone900,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _stone200),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        children: [
          DropdownButtonFormField<HmoOption>(
            initialValue: _hmo,
            decoration: const InputDecoration(
              labelText: 'HMO',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final o in HmoOption.all)
                DropdownMenuItem(value: o, child: Text(o.label)),
            ],
            onChanged: _busy
                ? null
                : (o) => setState(() {
                    if (o != null) _hmo = o;
                    _result = null;
                    _error = null;
                  }),
          ),
          if (!HmoService.isConfigured(_hmo.id)) ...[
            const SizedBox(height: 8),
            _errorBox(
              'The ${_hmo.id.toUpperCase()} login is not configured in this '
              'build of the app, so ${_hmo.id.toUpperCase()} checks will not work.',
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _query,
            enabled: !_busy,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'Member ID or name',
              hintText: _hmo.hint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _search,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(
                _busy ? 'Checking ${_hmo.id.toUpperCase()}…' : 'Search',
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) _errorBox(_error!),
          if (_result != null) ..._results(_result!),
        ],
      ),
    );
  }

  Widget _errorBox(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _redBg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(msg, style: const TextStyle(color: _red)),
  );

  List<Widget> _results(HmoLookupResult r) {
    if (r.results.isEmpty) {
      return [
        Text(
          r.message ?? 'No match found.',
          style: const TextStyle(color: _stone500),
        ),
      ];
    }
    final families = r.families;
    final shown = r.results.length;
    return [
      Text(
        r.total > shown
            ? 'Showing $shown of ${r.total} matches. Narrow the search to see others.'
            : '$shown ${shown == 1 ? 'person' : 'people'} found',
        style: const TextStyle(color: _stone500, fontSize: 13),
      ),
      if (r.notice != null) ...[
        const SizedBox(height: 4),
        Text(r.notice!, style: const TextStyle(color: _stone500, fontSize: 12)),
      ],
      const SizedBox(height: 8),
      for (final f in families) _group(r, f),
    ];
  }

  String _idLabel(String hmo) => hmo == 'phml' ? 'NHIS no.' : 'Member ID';

  Widget _group(HmoLookupResult r, HmoFamily f) {
    final people = f.everyone;
    final principal = f.principal;
    final header = people.length > 1
        ? (r.hmo == 'phml'
              ? 'NHIS no. ${f.id} · ${people.length} people'
              : 'Family ${f.id} · ${people.length} people')
        : '${_idLabel(r.hmo)} ${people.single.memberId}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: _stone200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: _stoneBg,
            child: Text(
              header,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (principal != null) ...[
            _person(principal, f),
            if (f.dependants.isNotEmpty) ...[
              const Divider(height: 1, color: _stone200),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                child: Text(
                  'Dependants (${f.dependants.length})',
                  style: const TextStyle(
                    color: _stone500,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final d in f.dependants) _dependant(d, f),
              const SizedBox(height: 6),
            ],
          ] else
            for (var i = 0; i < people.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: _stone200),
              _person(people[i], f),
            ],
        ],
      ),
    );
  }

  Widget _person(HmoMember m, HmoFamily family) {
    final line1 = [
      m.relationship,
      m.sex,
      if (m.dateOfBirth != null) 'DOB ${m.dateOfBirth}',
    ].whereType<String>().join(' · ');
    final line2 = [
      if (m.plan != null) m.plan!,
      if (m.coverEnds != null) 'Cover ends ${m.coverEnds}',
    ].join(' · ');
    final contact = [
      if (m.phones.isNotEmpty) formatPhone(m.phones.first),
      if (m.employer != null) m.employer!,
    ].join(' · ');
    const small = TextStyle(color: _stone500, fontSize: 13);
    return InkWell(
      onTap: () => _showDetails(m, family),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _photo(m),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (line1.isNotEmpty) Text(line1, style: small),
                  if (line2.isNotEmpty) Text(line2, style: small),
                  if (contact.isNotEmpty) Text(contact, style: small),
                  if (m.notes != null)
                    Text(
                      m.notes!,
                      style: const TextStyle(color: _stone500, fontSize: 12),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _statusChip(m.status),
                const SizedBox(height: 8),
                const Icon(Icons.chevron_right, color: _stone500, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// A compact row under the principal.
  Widget _dependant(HmoMember m, HmoFamily family) {
    final line = [
      m.relationship,
      m.memberId,
      if (m.dateOfBirth != null) 'DOB ${m.dateOfBirth}',
    ].whereType<String>().join(' · ');
    return InkWell(
      onTap: () => _showDetails(m, family),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _photoImage(m, 40),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (line.isNotEmpty)
                    Text(
                      line,
                      style: const TextStyle(color: _stone500, fontSize: 12),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _statusChip(m.status),
          ],
        ),
      ),
    );
  }

  /// Everything the HMO told us about [m], in a bottom sheet. Phone numbers,
  /// emails and the member ID copy on tap.
  void _showDetails(HmoMember m, HmoFamily family) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scroll) => _HmoDetails(
          member: m,
          family: family,
          idLabel: _idLabel(m.hmo),
          scroll: scroll,
          photo: (p, size) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _photoImage(p, size),
          ),
          statusChip: _statusChip,
          onPhotoTap: m.hasPhoto ? () => _showPhoto(m) : null,
          onOpen: (other) {
            Navigator.of(sheetContext).pop();
            _showDetails(other, family);
          },
        ),
      ),
    );
  }

  static const _photoSize = 56.0;

  Widget _photoPlaceholder(double size) => Container(
    width: size,
    height: size,
    color: _stoneBg,
    child: Icon(Icons.person, color: _stone500, size: size * 0.55),
  );

  /// The member's photo (or a plain placeholder), [size] px square.
  Widget _photoImage(HmoMember m, double size, {BoxFit fit = BoxFit.cover}) {
    if (m.photoBytes != null) {
      return Image.memory(
        Uint8List.fromList(m.photoBytes!),
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, _, _) => _photoPlaceholder(size),
      );
    }
    if (m.photoUrl == null) return _photoPlaceholder(size);
    return Image.network(
      m.photoUrl!,
      headers: m.photoHeaders,
      width: size,
      height: size,
      fit: fit,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _photoPlaceholder(size),
      errorBuilder: (_, _, _) => _photoPlaceholder(size),
    );
  }

  Widget _photo(HmoMember m) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: _photoImage(m, _photoSize),
    );
    if (!m.hasPhoto) return image;
    return GestureDetector(
      onTap: () => _showPhoto(m),
      child: Semantics(label: 'Photo of ${m.name}', button: true, child: image),
    );
  }

  void _showPhoto(HmoMember m) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _photoImage(m, 300, fit: BoxFit.contain),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                m.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final (bg, fg, label) = switch (status) {
      'eligible' => (_emeraldBg, _emeraldDark, 'Eligible'),
      'not eligible' => (_redBg, _red, 'Not eligible'),
      _ => (_stoneBg, _stone500, 'On list'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// "08031234567" -> "0803 123 4567"; "+2348031234567" -> "+234 803 123 4567".
/// Anything else is shown as given.
String formatPhone(String p) {
  final local = RegExp(r'^(0\d{3})(\d{3})(\d{4})$').firstMatch(p);
  if (local != null) return '${local[1]} ${local[2]} ${local[3]}';
  final intl = RegExp(r'^\+?(234)(\d{3})(\d{3})(\d{4})$').firstMatch(p);
  if (intl != null) return '+${intl[1]} ${intl[2]} ${intl[3]} ${intl[4]}';
  return p;
}

class _HmoDetails extends StatefulWidget {
  final HmoMember member;
  final HmoFamily family;
  final String idLabel;
  final ScrollController scroll;
  final Widget Function(HmoMember, double) photo;
  final Widget Function(String) statusChip;
  final VoidCallback? onPhotoTap;
  final void Function(HmoMember) onOpen;

  const _HmoDetails({
    required this.member,
    required this.family,
    required this.idLabel,
    required this.scroll,
    required this.photo,
    required this.statusChip,
    required this.onPhotoTap,
    required this.onOpen,
  });

  @override
  State<_HmoDetails> createState() => _HmoDetailsState();
}

class _HmoDetailsState extends State<_HmoDetails> {
  String? _copied;

  Future<void> _copy(String value) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
    } catch (_) {
      return; // No clipboard on this device; nothing to confirm.
    }
    if (!mounted) return;
    setState(() => _copied = value);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted && _copied == value) setState(() => _copied = null);
    });
  }

  Widget _row(String label, String value, {String? copyValue}) {
    final copyable = copyValue != null;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(color: _stone500, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: _stone900, fontSize: 14),
            ),
          ),
          if (copyable)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _copied == copyValue
                  ? const Text(
                      'Copied',
                      style: TextStyle(color: _emeraldDark, fontSize: 12),
                    )
                  : const Icon(Icons.copy, size: 16, color: _stone500),
            ),
        ],
      ),
    );
    if (!copyable) return row;
    return InkWell(onTap: () => _copy(copyValue), child: row);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final others = [
      for (final p in widget.family.everyone)
        if (!identical(p, m)) p,
    ];
    final rows = <Widget>[
      _row(widget.idLabel, m.memberId, copyValue: m.memberId),
      if (m.relationship != null) _row('Relationship', m.relationship!),
      if (m.sex != null) _row('Sex', m.sex!),
      if (m.dateOfBirth != null) _row('Date of birth', m.dateOfBirth!),
      for (final p in m.phones) _row('Phone', formatPhone(p), copyValue: p),
      for (final e in m.emails) _row('Email', e, copyValue: e),
      if (m.address != null) _row('Address', m.address!),
      if (m.employer != null) _row('Employer / group', m.employer!),
      if (m.plan != null) _row('Plan', m.plan!),
      if (m.coverStarts != null) _row('Cover starts', m.coverStarts!),
      if (m.coverEnds != null) _row('Cover ends', m.coverEnds!),
      if (m.primaryProvider != null)
        _row('Primary hospital', m.primaryProvider!),
      for (final e in m.extra.entries) _row(e.key, e.value),
      if (m.notes != null) _row('Notes', m.notes!),
    ];
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _stone200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: widget.onPhotoTap,
              child: widget.photo(m, 64),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _stone900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  widget.statusChip(m.status),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: _stone200),
        ...rows,
        if (!m.hasDetails)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'The HMO did not share contact or employer details for this '
              'person.',
              style: TextStyle(color: _stone500, fontSize: 12),
            ),
          ),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            m.isPrincipal ? 'Dependants' : 'Family',
            style: const TextStyle(
              color: _stone500,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          for (final p in others)
            InkWell(
              onTap: () => widget.onOpen(p),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    widget.photo(p, 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            [
                              p.relationship,
                              p.memberId,
                            ].whereType<String>().join(' · '),
                            style: const TextStyle(
                              color: _stone500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    widget.statusChip(p.status),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
