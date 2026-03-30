import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/patient_models.dart';
import '../models/inventory_models.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';

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
    Query query = _firestore.collection('patients');

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    return query.snapshots().map((snapshot) {
      final patients = snapshot.docs.map((doc) {
        return Patient.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      
      // Sort by createdAt descending on client side to avoid composite index requirement
      patients.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return patients;
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

  static Future<void> dischargePatientWithBilling({
    required String patientId,
    required int finalBillAmount,
    required String adminId,
    required String adminName,
    String? dischargeNotes,
  }) async {
    try {
      WriteBatch batch = _firestore.batch();

      // Update patient status to discharged
      final patientRef = _firestore.collection('patients').doc(patientId);
      batch.update(patientRef, {
        'status': PatientStatus.discharged.name,
        'dischargedAt': FieldValue.serverTimestamp(),
        'finalBillAmount': finalBillAmount,
        'dischargedBy': adminName,
        'dischargedById': adminId,
        'dischargeNotes': dischargeNotes,
      });

      // Create a final bill record
      final billRef = patientRef.collection('bills').doc();
      batch.set(billRef, {
        'type': 'final_discharge',
        'amount': finalBillAmount,
        'description': 'Final discharge bill',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': adminName,
        'createdById': adminId,
        'status': 'pending',
        'notes': dischargeNotes,
      });

      await batch.commit();
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.update, 'patients');
    }
  }

  static Future<List<Patient>> getAllPatients() async {
    try {
      final snapshot = await _firestore.collection('patients').get();
      final patients = snapshot.docs.map((doc) {
        return Patient.fromJson(doc.data(), doc.id);
      }).toList();

      // Sort by createdAt descending
      patients.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return patients;
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.list, 'patients');
      return [];
    }
  }

  static Future<int> calculatePatientTotalBill(String patientId) async {
    try {
      // Get all priced treatments for this patient
      final treatmentsSnapshot = await _firestore
          .collection('patients')
          .doc(patientId)
          .collection('treatments')
          .where('pricingStatus', isEqualTo: 'priced')
          .get();

      int totalAmount = 0;
      for (final doc in treatmentsSnapshot.docs) {
        final treatment = Treatment.fromJson(doc.data(), doc.id);
        totalAmount += treatment.totalCharge;
      }

      return totalAmount;
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.list, 'treatments');
      return 0;
    }
  }

  // Treatment operations
  static Future<void> addTreatment(String patientId, Treatment treatment) async {
    try {
      // Start batch write for atomic operations
      WriteBatch batch = _firestore.batch();

      // Create treatment data with server timestamp
      final data = treatment.toJson();
      data['timestamp'] = FieldValue.serverTimestamp();

      final treatmentRef = _firestore
          .collection('patients')
          .doc(patientId)
          .collection('treatments')
          .doc();

      batch.set(treatmentRef, data);

      // Update inventory for each treatment item
      for (final item in treatment.items) {
        await _updateInventoryForTreatmentItem(
          batch,
          item,
          treatmentRef.id,
          treatment.nurseName,
          treatment.nurseId,
        );
      }

      await batch.commit();

      // 🔔 Send notification after successful treatment logging
      try {
        // Get patient details for notification
        final patientDoc = await _firestore.collection('patients').doc(patientId).get();
        if (patientDoc.exists) {
          final patientData = patientDoc.data() as Map<String, dynamic>;
          final patientName = patientData['name'] as String;

          await NotificationService().notifyTreatmentLogged(
            patientName: patientName,
            nurseName: treatment.nurseName,
            patientId: patientId,
            treatmentId: treatmentRef.id,
            itemCount: treatment.items.length,
          );
        }
      } catch (notificationError) {
        // Don't fail the main operation if notification fails
        print('Failed to send treatment notification: $notificationError');
      }
    } catch (e) {
      FirebaseService.handleFirestoreError(
        e,
        OperationType.create,
        'patients/$patientId/treatments',
      );
    }
  }

  // Helper function to update inventory when treatment items are used
  static Future<void> _updateInventoryForTreatmentItem(
    WriteBatch batch,
    TreatmentItem treatmentItem,
    String treatmentId,
    String nurseName,
    String nurseId,
  ) async {
    try {
      // Find matching inventory item by name
      final inventoryQuery = await _firestore
          .collection('inventory')
          .where('name', isEqualTo: treatmentItem.name)
          .get();

      if (inventoryQuery.docs.isNotEmpty) {
        final inventoryDoc = inventoryQuery.docs.first;
        final inventoryItem = InventoryItem.fromJson(inventoryDoc.data(), inventoryDoc.id);

        // Calculate new stock level
        final newStock = inventoryItem.currentStock - treatmentItem.quantity;

        // Update inventory item stock
        final inventoryRef = _firestore.collection('inventory').doc(inventoryItem.id);
        batch.update(inventoryRef, {
          'currentStock': newStock >= 0 ? newStock : 0, // Don't allow negative stock
          'lastUpdated': FieldValue.serverTimestamp(),
          'updatedBy': nurseId,
        });

        // Add stock transaction record
        final transactionRef = _firestore.collection('stock_transactions').doc();
        batch.set(transactionRef, {
          'itemId': inventoryItem.id,
          'itemName': inventoryItem.name,
          'quantityChange': -treatmentItem.quantity, // Negative for usage
          'type': 'usage',
          'reason': 'Used in patient treatment',
          'timestamp': FieldValue.serverTimestamp(),
          'userId': nurseId,
          'userName': nurseName,
          'relatedTreatmentId': treatmentId,
        });
      }
      // If no matching inventory item found, we still create the treatment
      // but don't update inventory
    } catch (e) {
      // Log error but don't fail the treatment creation
      FirebaseService.handleFirestoreError(e, OperationType.update, 'inventory');
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

  // Get all pending treatments across all patients for admin pricing
  static Future<List<Treatment>> getPendingTreatments() async {
    try {
      final patientsSnapshot = await _firestore.collection('patients').get();
      List<Treatment> pendingTreatments = [];

      for (final patientDoc in patientsSnapshot.docs) {
        // Get pending treatments for this patient
        final treatmentsSnapshot = await _firestore
            .collection('patients')
            .doc(patientDoc.id)
            .collection('treatments')
            .where('pricingStatus', isEqualTo: 'pending')
            .get();

        final treatments = treatmentsSnapshot.docs.map((doc) {
          return Treatment.fromJson(doc.data(), doc.id);
        }).toList();

        pendingTreatments.addAll(treatments);
      }

      // Sort by timestamp descending on client side
      pendingTreatments.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return pendingTreatments;
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.list, 'treatments');
      return [];
    }
  }


  // Update treatment with pricing information
  static Future<void> updateTreatmentPricing(Treatment treatment) async {
    try {
      // Find the patient that contains this treatment
      final patientsSnapshot = await _firestore.collection('patients').get();

      for (final patientDoc in patientsSnapshot.docs) {
        final treatmentRef = _firestore
            .collection('patients')
            .doc(patientDoc.id)
            .collection('treatments')
            .doc(treatment.id);

        // Check if this treatment exists in this patient's collection
        final treatmentDoc = await treatmentRef.get();
        if (treatmentDoc.exists) {
          // Found the treatment, update it
          final data = treatment.toJson();
          data['pricedAt'] = FieldValue.serverTimestamp();

          await treatmentRef.update(data);
          return;
        }
      }

      throw Exception('Treatment not found');
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.update, 'treatments');
    }
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

      // 🔔 Send notification after successful payment recording
      try {
        // Get patient details for notification
        final patientDoc = await _firestore.collection('patients').doc(patientId).get();
        if (patientDoc.exists) {
          final patientData = patientDoc.data() as Map<String, dynamic>;
          final patientName = patientData['name'] as String;

          await NotificationService().notifyPaymentReceived(
            patientName: patientName,
            cashierName: payment.cashierName,
            patientId: patientId,
            paymentId: paymentRef.id,
            amount: payment.amount,
            paymentMethod: payment.paymentMethod,
          );
        }
      } catch (notificationError) {
        // Don't fail the main operation if notification fails
        print('Failed to send payment notification: $notificationError');
      }
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

      // Get current patient data to calculate new balance
      final patientDoc = await _firestore.collection('patients').doc(patientId).get();
      if (patientDoc.exists) {
        final currentBalance = patientDoc.data()?['outstandingBalance'] as int? ?? 0;
        final newBalance = currentBalance - forgiveness.forgivenAmount;

        // Update the patient's outstanding balance (subtract forgiven amount)
        final patientRef = _firestore.collection('patients').doc(patientId);
        batch.update(patientRef, {'outstandingBalance': newBalance >= 0 ? newBalance : 0});
      }

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

      // Count pending treatments across all active patients
      int pendingTreatments = 0;
      int todayAdmissions = 0;
      int todayTreatments = 0;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Count today's admissions
      todayAdmissions = patients.where((p) =>
        p.createdAt.isAfter(startOfDay) && p.createdAt.isBefore(endOfDay)
      ).length;

      // Get all pending treatments (this is an approximation - in real implementation
      // you might want to use a more efficient query)
      for (final patient in patients.where((p) => p.status == PatientStatus.active)) {
        try {
          final treatmentsSnapshot = await _firestore
              .collection('patients')
              .doc(patient.id)
              .collection('treatments')
              .where('pricingStatus', isEqualTo: 'pending')
              .get();

          pendingTreatments += treatmentsSnapshot.docs.length;

          // Count today's treatments for this patient
          final todayTreatmentsSnapshot = await _firestore
              .collection('patients')
              .doc(patient.id)
              .collection('treatments')
              .where('timestamp', isGreaterThan: startOfDay)
              .where('timestamp', isLessThan: endOfDay)
              .get();

          todayTreatments += todayTreatmentsSnapshot.docs.length;
        } catch (e) {
          // Continue if there's an error with individual patient
          continue;
        }
      }

      return {
        'total': patients.length,
        'active': patients.where((p) => p.status == PatientStatus.active).length,
        'discharged': patients.where((p) => p.status == PatientStatus.discharged).length,
        'pendingTreatments': pendingTreatments,
        'todayAdmissions': todayAdmissions,
        'todayTreatments': todayTreatments,
      };
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.list, 'patients');
      return {
        'total': 0,
        'active': 0,
        'discharged': 0,
        'pendingTreatments': 0,
        'todayAdmissions': 0,
        'todayTreatments': 0,
      };
    }
  }

  // Inventory operations
  static Stream<List<InventoryItem>> getInventoryItems({InventoryCategory? category, StockStatus? stockStatus}) {
    Query query = _firestore.collection('inventory');

    if (category != null) {
      query = query.where('category', isEqualTo: category.displayName);
    }

    return query.snapshots().map((snapshot) {
      final items = snapshot.docs.map((doc) {
        return InventoryItem.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      // Filter by stock status if specified
      if (stockStatus != null) {
        return items.where((item) => item.stockStatus == stockStatus).toList();
      }

      // Sort by name
      items.sort((a, b) => a.name.compareTo(b.name));
      return items;
    });
  }

  static Future<void> createInventoryItem(InventoryItem item, String userId) async {
    try {
      final data = item.toJson();
      data['lastUpdated'] = FieldValue.serverTimestamp();
      data['updatedBy'] = userId;

      await _firestore.collection('inventory').add(data);
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.create, 'inventory');
    }
  }

  static Future<void> updateInventoryItem(InventoryItem item, String userId) async {
    try {
      final data = item.toJson();
      data['lastUpdated'] = FieldValue.serverTimestamp();
      data['updatedBy'] = userId;

      await _firestore.collection('inventory').doc(item.id).update(data);
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.update, 'inventory');
    }
  }

  static Future<void> updateStock(
    String itemId,
    int newStock,
    String userId,
    String userName,
    String reason,
    String transactionType,
    {String? relatedTreatmentId}
  ) async {
    try {
      // Start a batch write for atomic operations
      WriteBatch batch = _firestore.batch();

      // Get current item to calculate stock change
      final itemDoc = await _firestore.collection('inventory').doc(itemId).get();
      if (!itemDoc.exists) {
        throw Exception('Inventory item not found');
      }

      final currentItem = InventoryItem.fromJson(itemDoc.data()!, itemId);
      final stockChange = newStock - currentItem.currentStock;

      // Update inventory item
      final inventoryRef = _firestore.collection('inventory').doc(itemId);
      batch.update(inventoryRef, {
        'currentStock': newStock,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': userId,
      });

      // Add stock transaction record
      final transactionRef = _firestore.collection('stock_transactions').doc();
      batch.set(transactionRef, {
        'itemId': itemId,
        'itemName': currentItem.name,
        'quantityChange': stockChange,
        'type': transactionType,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
        'userName': userName,
        'relatedTreatmentId': relatedTreatmentId,
      });

      await batch.commit();
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.update, 'inventory');
    }
  }

  static Stream<List<StockTransaction>> getStockTransactions({String? itemId}) {
    Query query = _firestore.collection('stock_transactions');

    if (itemId != null) {
      query = query.where('itemId', isEqualTo: itemId);
    }

    return query
        .orderBy('timestamp', descending: true)
        .limit(100) // Limit to last 100 transactions
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return StockTransaction.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Get low stock items for alerts
  static Future<List<InventoryItem>> getLowStockItems() async {
    try {
      final snapshot = await _firestore.collection('inventory').get();
      final items = snapshot.docs.map((doc) {
        return InventoryItem.fromJson(doc.data(), doc.id);
      }).toList();

      // Filter for low stock or out of stock items
      return items.where((item) =>
        item.stockStatus == StockStatus.lowStock ||
        item.stockStatus == StockStatus.outOfStock
      ).toList();
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.list, 'inventory');
      return [];
    }
  }

  // Get expiring items
  static Future<List<InventoryItem>> getExpiringItems() async {
    try {
      final snapshot = await _firestore.collection('inventory').get();
      final items = snapshot.docs.map((doc) {
        return InventoryItem.fromJson(doc.data(), doc.id);
      }).toList();

      // Filter for expiring or expired items
      return items.where((item) => item.isExpiringSoon || item.isExpired).toList();
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.list, 'inventory');
      return [];
    }
  }

  // Initialize inventory with default items
  static Future<void> initializeInventory(String userId) async {
    try {
      final inventorySnapshot = await _firestore.collection('inventory').get();
      if (inventorySnapshot.docs.isNotEmpty) {
        // Inventory already initialized
        return;
      }

      final batch = _firestore.batch();

      for (final itemData in DefaultInventoryItems.items) {
        final docRef = _firestore.collection('inventory').doc();
        final data = Map<String, dynamic>.from(itemData);
        data['lastUpdated'] = FieldValue.serverTimestamp();
        data['updatedBy'] = userId;

        batch.set(docRef, data);
      }

      await batch.commit();
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.create, 'inventory');
    }
  }
}