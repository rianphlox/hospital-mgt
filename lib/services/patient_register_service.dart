import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/register_patient_models.dart';
import '../utils/patient_register_utils.dart';
import 'firebase_service.dart';

/// How the Patient Register search box should interpret its text.
enum RegisterSearchMode { cardNumber, name }

/// Result of a batch import.
class RegisterImportResult {
  final int imported;
  final int skippedDuplicates;
  final int skippedInvalid;

  const RegisterImportResult({
    required this.imported,
    required this.skippedDuplicates,
    required this.skippedInvalid,
  });
}

/// Firestore access for the `patient_register` collection.
///
/// Searches combine registerYear with card/name filters. See
/// firestore.indexes.json. A read-only legacy fallback includes documents
/// without registerYear until they are edited with a year.
class PatientRegisterService {
  static FirebaseFirestore get _firestore => FirebaseService.firestore;

  static CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(RegisterPatient.collection);

  static const int _maxResults = 50;

  static List<RegisterPatient> _fromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((doc) => RegisterPatient.fromJson(doc.data(), doc.id))
        .toList();
  }

  /// Card number is required and must be valid; throws [StateError] if not.
  static void _checkCardNumber(String cardNumber) {
    final error = validateCardNumber(cardNumber);
    if (error != null) throw StateError(error);
  }

  /// Creates a register record. Throws [StateError] if the card number is
  /// already used by another patient.
  static Future<String> createPatient(RegisterPatient patient) async {
    _checkCardNumber(patient.cardNumber);
    final existing = await findByCardNumber(
      patient.cardNumber,
      year: patient.registerYear,
    );
    if (existing != null) {
      throw StateError(
        'Card number ${patient.cardNumber} in ${patient.registerYear} already belongs to ${existing.name}',
      );
    }
    try {
      final data = patient.toJson();
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _collection.add(data);
      return ref.id;
    } catch (e) {
      FirebaseService.handleFirestoreError(
        e,
        OperationType.create,
        RegisterPatient.collection,
      );
      rethrow;
    }
  }

  /// Updates an existing record (search fields are rebuilt from the new values).
  static Future<void> updatePatient(RegisterPatient patient) async {
    _checkCardNumber(patient.cardNumber);
    final existing = await findByCardNumber(
      patient.cardNumber,
      year: patient.registerYear,
    );
    if (existing != null && existing.id != patient.id) {
      throw StateError(
        'Card number ${patient.cardNumber} in ${patient.registerYear} already belongs to ${existing.name}',
      );
    }
    try {
      final data = patient.toJson();
      data.remove('createdAt');
      data.remove('createdBy');
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _collection.doc(patient.id).update(data);
    } catch (e) {
      FirebaseService.handleFirestoreError(
        e,
        OperationType.update,
        '${RegisterPatient.collection}/${patient.id}',
      );
    }
  }

  static Future<RegisterPatient?> getPatient(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) return null;
      return RegisterPatient.fromJson(doc.data()!, doc.id);
    } catch (e) {
      FirebaseService.handleFirestoreError(
        e,
        OperationType.get,
        '${RegisterPatient.collection}/$id',
      );
      return null;
    }
  }

  static Future<RegisterPatient?> findByCardNumber(
    String cardNumber, {
    int? year,
  }) async {
    final normalized = normalizeCardNumber(cardNumber);
    if (normalized.isEmpty) return null;
    // Do not limit before deriving legacy years: a card may occur in many years.
    final snapshot = await _collection
        .where('cardNumberNormalized', isEqualTo: normalized)
        .get();
    final list = filterByYear(
      _fromSnapshot(snapshot),
      year ?? DateTime.now().year,
    );
    return list.isEmpty ? null : list.first;
  }

  /// Returns existing year/card keys, not globally unique card numbers.
  static Future<Set<String>> existingCardNumbers(
    Iterable<RegisterPatient> patients,
  ) async {
    final requested = patients.map((p) => p.cardKey).toSet();
    final cards = patients.map((p) => p.cardNumberNormalized).toSet().toList();
    final found = <String>{};
    for (var i = 0; i < cards.length; i += 30) {
      final chunk = cards.sublist(
        i,
        i + 30 > cards.length ? cards.length : i + 30,
      );
      final snapshot = await _collection
          .where('cardNumberNormalized', whereIn: chunk)
          .get();
      for (final patient in _fromSnapshot(snapshot)) {
        if (requested.contains(patient.cardKey)) found.add(patient.cardKey);
      }
    }
    return found;
  }

  static List<RegisterPatient> filterByYear(
    Iterable<RegisterPatient> patients,
    int? year,
  ) =>
      patients.where((p) => matchesRegisterYear(p.registerYear, year)).toList();

  /// Includes derived years of legacy documents. This full read is needed
  /// because Firestore cannot query a field that does not exist.
  static Future<List<int>> availableYears() async {
    final snapshot = await _collection.get();
    return {
      ..._fromSnapshot(snapshot).map((p) => p.registerYear),
      DateTime.now().year,
    }.toList()..sort((a, b) => b.compareTo(a));
  }

  static Future<List<RegisterPatient>> _queryForYear(
    Query<Map<String, dynamic>> query,
    int? year,
  ) async {
    if (year == null) return _fromSnapshot(await query.get());
    final scoped = await query.where('registerYear', isEqualTo: year).get();
    // Missing fields are not matched by where(null). Use the same indexed
    // card/name query without a year, then retain ONLY legacy documents.
    // No limit before year/name filtering: old years must not crowd out matches.
    final legacy = await query.get();
    return [
      ..._fromSnapshot(scoped),
      ...legacy.docs
          .where((doc) => doc.data()['registerYear'] == null)
          .map((doc) => RegisterPatient.fromJson(doc.data(), doc.id))
          .where((p) => matchesRegisterYear(p.registerYear, year)),
    ];
  }

  /// Card number search: exact match first, then card numbers that start
  /// with the typed text ("B5" finds B 50 ... B 59).
  static Future<List<RegisterPatient>> searchByCardNumber(
    String query, {
    int? year,
  }) async {
    final normalized = normalizeCardNumber(query);
    if (normalized.isEmpty) return [];
    try {
      final cardQuery = _collection
          .orderBy('cardNumberNormalized')
          .startAt([normalized])
          .endAt(['$normalized\uf8ff']);
      final results = await _queryForYear(cardQuery, year);
      results.sort((a, b) {
        final aExact = a.cardNumberNormalized == normalized ? 0 : 1;
        final bExact = b.cardNumberNormalized == normalized ? 0 : 1;
        if (aExact != bExact) return aExact - bExact;
        return _compareCards(a.cardNumberNormalized, b.cardNumberNormalized);
      });
      return results.take(_maxResults).toList();
    } catch (e) {
      FirebaseService.handleFirestoreError(
        e,
        OperationType.list,
        RegisterPatient.collection,
      );
      rethrow;
    }
  }

  /// Name search: case-insensitive, matches the start of any part of the
  /// name. Every typed word must match ("jane do" finds "Jane Doe").
  static Future<List<RegisterPatient>> searchByName(
    String query, {
    int? year,
  }) async {
    final words = nameWords(query);
    if (words.isEmpty) return [];
    // Query on the longest word (most selective), filter the rest locally.
    final key = words.reduce((a, b) => b.length > a.length ? b : a);
    try {
      final results =
          (await _queryForYear(
              _collection.where('nameSearchKeys', arrayContains: key),
              year,
            )).where((p) => nameMatchesQuery(p.name, query)).toList()
            ..sort((a, b) => a.nameLower.compareTo(b.nameLower));
      return results.take(_maxResults).toList();
    } catch (e) {
      FirebaseService.handleFirestoreError(
        e,
        OperationType.list,
        RegisterPatient.collection,
      );
      rethrow;
    }
  }

  static Future<List<RegisterPatient>> search(
    String text,
    RegisterSearchMode mode, {
    int? year,
  }) async {
    switch (mode) {
      case RegisterSearchMode.cardNumber:
        return searchByCardNumber(text, year: year);
      case RegisterSearchMode.name:
        return searchByName(text, year: year);
    }
  }

  /// Most recently added register records, for the screen's default list.
  static Future<List<RegisterPatient>> recentPatients({
    int limit = 30,
    int? year,
  }) async {
    final results = await _queryForYear(_collection, year);
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results.take(limit).toList();
  }

  static Future<int> countPatients() async {
    try {
      final aggregate = await _collection.count().get();
      return aggregate.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Writes many register records, skipping any whose card number already
  /// exists in Firestore or earlier in [patients]. Uses batched writes of
  /// up to 400 documents.
  static Future<RegisterImportResult> importPatients(
    List<RegisterPatient> patients, {
    String? createdBy,
  }) async {
    final existing = await existingCardNumbers(patients);
    final seen = <String>{...existing};
    final toWrite = <RegisterPatient>[];
    var duplicates = 0;
    var invalid = 0;
    for (final p in patients) {
      final key = p.cardKey;
      if (validateCardNumber(p.cardNumber) != null || p.name.trim().isEmpty) {
        invalid++;
        continue;
      }
      if (seen.contains(key)) {
        duplicates++;
        continue;
      }
      seen.add(key);
      toWrite.add(p);
    }

    try {
      for (var i = 0; i < toWrite.length; i += 400) {
        final batch = _firestore.batch();
        final end = i + 400 > toWrite.length ? toWrite.length : i + 400;
        for (final p in toWrite.sublist(i, end)) {
          final data = p.toJson();
          data['createdAt'] = FieldValue.serverTimestamp();
          if (createdBy != null) data['createdBy'] = createdBy;
          data['importedAt'] = FieldValue.serverTimestamp();
          batch.set(_collection.doc(), data);
        }
        await batch.commit();
      }
    } catch (e) {
      FirebaseService.handleFirestoreError(
        e,
        OperationType.write,
        RegisterPatient.collection,
      );
    }

    return RegisterImportResult(
      imported: toWrite.length,
      skippedDuplicates: duplicates,
      skippedInvalid: invalid,
    );
  }

  /// Orders "B9" before "B10" (letters, then number).
  static int _compareCards(String a, String b) {
    final re = RegExp(r'^([A-Z]*)(\d*)(.*)$');
    final ma = re.firstMatch(a)!;
    final mb = re.firstMatch(b)!;
    final prefix = ma.group(1)!.compareTo(mb.group(1)!);
    if (prefix != 0) return prefix;
    final na = int.tryParse(ma.group(2)!) ?? 0;
    final nb = int.tryParse(mb.group(2)!) ?? 0;
    if (na != nb) return na.compareTo(nb);
    return a.compareTo(b);
  }
}
