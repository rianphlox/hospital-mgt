/// Pure helpers for the Patient Register (no Flutter / Firebase imports so
/// they can be unit tested directly).
library;

/// Normalises a hospital card number so that "B50", "b 50", "B-50" and
/// " B 50 " all become "B50".
String normalizeCardNumber(String input) {
  return input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

/// Lower-cases and splits a name into words, ignoring punctuation.
List<String> nameWords(String name) {
  return name
      .toLowerCase()
      .split(RegExp(r"[^a-z0-9']+"))
      .map((w) => w.replaceAll("'", ''))
      .where((w) => w.isNotEmpty)
      .toList();
}

/// Builds the keys stored on each register document so a single
/// `array-contains` query can find a patient by the start of any part of
/// their name. "Jane Doe" -> [j, ja, jan, jane, d, do, doe].
List<String> buildNameSearchKeys(String name) {
  final keys = <String>{};
  for (final word in nameWords(name)) {
    for (var i = 1; i <= word.length; i++) {
      keys.add(word.substring(0, i));
    }
  }
  return keys.toList()..sort();
}

/// True when every word typed in [query] is the start of some word in [name].
/// "ja do" matches "Jane Doe"; "doe" matches too.
bool nameMatchesQuery(String name, String query) {
  final words = nameWords(name);
  final queryWords = nameWords(query);
  if (queryWords.isEmpty) return false;
  return queryWords.every((q) => words.any((w) => w.startsWith(q)));
}

/// An inclusive age range in whole years, parsed from search input such as
/// "30", "30-40", "30 to 40", "60+" or "<5".
class AgeRange {
  final int min;
  final int max;

  const AgeRange(this.min, this.max);

  bool contains(int years) => years >= min && years <= max;

  static AgeRange? parse(String input) {
    final text = input.trim().toLowerCase();
    if (text.isEmpty) return null;

    var match = RegExp(r'^(\d{1,3})$').firstMatch(text);
    if (match != null) {
      final n = int.parse(match.group(1)!);
      return AgeRange(n, n);
    }
    match = RegExp(r'^(\d{1,3})\s*(?:-|to|–)\s*(\d{1,3})$').firstMatch(text);
    if (match != null) {
      final a = int.parse(match.group(1)!);
      final b = int.parse(match.group(2)!);
      return a <= b ? AgeRange(a, b) : AgeRange(b, a);
    }
    match = RegExp(r'^(\d{1,3})\s*\+$').firstMatch(text) ??
        RegExp(r'^>=?\s*(\d{1,3})$').firstMatch(text);
    if (match != null) {
      return AgeRange(int.parse(match.group(1)!), 200);
    }
    match = RegExp(r'^<=?\s*(\d{1,3})$').firstMatch(text);
    if (match != null) {
      final n = int.parse(match.group(1)!);
      return AgeRange(0, text.contains('=') ? n : (n > 0 ? n - 1 : 0));
    }
    return null;
  }

  @override
  String toString() => min == max ? '$min' : '$min-$max';
}
