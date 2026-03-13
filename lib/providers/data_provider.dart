import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/patient_models.dart';
import '../services/data_service.dart';

class DataProvider with ChangeNotifier {
  List<Patient> _patients = [];
  List<Treatment> _treatments = [];
  List<Payment> _payments = [];
  Map<String, int> _patientStats = {'total': 0, 'active': 0, 'discharged': 0};
  bool _isLoading = false;
  PatientStatus _currentFilter = PatientStatus.active;

  StreamSubscription<List<Patient>>? _patientsSubscription;
  StreamSubscription<List<Treatment>>? _treatmentsSubscription;
  StreamSubscription<List<Payment>>? _paymentsSubscription;

  List<Patient> get patients => _patients;
  List<Treatment> get treatments => _treatments;
  List<Payment> get payments => _payments;
  Map<String, int> get patientStats => _patientStats;
  bool get isLoading => _isLoading;
  PatientStatus get currentFilter => _currentFilter;

  @override
  void dispose() {
    _patientsSubscription?.cancel();
    _treatmentsSubscription?.cancel();
    _paymentsSubscription?.cancel();
    super.dispose();
  }

  void setPatientFilter(PatientStatus status) {
    if (_currentFilter == status) return;
    _currentFilter = status;
    notifyListeners();
    _loadPatients();
  }

  void _loadPatients() {
    _patientsSubscription?.cancel();
    _patientsSubscription = DataService.getPatients(status: _currentFilter).listen(
      (patients) {
        _patients = patients;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error listening to patients: $error');
      },
    );
  }

  void loadTreatments(String patientId) {
    _treatmentsSubscription?.cancel();
    _treatmentsSubscription = DataService.getTreatments(patientId).listen(
      (treatments) {
        _treatments = treatments;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error listening to treatments: $error');
      },
    );
  }

  void loadPayments(String patientId) {
    _paymentsSubscription?.cancel();
    _paymentsSubscription = DataService.getPayments(patientId).listen(
      (payments) {
        _payments = payments;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error listening to payments: $error');
      },
    );
  }

  Future<void> createPatient(Patient patient) async {
    _isLoading = true;
    notifyListeners();

    try {
      await DataService.createPatient(patient);
      await loadStats();
      // Ensure the patients list refreshes by restarting the listener
      _loadPatients();
    } catch (e) {
      debugPrint('Error creating patient: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> dischargePatient(String patientId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await DataService.updatePatientStatus(patientId, PatientStatus.discharged);
      await loadStats();
    } catch (e) {
      debugPrint('Error discharging patient: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTreatment(String patientId, Treatment treatment) async {
    _isLoading = true;
    notifyListeners();

    try {
      await DataService.addTreatment(patientId, treatment);
    } catch (e) {
      debugPrint('Error adding treatment: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPayment(String patientId, Payment payment) async {
    _isLoading = true;
    notifyListeners();

    try {
      await DataService.addPayment(patientId, payment);
      // Stats might change (e.g. if we add total revenue later)
      await loadStats();
    } catch (e) {
      debugPrint('Error adding payment: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addDebtForgiveness(String patientId, DebtForgiveness forgiveness) async {
    _isLoading = true;
    notifyListeners();

    try {
      await DataService.addDebtForgiveness(patientId, forgiveness);
      await loadStats();
    } catch (e) {
      debugPrint('Error adding debt forgiveness: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStats() async {
    try {
      _patientStats = await DataService.getPatientStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> refreshStats() async {
    await loadStats();
  }

  void initialize() {
    _loadPatients();
    loadStats();
  }
}