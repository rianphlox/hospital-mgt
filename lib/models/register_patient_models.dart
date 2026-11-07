import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/patient_register_utils.dart';

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

/// Unit the age number was written in.
enum AgeUnit { days, months, years }

extension AgeUnitExtension on AgeUnit {
  static AgeUnit fromString(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    if (v.startsWith('d')) return AgeUnit.days;
    if (v.startsWith('m')) return AgeUnit.months;
    return AgeUnit.years;
  }
}

/// The six NHMIS age bands printed on the register.
enum AgeBand {
  days0to28,
  days29toMonths11,
  months12to59,
  years5to9,
  years10to19,
  years20plus,
}

extension AgeBandExtension on AgeBand {
  String get label {
    switch (this) {
      case AgeBand.days0to28:
        return '0-28 days';
      case AgeBand.days29toMonths11:
        return '29 days-11 months';
      case AgeBand.months12to59:
        return '12-59 months';
      case AgeBand.years5to9:
        return '5-9 years';
      case AgeBand.years10to19:
        return '10-19 years';
      case AgeBand.years20plus:
        return '>=20 years';
    }
  }

  static AgeBand? fromLabel(String? value) {
    final v = (value ?? '')
        .toLowerCase()
        .replaceAll('≥', '>=')
        .replaceAll(' ', '')
        .replaceAll('–', '-');
    if (v.isEmpty) return null;
    for (final band in AgeBand.values) {
      if (band.label.replaceAll(' ', '') == v || band.name.toLowerCase() == v) {
        return band;
      }
    }
    if (v.contains('20')) return AgeBand.years20plus;
    return null;
  }

  /// Works out the band from an age number and its unit.
  static AgeBand? fromAge(int? age, AgeUnit unit) {
    if (age == null) return null;
    switch (unit) {
      case AgeUnit.days:
        return age <= 28 ? AgeBand.days0to28 : AgeBand.days29toMonths11;
      case AgeUnit.months:
        if (age < 12) return AgeBand.days29toMonths11;
        if (age < 60) return AgeBand.months12to59;
        return fromAge(age ~/ 12, AgeUnit.years);
      case AgeUnit.years:
        if (age < 5) return AgeBand.months12to59;
        if (age < 10) return AgeBand.years5to9;
        if (age < 20) return AgeBand.years10to19;
        return AgeBand.years20plus;
    }
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
  final String cardNumber;
  final String name;

  /// Date of birth exactly as written (DD/MM/YY or DD/MM/YYYY).
  final String dateOfBirth;
  final RegisterSex sex;
  final int? age;
  final AgeUnit ageUnit;
  final AgeBand? ageBand;
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
  final int? serialNo;
  final bool needsReview;
  final String reviewNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  RegisterPatient({
    required this.id,
    required this.cardNumber,
    required this.name,
    this.dateOfBirth = '',
    this.sex = RegisterSex.unknown,
    this.age,
    this.ageUnit = AgeUnit.years,
    AgeBand? ageBand,
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
    this.serialNo,
    this.needsReview = false,
    this.reviewNotes = '',
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
  }) : ageBand = ageBand ?? AgeBandExtension.fromAge(age, ageUnit);

  String get cardNumberNormalized => normalizeCardNumber(cardNumber);
  String get nameLower => name.trim().toLowerCase();
  List<String> get nameSearchKeys => buildNameSearchKeys(name);

  /// Age in whole years, used for age searches. Babies recorded in days or
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

  String get ageDisplay {
    if (age == null) return '-';
    switch (ageUnit) {
      case AgeUnit.days:
        return '$age day${age == 1 ? '' : 's'}';
      case AgeUnit.months:
        return '$age month${age == 1 ? '' : 's'}';
      case AgeUnit.years:
        return '$age yr${age == 1 ? '' : 's'}';
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
      name: json['name'] as String? ?? '',
      dateOfBirth: json['dateOfBirth'] as String? ?? '',
      sex: RegisterSexExtension.fromString(json['sex'] as String?),
      age: age,
      ageUnit: unit,
      ageBand: AgeBandExtension.fromLabel(json['ageBand'] as String?),
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
      serialNo: (json['serialNo'] as num?)?.toInt(),
      needsReview: json['needsReview'] as bool? ?? false,
      reviewNotes: json['reviewNotes'] as String? ?? '',
      createdAt: _toDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _toDate(json['updatedAt']),
      createdBy: json['createdBy'] as String?,
    );
  }

  /// Firestore document. Includes the derived search fields
  /// (`cardNumberNormalized`, `nameLower`, `nameSearchKeys`, `ageYears`).
  Map<String, dynamic> toJson() {
    return {
      'cardNumber': cardNumber.trim(),
      'cardNumberNormalized': cardNumberNormalized,
      'name': name.trim(),
      'nameLower': nameLower,
      'nameSearchKeys': nameSearchKeys,
      'dateOfBirth': dateOfBirth.trim(),
      'sex': sex.name,
      'age': age,
      'ageUnit': ageUnit.name,
      'ageYears': ageYears,
      'ageBand': ageBand?.label,
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
      'serialNo': serialNo,
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
    String? name,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return RegisterPatient(
      id: id ?? this.id,
      cardNumber: cardNumber ?? this.cardNumber,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth,
      sex: sex,
      age: age,
      ageUnit: ageUnit,
      ageBand: ageBand,
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
      serialNo: serialNo,
      needsReview: needsReview,
      reviewNotes: reviewNotes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
