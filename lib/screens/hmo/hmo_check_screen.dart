import 'dart:typed_data';

import 'package:flutter/material.dart';
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
/// and see who is on that HMO's records. THT answers with live eligibility;
/// PHML answers with the hospital's assigned-lives list (family grouped under
/// one NHIS number).
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
    final groups = r.byMemberId;
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
      for (final e in groups.entries) _group(r, e.key, e.value),
    ];
  }

  Widget _group(HmoLookupResult r, String memberId, List<HmoMember> people) {
    final idLabel = r.hmo == 'phml' ? 'NHIS no.' : 'Member ID';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              people.length > 1
                  ? '$idLabel $memberId · ${people.length} people'
                  : '$idLabel $memberId',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          for (var i = 0; i < people.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: _stone200),
            _person(people[i]),
          ],
        ],
      ),
    );
  }

  Widget _person(HmoMember m) {
    final line1 = [
      m.relationship,
      m.sex,
      if (m.dateOfBirth != null) 'DOB ${m.dateOfBirth}',
    ].whereType<String>().join(' · ');
    final line2 = [
      if (m.plan != null) m.plan!,
      if (m.coverEnds != null) 'Cover ends ${m.coverEnds}',
    ].join(' · ');
    return Padding(
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
                if (line1.isNotEmpty)
                  Text(
                    line1,
                    style: const TextStyle(color: _stone500, fontSize: 13),
                  ),
                if (line2.isNotEmpty)
                  Text(
                    line2,
                    style: const TextStyle(color: _stone500, fontSize: 13),
                  ),
                if (m.notes != null)
                  Text(
                    m.notes!,
                    style: const TextStyle(color: _stone500, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _statusChip(m.status),
        ],
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
