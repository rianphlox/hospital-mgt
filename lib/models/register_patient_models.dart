import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/patient_register_utils.dart';
import '../utils/register_age.dart';

export '../utils/register_age.dart' show AgeUnit, AgeUnitExtension;

/// Sex as recorded in the NHMIS attendance register (column 11 Male /
/// column 12 Female).
enum RegisterSex { male, female, unknown }

extension RegisterSexExtension on RegisterSex {
  String get displayName {
    switch (this) {
      case RegisterSex.male:
        return 'Male';
      case RegisterSex.female:
        return 'Female';
      case RegisterSex.unknown:
        return 'Unknown';
    }
  }

  /// Short code used in CSV files: M / F / blank.
  String get code {
    switch (this) {
      case RegisterSex.male:
        return 'M';
      case RegisterSex.female:
        return 'F';
      case RegisterSex.unknown:
        return '';
    }
  }

  static RegisterSex fromString(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    if (v == 'm' || v == 'male') return RegisterSex.male;
    if (v == 'f' || v == 'female') return RegisterSex.female;
    return RegisterSex.unknown;
  }
}

/// One person in the hospital's Patient Register (the NHMIS "Daily General
/// Attendance Register"). Stored in the `patient_register` collection.
///
/// This is separate from [Patient] in `patient_models.dart`, which is an
/// admission (in-patient / out-patient visit with a ward and bills). One
/// register record can have many admissions; an admission started from the
/// register carries `registerPatientId` and `cardNumber`.
class RegisterPatient {
  static const String collection = 'patient_register';

  final String id;

  /// Hospital card number (e.g. "B 50"). The primary key for finding a
  /// patient: required and unique within its register year.
  final String cardNumber;
  final int registerYear;
  final String name;

  /// Date of birth exactly as written (DD/MM/YY or DD/MM/YYYY).
  final String dateOfBirth;
  final RegisterSex sex;
  final int? age;
  final AgeUnit ageUnit;
  final String contactAddress;
  final String stateOfOrigin;
  final String phone;

  /// Column 16: first contact with the facility (Yes / No / not recorded).
  final bool? firstContact;
  final String nokName;
  final String nokRelationship;
  final String nokAddress;
  final String nokPhone;
  final DateTime? visitDate;
  final String lga;
  final String ward;
  final String facility;
  final bool needsReview;
  final String reviewNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  RegisterPatient({
    required this.id,
    required this.cardNumber,
    int? registerYear,
    required this.name,
    this.dateOfBirth = '',
    this.sex = RegisterSex.unknown,
    this.age,
    this.ageUnit = AgeUnit.years,
    this.contactAddress = '',
    this.stateOfOrigin = '',
    this.phone = '',
    this.firstContact,
    this.nokName = '',
    this.nokRelationship = '',
    this.nokAddress = '',
    this.nokPhone = '',
    this.visitDate,
    this.lga = '',
    this.ward = '',
    this.facility = '',
    this.needsReview = false,
    this.reviewNotes = '',
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
  }) : registerYear = registerYear ?? visitDate?.year ?? createdAt.year;

  /// Stable duplicate key: a card can be reused in a different year.
  String get cardKey => registerCardKey(registerYear, cardNumber);

  String get cardNumberNormalized => normalizeCardNumber(cardNumber);
  String get nameLower => name.trim().toLowerCase();
  List<String> get nameSearchKeys => buildNameSearchKeys(name);

  /// Age in whole years, retained in stored records. Babies recorded in days or
  /// months count as 0 (or months ~/ 12).
  int? get ageYears {
    if (age == null) return null;
    switch (ageUnit) {
      case AgeUnit.days:
        return 0;
      case AgeUnit.months:
        return age! ~/ 12;
      case AgeUnit.years:
        return age;
    }
  }

  /// Age as stored, or, when no age was recorded, worked out from the date
  /// of birth on the visit date (today if there is none). Computed on read
  /// for display only; nothing is written back.
  CalculatedAge? get effectiveAge {
    if (age != null) return CalculatedAge(age!, ageUnit);
    return calculateAgeFromText(dateOfBirth, visitDate ?? DateTime.now());
  }

  /// True when [effectiveAge] came from the date of birth, not a stored age.
  bool get isAgeCalculated => age == null && effectiveAge != null;

  String get ageDisplay {
    final a = effectiveAge;
    if (a == null) return '-';
    final n = a.value;
    switch (a.unit) {
      case AgeUnit.days:
        return '$n day${n == 1 ? '' : 's'}';
      case AgeUnit.months:
        return '$n month${n == 1 ? '' : 's'}';
      case AgeUnit.years:
        return '$n yr${n == 1 ? '' : 's'}';
    }
  }

  String get firstContactDisplay =>
      firstContact == null ? '-' : (firstContact! ? 'Yes' : 'No');

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  factory RegisterPatient.fromJson(Map<String, dynamic> json, String id) {
    final unit = AgeUnitExtension.fromString(json['ageUnit'] as String?);
    final age = (json['age'] as num?)?.toInt();
    return RegisterPatient(
      id: id,
      cardNumber: json['cardNumber'] as String? ?? '',
      registerYear: int.tryParse(
        '${json['registerYear'] ?? json['year'] ?? ''}',
      ),
      name: json['name'] as String? ?? '',
      dateOfBirth: json['dateOfBirth'] as String? ?? '',
      sex: RegisterSexExtension.fromString(json['sex'] as String?),
      age: age,
      ageUnit: unit,
      contactAddress: json['contactAddress'] as String? ?? '',
      stateOfOrigin: json['stateOfOrigin'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      firstContact: json['firstContact'] as bool?,
      nokName: json['nokName'] as String? ?? '',
      nokRelationship: json['nokRelationship'] as String? ?? '',
      nokAddress: json['nokAddress'] as String? ?? '',
      nokPhone: json['nokPhone'] as String? ?? '',
      visitDate: _toDate(json['visitDate']),
      lga: json['lga'] as String? ?? '',
      ward: json['ward'] as String? ?? '',
      facility: json['facility'] as String? ?? '',
      needsReview: json['needsReview'] as bool? ?? false,
      reviewNotes: json['reviewNotes'] as String? ?? '',
      createdAt: _toDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _toDate(json['updatedAt']),
      createdBy: json['createdBy'] as String?,
    );
  }

  /// Firestore document. Includes derived card/name search fields and
  /// whole-year age for compatibility with existing records.
  Map<String, dynamic> toJson() {
    return {
      'cardNumber': cardNumber.trim(),
      'registerYear': registerYear,
      'cardNumberNormalized': cardNumberNormalized,
      'name': name.trim(),
      'nameLower': nameLower,
      'nameSearchKeys': nameSearchKeys,
      'dateOfBirth': dateOfBirth.trim(),
      'sex': sex.name,
      'age': age,
      'ageUnit': ageUnit.name,
      'ageYears': ageYears,
      'contactAddress': contactAddress.trim(),
      'stateOfOrigin': stateOfOrigin.trim(),
      'phone': phone.trim(),
      'firstContact': firstContact,
      'nokName': nokName.trim(),
      'nokRelationship': nokRelationship.trim(),
      'nokAddress': nokAddress.trim(),
      'nokPhone': nokPhone.trim(),
      'visitDate': visitDate != null ? Timestamp.fromDate(visitDate!) : null,
      'lga': lga.trim(),
      'ward': ward.trim(),
      'facility': facility.trim(),
      'needsReview': needsReview,
      'reviewNotes': reviewNotes.trim(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
    };
  }

  RegisterPatient copyWith({
    String? id,
    String? cardNumber,
    int? registerYear,
    String? name,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return RegisterPatient(
      id: id ?? this.id,
      cardNumber: cardNumber ?? this.cardNumber,
      registerYear: registerYear ?? this.registerYear,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth,
      sex: sex,
      age: age,
      ageUnit: ageUnit,
      contactAddress: contactAddress,
      stateOfOrigin: stateOfOrigin,
      phone: phone,
      firstContact: firstContact,
      nokName: nokName,
      nokRelationship: nokRelationship,
      nokAddress: nokAddress,
      nokPhone: nokPhone,
      visitDate: visitDate,
      lga: lga,
      ward: ward,
      facility: facility,
      needsReview: needsReview,
      reviewNotes: reviewNotes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
