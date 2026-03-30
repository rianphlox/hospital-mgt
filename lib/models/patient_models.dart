import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_models.dart';

enum PatientType { inPatient, outPatient }
enum PatientStatus { active, discharged }

extension PatientTypeExtension on PatientType {
  String get displayName {
    switch (this) {
      case PatientType.inPatient:
        return 'In-patient';
      case PatientType.outPatient:
        return 'Out-patient';
    }
  }

  static PatientType fromString(String value) {
    switch (value) {
      case 'In-patient':
        return PatientType.inPatient;
      case 'Out-patient':
        return PatientType.outPatient;
      default:
        return PatientType.inPatient;
    }
  }
}

class Patient {
  final String id;
  final String name;
  final String admissionNumber;
  final String ward;
  final PatientType type;
  final PatientStatus status;
  final DateTime createdAt;
  final DateTime? dischargedAt;
  final int outstandingBalance; // Total unpaid balance across all visits

  Patient({
    required this.id,
    required this.name,
    required this.admissionNumber,
    required this.ward,
    required this.type,
    required this.status,
    required this.createdAt,
    this.dischargedAt,
    this.outstandingBalance = 0,
  });

  factory Patient.fromJson(Map<String, dynamic> json, String id) {
    return Patient(
      id: id,
      name: json['name'] as String,
      admissionNumber: json['admissionNumber'] as String,
      ward: json['ward'] as String,
      type: PatientTypeExtension.fromString(json['type'] as String),
      status: PatientStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PatientStatus.active,
      ),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      dischargedAt: json['dischargedAt'] != null
          ? (json['dischargedAt'] as Timestamp).toDate()
          : null,
      outstandingBalance: json['outstandingBalance'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'admissionNumber': admissionNumber,
      'ward': ward,
      'type': type.displayName,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'dischargedAt': dischargedAt != null
          ? Timestamp.fromDate(dischargedAt!)
          : null,
      'outstandingBalance': outstandingBalance,
    };
  }

  Patient copyWith({
    String? id,
    String? name,
    String? admissionNumber,
    String? ward,
    PatientType? type,
    PatientStatus? status,
    DateTime? createdAt,
    DateTime? dischargedAt,
    int? outstandingBalance,
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      admissionNumber: admissionNumber ?? this.admissionNumber,
      ward: ward ?? this.ward,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      dischargedAt: dischargedAt ?? this.dischargedAt,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
    );
  }
}

class TreatmentItem {
  final String name;
  final int quantity;
  final int unitPrice; // 0 when pending pricing, set by admin
  final String dosage; // e.g., "500mg", "2 tablets"
  final String instructions; // e.g., "Take after meals", "IV slowly"

  TreatmentItem({
    required this.name,
    required this.quantity,
    this.unitPrice = 0, // Default to 0 for nurse entries
    this.dosage = '',
    this.instructions = '',
  });

  factory TreatmentItem.fromJson(Map<String, dynamic> json) {
    return TreatmentItem(
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      unitPrice: json['unitPrice'] as int? ?? 0,
      dosage: json['dosage'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'dosage': dosage,
      'instructions': instructions,
    };
  }

  int get totalPrice => quantity * unitPrice;
}

enum TreatmentPricingStatus {
  pending,    // Nurse logged but admin hasn't priced
  priced,     // Admin has set pricing
  billed,     // Cashier has billed patient
}

extension TreatmentPricingStatusExtension on TreatmentPricingStatus {
  String get displayName {
    switch (this) {
      case TreatmentPricingStatus.pending:
        return 'Pending Pricing';
      case TreatmentPricingStatus.priced:
        return 'Priced';
      case TreatmentPricingStatus.billed:
        return 'Billed';
    }
  }
}

class Treatment {
  final String id;
  final String patientId;
  final String nurseId;
  final String nurseName;
  final List<TreatmentItem> items;
  final int totalCharge;
  final DateTime timestamp;
  final NursingShift? shift;
  final TreatmentPricingStatus pricingStatus;
  final String? adminId;
  final String? adminName;
  final DateTime? pricedAt;

  Treatment({
    required this.id,
    required this.patientId,
    required this.nurseId,
    required this.nurseName,
    required this.items,
    required this.totalCharge,
    required this.timestamp,
    this.shift,
    this.pricingStatus = TreatmentPricingStatus.pending,
    this.adminId,
    this.adminName,
    this.pricedAt,
  });

  factory Treatment.fromJson(Map<String, dynamic> json, String id) {
    return Treatment(
      id: id,
      patientId: json['patientId'] as String,
      nurseId: json['nurseId'] as String,
      nurseName: json['nurseName'] as String,
      items: (json['items'] as List)
          .map((item) => TreatmentItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalCharge: json['totalCharge'] as int? ?? 0,
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      shift: json['shift'] != null
          ? NursingShift.values.firstWhere(
              (s) => s.name == json['shift'],
              orElse: () => NursingShiftExtension.getCurrentShift(),
            )
          : null,
      pricingStatus: json['pricingStatus'] != null
          ? TreatmentPricingStatus.values.firstWhere(
              (status) => status.name == json['pricingStatus'],
              orElse: () => TreatmentPricingStatus.pending,
            )
          : TreatmentPricingStatus.pending,
      adminId: json['adminId'] as String?,
      adminName: json['adminName'] as String?,
      pricedAt: json['pricedAt'] != null
          ? (json['pricedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patientId': patientId,
      'nurseId': nurseId,
      'nurseName': nurseName,
      'items': items.map((item) => item.toJson()).toList(),
      'totalCharge': totalCharge,
      'timestamp': Timestamp.fromDate(timestamp),
      'shift': shift?.name,
      'pricingStatus': pricingStatus.name,
      'adminId': adminId,
      'adminName': adminName,
      'pricedAt': pricedAt != null ? Timestamp.fromDate(pricedAt!) : null,
    };
  }
}

enum PaymentType { full, partial }

class Payment {
  final String id;
  final String patientId;
  final String cashierId;
  final String cashierName;
  final int amount;
  final String paymentMethod;
  final DateTime timestamp;
  final PaymentType paymentType;
  final int? originalBillAmount; // For partial payments
  final String? notes; // Payment notes

  Payment({
    required this.id,
    required this.patientId,
    required this.cashierId,
    required this.cashierName,
    required this.amount,
    required this.paymentMethod,
    required this.timestamp,
    this.paymentType = PaymentType.full,
    this.originalBillAmount,
    this.notes,
  });

  factory Payment.fromJson(Map<String, dynamic> json, String id) {
    return Payment(
      id: id,
      patientId: json['patientId'] as String,
      cashierId: json['cashierId'] as String,
      cashierName: json['cashierName'] as String,
      amount: json['amount'] as int,
      paymentMethod: json['paymentMethod'] as String,
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      paymentType: PaymentType.values.firstWhere(
        (type) => type.name == json['paymentType'],
        orElse: () => PaymentType.full,
      ),
      originalBillAmount: json['originalBillAmount'] as int?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patientId': patientId,
      'cashierId': cashierId,
      'cashierName': cashierName,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'timestamp': Timestamp.fromDate(timestamp),
      'paymentType': paymentType.name,
      'originalBillAmount': originalBillAmount,
      'notes': notes,
    };
  }
}

class DebtForgiveness {
  final String id;
  final String patientId;
  final String adminId;
  final String adminName;
  final int forgivenAmount;
  final String reason;
  final DateTime timestamp;

  DebtForgiveness({
    required this.id,
    required this.patientId,
    required this.adminId,
    required this.adminName,
    required this.forgivenAmount,
    required this.reason,
    required this.timestamp,
  });

  factory DebtForgiveness.fromJson(Map<String, dynamic> json, String id) {
    return DebtForgiveness(
      id: id,
      patientId: json['patientId'] as String,
      adminId: json['adminId'] as String,
      adminName: json['adminName'] as String,
      forgivenAmount: json['forgivenAmount'] as int,
      reason: json['reason'] as String,
      timestamp: (json['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patientId': patientId,
      'adminId': adminId,
      'adminName': adminName,
      'forgivenAmount': forgivenAmount,
      'reason': reason,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class QuickDrug {
  final String name;
  final int price;

  const QuickDrug({
    required this.name,
    required this.price,
  });

  static const List<QuickDrug> defaultDrugs = [
    // IV Fluids
    QuickDrug(name: 'Normal Saline', price: 1500),
    QuickDrug(name: 'Ringer\'s Lactate', price: 1800),
    QuickDrug(name: 'Darrow\'s Full Strength', price: 2500),
    QuickDrug(name: 'Glucose 5%', price: 1500),
    QuickDrug(name: 'Glucose 10%', price: 1800),

    // Antibiotics
    QuickDrug(name: 'Ceftriaxone 1g', price: 4500),
    QuickDrug(name: 'Metronidazole (Metro)', price: 1200),
    QuickDrug(name: 'Ciprofloxacin', price: 2000),
    QuickDrug(name: 'Amoxicillin', price: 800),
    QuickDrug(name: 'Cefuroxime', price: 3500),

    // Pain & Anti-inflammatory
    QuickDrug(name: 'Paracetamol IV', price: 3000),
    QuickDrug(name: 'Diclofenac 75mg', price: 1800),
    QuickDrug(name: 'Tramadol 50mg', price: 2200),
    QuickDrug(name: 'Ibuprofen', price: 1200),
    QuickDrug(name: 'Morphine 10mg', price: 5000),

    // Emergency Drugs
    QuickDrug(name: 'Adrenaline 1mg', price: 8000),
    QuickDrug(name: 'Hydrocortisone', price: 3500),
    QuickDrug(name: 'Atropine', price: 2500),
    QuickDrug(name: 'Furosemide', price: 1500),

    // Others
    QuickDrug(name: 'Vitamin B Complex', price: 1000),
    QuickDrug(name: 'Vitamin C', price: 800),
    QuickDrug(name: 'Oxygen Therapy', price: 5000),
    QuickDrug(name: 'Blood Test', price: 3000),
    QuickDrug(name: 'X-Ray', price: 8000),
  ];
}