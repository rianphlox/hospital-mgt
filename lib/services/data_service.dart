import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/patient_models.dart';
import '../services/firebase_service.dart';

class DataService {
  static final FirebaseFirestore _firestore = FirebaseService.firestore;

  // Patient operations
  static Future<void> createPatient(Patient patient) async {
    try {
      await _firestore.collection('patients').add(patient.toJson());
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.create, 'patients');
    }
  }

  static Stream<List<Patient>> getPatients({PatientStatus? status}) {
    Query query = _firestore.collection('patients').orderBy('createdAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Patient.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  static Future<void> updatePatientStatus(String patientId, PatientStatus status) async {
    try {
      final updates = <String, dynamic>{'status': status.name};
      if (status == PatientStatus.discharged) {
        updates['dischargedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('patients').doc(patientId).update(updates);
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.update, 'patients');
    }
  }

  // Treatment operations
  static Future<void> addTreatment(String patientId, Treatment treatment) async {
    try {
      // Create treatment data with server timestamp (like React version)
      final data = treatment.toJson();
      data['timestamp'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('patients')
          .doc(patientId)
          .collection('treatments')
          .add(data);
    } catch (e) {
      FirebaseService.handleFirestoreError(
        e,
        OperationType.create,
        'patients/$patientId/treatments',
      );
    }
  }

  static Stream<List<Treatment>> getTreatments(String patientId) {
    return _firestore
        .collection('patients')
        .doc(patientId)
        .collection('treatments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Treatment.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  // Payment operations
  static Future<void> addPayment(String patientId, Payment payment) async {
    try {
      // Start a batch write for atomic operations
      WriteBatch batch = _firestore.batch();

      // Add payment record
      final paymentRef = _firestore
          .collection('patients')
          .doc(patientId)
          .collection('payments')
          .doc();
      batch.set(paymentRef, payment.toJson());

      // Update patient's outstanding balance if it's a partial payment
      if (payment.paymentType == PaymentType.partial && payment.originalBillAmount != null) {
        final remainingBalance = payment.originalBillAmount! - payment.amount;
        final patientRef = _firestore.collection('patients').doc(patientId);
        batch.update(patientRef, {'outstandingBalance': remainingBalance});
      } else if (payment.paymentType == PaymentType.full) {
        // Clear outstanding balance for full payments
        final patientRef = _firestore.collection('patients').doc(patientId);
        batch.update(patientRef, {'outstandingBalance': 0});
      }

      await batch.commit();
    } catch (e) {
      FirebaseService.handleFirestoreError(
        e,
        OperationType.create,
        'patients/$patientId/payments',
      );
    }
  }

  static Stream<List<Payment>> getPayments(String patientId) {
    return _firestore
        .collection('patients')
        .doc(patientId)
        .collection('payments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Payment.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  // Debt Forgiveness operations
  static Future<void> addDebtForgiveness(String patientId, DebtForgiveness forgiveness) async {
    try {
      // Start a batch write for atomic operations
      WriteBatch batch = _firestore.batch();

      // Add debt forgiveness record
      final forgivenessRef = _firestore
          .collection('patients')
          .doc(patientId)
          .collection('debt_forgiveness')
          .doc();
      batch.set(forgivenessRef, forgiveness.toJson());

      // Clear or reduce the patient's outstanding balance
      final patientRef = _firestore.collection('patients').doc(patientId);
      batch.update(patientRef, {'outstandingBalance': 0}); // Forgive the entire balance

      await batch.commit();
    } catch (e) {
      FirebaseService.handleFirestoreError(
        e,
        OperationType.create,
        'patients/$patientId/debt_forgiveness',
      );
    }
  }

  static Stream<List<DebtForgiveness>> getDebtForgiveness(String patientId) {
    return _firestore
        .collection('patients')
        .doc(patientId)
        .collection('debt_forgiveness')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DebtForgiveness.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  // Analytics
  static Future<Map<String, int>> getPatientStats() async {
    try {
      final snapshot = await _firestore.collection('patients').get();
      final patients = snapshot.docs
          .map((doc) => Patient.fromJson(doc.data(), doc.id))
          .toList();

      return {
        'total': patients.length,
        'active': patients.where((p) => p.status == PatientStatus.active).length,
        'discharged': patients.where((p) => p.status == PatientStatus.discharged).length,
      };
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.list, 'patients');
      return {'total': 0, 'active': 0, 'discharged': 0};
    }
  }
}