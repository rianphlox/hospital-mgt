import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/register_patient_models.dart';
import '../utils/patient_register_utils.dart';
import 'firebase_service.dart';

/// How the Patient Register search box should interpret its text.
enum RegisterSearchMode { cardNumber, name, age }

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
/// Searches only use single-field filters (equality, range, or
/// array-contains), which Firestore indexes automatically, so no composite
/// indexes are needed.
class PatientRegisterService {
  static FirebaseFirestore get _firestore => FirebaseService.firestore;

  static CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(RegisterPatient.collection);

  static const int _maxResults = 50;

  static List<RegisterPatient> _fromSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
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
    final existing = await findByCardNumber(patient.cardNumber);
    if (existing != null) {
      throw StateError(
          'Card number ${patient.cardNumber} already belongs to ${existing.name}');
    }
    try {
      final data = patient.toJson();
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _collection.add(data);
      return ref.id;
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.create, RegisterPatient.collection);
      rethrow;
    }
  }

  /// Updates an existing record (search fields are rebuilt from the new values).
  static Future<void> updatePatient(RegisterPatient patient) async {
    _checkCardNumber(patient.cardNumber);
    final existing = await findByCardNumber(patient.cardNumber);
    if (existing != null && existing.id != patient.id) {
      throw StateError(
          'Card number ${patient.cardNumber} already belongs to ${existing.name}');
    }
    try {
      final data = patient.toJson();
      data.remove('createdAt');
      data.remove('createdBy');
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _collection.doc(patient.id).update(data);
    } catch (e) {
      FirebaseService.handleFirestoreError(
          e, OperationType.update, '${RegisterPatient.collection}/${patient.id}');
    }
  }

  static Future<RegisterPatient?> getPatient(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) return null;
      return RegisterPatient.fromJson(doc.data()!, doc.id);
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.get, '${RegisterPatient.collection}/$id');
      return null;
    }
  }

  static Future<RegisterPatient?> findByCardNumber(String cardNumber) async {
    final normalized = normalizeCardNumber(cardNumber);
    if (normalized.isEmpty) return null;
    final snapshot = await _collection
        .where('cardNumberNormalized', isEqualTo: normalized)
        .limit(1)
        .get();
    final list = _fromSnapshot(snapshot);
    return list.isEmpty ? null : list.first;
  }

  /// Returns which of [normalizedCards] already exist in Firestore.
  static Future<Set<String>> existingCardNumbers(Iterable<String> normalizedCards) async {
    final cards = normalizedCards.where((c) => c.isNotEmpty).toSet().toList();
    final found = <String>{};
    // Firestore allows at most 30 values in a whereIn filter.
    for (var i = 0; i < cards.length; i += 30) {
      final chunk = cards.sublist(i, i + 30 > cards.length ? cards.length : i + 30);
      final snapshot = await _collection.where('cardNumberNormalized', whereIn: chunk).get();
      for (final doc in snapshot.docs) {
        final value = doc.data()['cardNumberNormalized'];
        if (value is String) found.add(value);
      }
    }
    return found;
  }

  /// Card number search: exact match first, then card numbers that start
  /// with the typed text ("B5" finds B 50 ... B 59).
  static Future<List<RegisterPatient>> searchByCardNumber(String query) async {
    final normalized = normalizeCardNumber(query);
    if (normalized.isEmpty) return [];
    try {
      final snapshot = await _collection
          .orderBy('cardNumberNormalized')
          .startAt([normalized])
          .endAt(['$normalized\uf8ff'])
          .limit(_maxResults)
          .get();
      final results = _fromSnapshot(snapshot);
      results.sort((a, b) {
        final aExact = a.cardNumberNormalized == normalized ? 0 : 1;
        final bExact = b.cardNumberNormalized == normalized ? 0 : 1;
        if (aExact != bExact) return aExact - bExact;
        return _compareCards(a.cardNumberNormalized, b.cardNumberNormalized);
      });
      return results;
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.list, RegisterPatient.collection);
      return [];
    }
  }

  /// Name search: case-insensitive, matches the start of any part of the
  /// name. Every typed word must match ("jane do" finds "Jane Doe").
  static Future<List<RegisterPatient>> searchByName(String query) async {
    final words = nameWords(query);
    if (words.isEmpty) return [];
    // Query on the longest word (most selective), filter the rest locally.
    final key = words.reduce((a, b) => b.length > a.length ? b : a);
    try {
      final snapshot = await _collection
          .where('nameSearchKeys', arrayContains: key)
          .limit(200)
          .get();
      final results = _fromSnapshot(snapshot)
          .where((p) => nameMatchesQuery(p.name, query))
          .toList()
        ..sort((a, b) => a.nameLower.compareTo(b.nameLower));
      return results.take(_maxResults).toList();
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.list, RegisterPatient.collection);
      return [];
    }
  }

  /// Age search in whole years: a single age ("45") or a range ("40-50",
  /// "60+", "<5"). Babies recorded in days/months count as age 0.
  static Future<List<RegisterPatient>> searchByAge(AgeRange range) async {
    try {
      Query<Map<String, dynamic>> query = _collection;
      if (range.min == range.max) {
        query = query.where('ageYears', isEqualTo: range.min);
      } else {
        query = query
            .where('ageYears', isGreaterThanOrEqualTo: range.min)
            .where('ageYears', isLessThanOrEqualTo: range.max)
            .orderBy('ageYears');
      }
      final snapshot = await query.limit(200).get();
      final results = _fromSnapshot(snapshot)
        ..sort((a, b) {
          final byAge = (a.ageYears ?? 0).compareTo(b.ageYears ?? 0);
          return byAge != 0 ? byAge : a.nameLower.compareTo(b.nameLower);
        });
      return results;
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.list, RegisterPatient.collection);
      return [];
    }
  }

  static Future<List<RegisterPatient>> search(String text, RegisterSearchMode mode) async {
    switch (mode) {
      case RegisterSearchMode.cardNumber:
        return searchByCardNumber(text);
      case RegisterSearchMode.name:
        return searchByName(text);
      case RegisterSearchMode.age:
        final range = AgeRange.parse(text);
        return range == null ? [] : searchByAge(range);
    }
  }

  /// Most recently added register records, for the screen's default list.
  static Future<List<RegisterPatient>> recentPatients({int limit = 30}) async {
    try {
      final snapshot = await _collection
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return _fromSnapshot(snapshot);
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.list, RegisterPatient.collection);
      return [];
    }
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
    final existing = await existingCardNumbers(patients.map((p) => p.cardNumberNormalized));
    final seen = <String>{...existing};
    final toWrite = <RegisterPatient>[];
    var duplicates = 0;
    var invalid = 0;
    for (final p in patients) {
      final key = p.cardNumberNormalized;
      if (key.isEmpty || p.name.trim().isEmpty) {
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
      FirebaseService.handleFirestoreError(e, OperationType.write, RegisterPatient.collection);
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
