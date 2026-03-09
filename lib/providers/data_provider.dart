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

  List<Patient> get patients => _patients;
  List<Treatment> get treatments => _treatments;
  List<Payment> get payments => _payments;
  Map<String, int> get patientStats => _patientStats;
  bool get isLoading => _isLoading;
  PatientStatus get currentFilter => _currentFilter;

  void setPatientFilter(PatientStatus status) {
    _currentFilter = status;
    notifyListeners();
    _loadPatients();
  }

  void _loadPatients() {
    DataService.getPatients(status: _currentFilter).listen((patients) {
      _patients = patients;
      notifyListeners();
    });
  }

  void loadTreatments(String patientId) {
    DataService.getTreatments(patientId).listen((treatments) {
      _treatments = treatments;
      notifyListeners();
    });
  }

  void loadPayments(String patientId) {
    DataService.getPayments(patientId).listen((payments) {
      _payments = payments;
      notifyListeners();
    });
  }

  Future<void> createPatient(Patient patient) async {
    _isLoading = true;
    notifyListeners();

    try {
      await DataService.createPatient(patient);
    } catch (e) {
      debugPrint('Error creating patient: $e');
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
    } catch (e) {
      debugPrint('Error discharging patient: $e');
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
      // Reload patient data to update outstanding balance
      _loadPatients();
    } catch (e) {
      debugPrint('Error adding payment: $e');
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
      // Reload patient data to update outstanding balance
      _loadPatients();
    } catch (e) {
      debugPrint('Error adding debt forgiveness: $e');
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

  void initialize() {
    _loadPatients();
    loadStats();
  }
}