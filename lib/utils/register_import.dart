import 'dart:convert';
import '../models/register_patient_models.dart';
import 'patient_register_utils.dart';
import 'register_age.dart';

/// Column order used for Patient Register CSV files (import and export).
/// Card number comes first. On import, columns are matched by header name,
/// so order does not matter and unknown or extra columns (for example the
/// old `serialNo` / `ageBand`) are ignored.
const List<String> registerCsvColumns = [
  'cardNumber',
  'registerYear',
  'visitDate',
  'name',
  'dateOfBirth',
  'sex',
  'age',
  'ageUnit',
  'contactAddress',
  'stateOfOrigin',
  'phone',
  'firstContact',
  'nokName',
  'nokRelationship',
  'nokAddress',
  'nokPhone',
  'lga',
  'ward',
  'facility',
  'needsReview',
  'reviewNotes',
];

/// One parsed row from an import file.
class RegisterImportRow {
  /// 1-based row number in the file (header excluded for CSV).
  final int rowNumber;
  final RegisterPatient? patient;
  final List<String> errors;

  /// Set by the import screen once duplicates have been checked.
  bool isDuplicate;

  RegisterImportRow({
    required this.rowNumber,
    this.patient,
    List<String>? errors,
    this.isDuplicate = false,
  }) : errors = errors ?? [];

  bool get isValid => patient != null && errors.isEmpty;
}

/// Splits CSV text into rows of fields (RFC 4180: quoted fields, escaped
/// quotes, commas and newlines inside quotes, CRLF or LF line endings).
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var i = 0;
  if (text.startsWith('\uFEFF')) i = 1; // UTF-8 BOM from Excel

  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    if (!(row.length == 1 && row.first.trim().isEmpty)) rows.add(row);
    row = <String>[];
  }

  while (i < text.length) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == ',') {
      endField();
    } else if (ch == '\r') {
      // swallow; \n ends the row
    } else if (ch == '\n') {
      endRow();
    } else {
      field.write(ch);
    }
    i++;
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

String _csvEscape(String value) {
  if (value.contains(RegExp(r'[",\r\n]'))) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Writes patients back out in the same CSV format the importer accepts.
String registerPatientsToCsv(List<RegisterPatient> patients) {
  final buffer = StringBuffer()..writeln(registerCsvColumns.join(','));
  for (final p in patients) {
    final values = <String>[
      p.cardNumber,
      p.registerYear.toString(),
      p.visitDate != null ? _isoDate(p.visitDate!) : '',
      p.name,
      p.dateOfBirth,
      p.sex.code,
      p.age?.toString() ?? '',
      p.ageUnit.name,
      p.contactAddress,
      p.stateOfOrigin,
      p.phone,
      p.firstContact == null ? '' : (p.firstContact! ? 'Yes' : 'No'),
      p.nokName,
      p.nokRelationship,
      p.nokAddress,
      p.nokPhone,
      p.lga,
      p.ward,
      p.facility,
      p.needsReview ? 'true' : 'false',
      p.reviewNotes,
    ];
    buffer.writeln(values.map(_csvEscape).join(','));
  }
  return buffer.toString();
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Parses "2026-02-07", "07/02/2026" or "7/2/26" (day first).
DateTime? parseRegisterDate(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return null;
  final iso = DateTime.tryParse(v);
  if (iso != null) return iso;
  final m = RegExp(
    r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2}|\d{4})$',
  ).firstMatch(v);
  if (m == null) return null;
  final day = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  var year = int.parse(m.group(3)!);
  if (m.group(3)!.length == 2) year += 2000;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

bool? _parseYesNo(String? value) {
  final v = (value ?? '').trim().toLowerCase();
  if (['yes', 'y', 'true', '1'].contains(v)) return true;
  if (['no', 'n', 'false', '0'].contains(v)) return false;
  return null;
}

String _key(String header) =>
    header.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Builds a [RegisterImportRow] from a map of column name -> text value.
RegisterImportRow registerRowFromMap(
  Map<String, String> raw,
  int rowNumber, {
  DateTime? now,
  String? createdBy,
}) {
  final m = {for (final e in raw.entries) _key(e.key): e.value.trim()};
  String get(String name) => m[_key(name)] ?? '';

  final errors = <String>[];
  final card = get('cardNumber');
  final name = get('name');
  final cardError = validateCardNumber(card);
  if (cardError != null) {
    errors.add(
      normalizeCardNumber(card).isEmpty
          ? 'Missing card number'
          : 'Card number "$card": $cardError',
    );
  }
  if (name.isEmpty) errors.add('Missing name');

  int? age;
  final ageText = get('age');
  if (ageText.isNotEmpty) {
    age = int.tryParse(ageText);
    if (age == null) errors.add('Age "$ageText" is not a whole number');
  }

  final visitText = get('visitDate');
  final visitDate = parseRegisterDate(visitText);
  if (visitText.isNotEmpty && visitDate == null) {
    errors.add('Visit date "$visitText" not understood (use YYYY-MM-DD)');
  }

  final yearText = get('registerYear').isNotEmpty
      ? get('registerYear')
      : get('year');
  final year = yearText.isEmpty ? null : int.tryParse(yearText);
  if (yearText.isNotEmpty && (year == null || year < 1900 || year > 9999)) {
    errors.add(
      'Register year "$yearText" must be a four-digit year (1900-9999)',
    );
  }

  // Blank age + readable date of birth: work the age out from the DOB on the
  // visit date (today when there is none). A DOB after that date is an error.
  var ageUnit = AgeUnitExtension.fromString(get('ageUnit'));
  final dobText = get('dateOfBirth');
  final ageReference = visitDate ?? now ?? DateTime.now();
  final dobError = validateDateOfBirth(
    dobText,
    ageReference,
    referenceIsVisitDate: visitDate != null,
  );
  if (dobError != null) {
    errors.add('Date of birth "$dobText": $dobError');
  } else if (ageText.isEmpty) {
    final calculated = calculateAgeFromText(dobText, ageReference);
    if (calculated != null) {
      age = calculated.value;
      ageUnit = calculated.unit;
    }
  }

  final patient = errors.isNotEmpty
      ? null
      : RegisterPatient(
          id: '',
          cardNumber: card,
          registerYear: year,
          name: name,
          dateOfBirth: get('dateOfBirth'),
          sex: RegisterSexExtension.fromString(get('sex')),
          age: age,
          ageUnit: ageUnit,
          contactAddress: get('contactAddress'),
          stateOfOrigin: get('stateOfOrigin'),
          phone: get('phone'),
          firstContact: _parseYesNo(get('firstContact')),
          nokName: get('nokName'),
          nokRelationship: get('nokRelationship'),
          nokAddress: get('nokAddress'),
          nokPhone: get('nokPhone'),
          visitDate: visitDate,
          lga: get('lga'),
          ward: get('ward'),
          facility: get('facility'),
          needsReview: _parseYesNo(get('needsReview')) ?? false,
          reviewNotes: get('reviewNotes'),
          createdAt: now ?? DateTime.now(),
          createdBy: createdBy,
        );
  return RegisterImportRow(
    rowNumber: rowNumber,
    patient: patient,
    errors: errors,
  );
}

/// Parses register_2026.csv-style text. Throws [FormatException] when the
/// header is missing the required columns.
List<RegisterImportRow> parseRegisterCsv(
  String text, {
  DateTime? now,
  String? createdBy,
}) {
  final rows = parseCsv(text);
  if (rows.isEmpty) return [];
  final header = rows.first;
  final keys = header.map(_key).toSet();
  if (!keys.contains('cardnumber') || !keys.contains('name')) {
    throw const FormatException(
      'CSV header must include at least "cardNumber" and "name" columns',
    );
  }
  final result = <RegisterImportRow>[];
  for (var r = 1; r < rows.length; r++) {
    final values = rows[r];
    final map = <String, String>{};
    for (var c = 0; c < header.length; c++) {
      map[header[c]] = c < values.length ? values[c] : '';
    }
    result.add(registerRowFromMap(map, r, now: now, createdBy: createdBy));
  }
  return result;
}

/// Parses JSON in the register_2026.json format: either a list of patient
/// objects or an object with a "patients" list.
List<RegisterImportRow> parseRegisterJson(
  String text, {
  DateTime? now,
  String? createdBy,
}) {
  final decoded = jsonDecode(text);
  final List<dynamic> list;
  if (decoded is List) {
    list = decoded;
  } else if (decoded is Map && decoded['patients'] is List) {
    list = decoded['patients'] as List;
  } else {
    throw const FormatException(
      'JSON must be a list or contain a "patients" list',
    );
  }
  final result = <RegisterImportRow>[];
  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    if (item is! Map) {
      result.add(
        RegisterImportRow(rowNumber: i + 1, errors: ['Not an object']),
      );
      continue;
    }
    final map = <String, String>{
      for (final e in item.entries)
        e.key.toString(): e.value == null ? '' : e.value.toString(),
    };
    result.add(registerRowFromMap(map, i + 1, now: now, createdBy: createdBy));
  }
  return result;
}

/// Picks CSV or JSON automatically from the content.
List<RegisterImportRow> parseRegisterImport(
  String text, {
  DateTime? now,
  String? createdBy,
}) {
  final trimmed = text.trimLeft().replaceFirst('\uFEFF', '');
  if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
    return parseRegisterJson(trimmed, now: now, createdBy: createdBy);
  }
  return parseRegisterCsv(text, now: now, createdBy: createdBy);
}

/// Marks rows whose year/card key is already in [existingNormalized] or
/// appears earlier in the same file. Returns the number of duplicates.
int markDuplicates(
  List<RegisterImportRow> rows,
  Set<String> existingNormalized,
) {
  final seen = <String>{...existingNormalized};
  var count = 0;
  for (final row in rows) {
    final p = row.patient;
    if (p == null) continue;
    final key = p.cardKey;
    row.isDuplicate = seen.contains(key);
    if (row.isDuplicate) count++;
    seen.add(key);
  }
  return count;
}
