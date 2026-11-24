const _months = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

String _pad(int n) => n.toString().padLeft(2, '0');

/// Turns the portals' date formats into dd/mm/yyyy:
///  - "2013-03-30T00:00:00" (THT, ISO)
///  - "05 April, 1965" (PHML)
/// Returns null for empty input and for .NET's "no date" (year 0001).
String? toDdMmYyyy(Object? raw) {
  if (raw is! String) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;

  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (iso != null) {
    if (int.parse(iso[1]!) < 1900) return null;
    return '${iso[3]}/${iso[2]}/${iso[1]}';
  }

  final words = RegExp(r'^(\d{1,2})\s+([A-Za-z]+),?\s+(\d{4})$').firstMatch(s);
  if (words != null && words[2]!.length >= 3) {
    final m = _months.indexOf(words[2]!.substring(0, 3).toLowerCase());
    if (m >= 0) {
      return '${_pad(int.parse(words[1]!))}/${_pad(m + 1)}/${words[3]}';
    }
  }

  final dmy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
  if (dmy != null) {
    return '${_pad(int.parse(dmy[1]!))}/${_pad(int.parse(dmy[2]!))}/${dmy[3]}';
  }
  return s; // Unknown format: show what the portal gave.
}

const _entities = {
  'nbsp': ' ',
  'amp': '&',
  'quot': '"',
  'apos': "'",
  'lt': '<',
  'gt': '>',
};

/// Decodes HTML entities the portals leave in names (&nbsp; &amp; &#39;
/// &#x27; ..., any case), turns non-breaking spaces into spaces, collapses
/// runs of whitespace and trims.
String cleanText(String s) {
  final decoded = s.replaceAllMapped(
    RegExp(r'&(#x[0-9a-f]+|#[0-9]+|[a-z]+);', caseSensitive: false),
    (m) {
      final e = m[1]!.toLowerCase();
      int? code;
      if (e.startsWith('#x')) {
        code = int.tryParse(e.substring(2), radix: 16);
      } else if (e.startsWith('#')) {
        code = int.tryParse(e.substring(1));
      }
      if (code != null && code > 0 && code <= 0x10FFFF) {
        return String.fromCharCode(code);
      }
      return _entities[e] ?? m[0]!;
    },
  );
  return decoded
      .replaceAll('\u00A0', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Cleans [s] (see [cleanText]) and title-cases it: "JOHN DOE" -> "John Doe".
String titleCase(String s) => cleanText(s)
    .toLowerCase()
    .replaceAllMapped(
      RegExp(r'(^|[\s\-(])([a-z])'),
      (m) => '${m[1]}${m[2]!.toUpperCase()}',
    )
    // O'brien -> O'Brien, but Mary's stays Mary's.
    .replaceAllMapped(
      RegExp(r"(^|[\s\-(])([A-Z])'([a-z])"),
      (m) => "${m[1]}${m[2]}'${m[3]!.toUpperCase()}",
    );

/// Trimmed string, or '' for null.
String str(Object? v) => v == null ? '' : v.toString().trim();

String? orNull(String s) => s.isEmpty ? null : s;
