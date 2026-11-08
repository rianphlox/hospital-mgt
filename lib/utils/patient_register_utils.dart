/// Pure helpers for the Patient Register (no Flutter / Firebase imports so
/// they can be unit tested directly).
library;

/// Normalises a hospital card number so that "B50", "b 50", "B-50" and
/// " B 50 " all become "B50".
String normalizeCardNumber(String input) {
  return input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

/// Checks a card number typed by staff or read from an import file.
/// Returns an error message, or null when the card number is acceptable.
/// A card number is required, must contain at least one digit, may only use
/// one letter A-L followed by digits (optional spaces, "-" or "/" separators),
/// and is at most 20 characters.
String? validateCardNumber(String? input) {
  final v = (input ?? '').trim();
  if (v.isEmpty || normalizeCardNumber(v).isEmpty) {
    return 'Card number is required';
  }
  if (v.length > 20) return 'Card number is too long (max 20 characters)';
  if (!RegExp(r'^[A-Za-z0-9 /-]+$').hasMatch(v)) {
    return 'Use only letters, numbers, spaces, "-" or "/"';
  }
  if (!RegExp(r'[0-9]').hasMatch(v)) return 'Card number must include a number';
  if (!RegExp(r'^[A-La-l][ /-]*[0-9]+$').hasMatch(v)) {
    return 'Use a letter A-L followed by a number, e.g. B 50';
  }
  return null;
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

/// Card identity includes the year, since cards restart every January.
String registerCardKey(int year, String cardNumber) =>
    '$year:${normalizeCardNumber(cardNumber)}';

/// A null selected year means all years.
bool matchesRegisterYear(int registerYear, int? selectedYear) =>
    selectedYear == null || registerYear == selectedYear;
