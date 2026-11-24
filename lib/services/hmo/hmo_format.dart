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

String titleCase(String s) => s.toLowerCase().replaceAllMapped(
  RegExp(r'\b([a-z])'),
  (m) => m[1]!.toUpperCase(),
);

/// Trimmed string, or '' for null.
String str(Object? v) => v == null ? '' : v.toString().trim();

String? orNull(String s) => s.isEmpty ? null : s;
