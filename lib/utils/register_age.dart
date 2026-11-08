/// Age-from-date-of-birth helpers for the Patient Register. Pure Dart (no
/// Flutter / Firebase imports) so they can be unit tested directly.
library;

/// Unit the age number was written in. Matches the NHMIS register age
/// columns: babies are recorded in days (0-28 days) or months (29 days -
/// 11 months), everyone else in whole years.
enum AgeUnit { days, months, years }

extension AgeUnitExtension on AgeUnit {
  static AgeUnit fromString(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    if (v.startsWith('d')) return AgeUnit.days;
    if (v.startsWith('m')) return AgeUnit.months;
    return AgeUnit.years;
  }
}

/// An age worked out from a date of birth.
class CalculatedAge {
  final int value;
  final AgeUnit unit;
  const CalculatedAge(this.value, this.unit);

  @override
  bool operator ==(Object other) =>
      other is CalculatedAge && other.value == value && other.unit == unit;

  @override
  int get hashCode => Object.hash(value, unit);

  @override
  String toString() => 'CalculatedAge($value ${unit.name})';
}

DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

int _daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// Parses a date of birth as written in the register: "7/8/1996",
/// "07-08-96", "7.8.96" (day first) or ISO "1996-08-07". Returns null for
/// anything unclear ("?/4/2023") or impossible ("31/2/1991"); such dates
/// are kept as written but never used to calculate an age.
///
/// Two-digit years are taken as 20YY unless that would be after
/// [reference] (default today), in which case 19YY: "7/8/96" is 1996,
/// "4/8/23" is 2023.
DateTime? parseDateOfBirth(String? value, {DateTime? reference}) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return null;
  int year;
  int month;
  int day;
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(v);
  final dmy = RegExp(
    r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2}|\d{4})$',
  ).firstMatch(v);
  if (iso != null) {
    year = int.parse(iso.group(1)!);
    month = int.parse(iso.group(2)!);
    day = int.parse(iso.group(3)!);
  } else if (dmy != null) {
    day = int.parse(dmy.group(1)!);
    month = int.parse(dmy.group(2)!);
    year = int.parse(dmy.group(3)!);
    if (dmy.group(3)!.length == 2) {
      final refYear = (reference ?? DateTime.now()).year;
      year += 2000;
      if (year > refYear) year -= 100;
    }
  } else {
    return null;
  }
  if (year < 1800 || month < 1 || month > 12 || day < 1) return null;
  if (day > _daysInMonth(year, month)) return null;
  return DateTime(year, month, day);
}

/// Whole calendar months from [from] to [to] (both date-only, from <= to).
/// A month is complete on the same day number; when that day does not
/// exist (born 31 Jan, or 29 Feb in a non-leap year) it is complete on the
/// last day of the month.
int _wholeMonths(DateTime from, DateTime to) {
  var months = (to.year - from.year) * 12 + (to.month - from.month);
  final anniversaryDay = from.day <= _daysInMonth(to.year, to.month)
      ? from.day
      : _daysInMonth(to.year, to.month);
  if (to.day < anniversaryDay) months--;
  return months;
}

/// True when [dob] is after [reference] (the visit date, or today).
bool isDateOfBirthInFuture(DateTime dob, DateTime reference) =>
    _dateOnly(dob).isAfter(_dateOnly(reference));

/// Age on [reference] for someone born on [dob], in the unit the NHMIS
/// register uses: 0-28 days in days, then months until the first birthday
/// (at least 1 month), then whole years. Returns null when [dob] is after
/// [reference].
///
/// Leap-day births have their birthday on 28 February in non-leap years.
CalculatedAge? calculateAge(DateTime dob, DateTime reference) {
  final from = _dateOnly(dob);
  final to = _dateOnly(reference);
  if (from.isAfter(to)) return null;
  final days = to.difference(from).inDays;
  if (days <= 28) return CalculatedAge(days, AgeUnit.days);
  final months = _wholeMonths(from, to);
  if (months < 12) {
    return CalculatedAge(months < 1 ? 1 : months, AgeUnit.months);
  }
  return CalculatedAge(months ~/ 12, AgeUnit.years);
}

/// Parses [dateOfBirth] text and calculates the age on [reference].
/// Null when the date is blank, unclear, impossible or in the future.
CalculatedAge? calculateAgeFromText(String? dateOfBirth, DateTime reference) {
  final dob = parseDateOfBirth(dateOfBirth, reference: reference);
  return dob == null ? null : calculateAge(dob, reference);
}

/// Validation message for a date of birth, or null when it is acceptable.
/// Only a readable date after [reference] is an error; blank or unclear
/// dates are allowed because the register keeps them exactly as written.
String? validateDateOfBirth(
  String? dateOfBirth,
  DateTime reference, {
  bool referenceIsVisitDate = false,
}) {
  final dob = parseDateOfBirth(dateOfBirth, reference: reference);
  if (dob == null || !isDateOfBirthInFuture(dob, reference)) return null;
  return referenceIsVisitDate
      ? 'Date of birth is after the visit date'
      : 'Date of birth is in the future';
}

/// The age to store when an entry is submitted. An age typed by staff
/// ([ageText], a whole number in [unit]) always wins. When the age box was
/// left empty, the age is worked out from [dateOfBirth] on [reference] (the
/// visit date, or today) so it is saved with the record. Null when neither
/// gives an age.
CalculatedAge? resolveAgeOnSubmit({
  required String? ageText,
  required AgeUnit unit,
  required String? dateOfBirth,
  required DateTime reference,
}) {
  final typed = (ageText ?? '').trim();
  if (typed.isNotEmpty) {
    final n = int.tryParse(typed);
    return n == null ? null : CalculatedAge(n, unit);
  }
  return calculateAgeFromText(dateOfBirth, reference);
}
