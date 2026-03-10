import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/data_provider.dart';
import '../../models/patient_models.dart';
import 'billing_detail_screen.dart';

class CashierDashboard extends StatefulWidget {
  const CashierDashboard({super.key});

  @override
  State<CashierDashboard> createState() => _CashierDashboardState();
}

class _CashierDashboardState extends State<CashierDashboard> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, _) {
        final patients = dataProvider.patients;
        final filteredPatients = _filterPatients(patients);

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Billing Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Search bar
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search patient for billing...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF78716C),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: Color(0xFF78716C),
                          ),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFFAFAF9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFFE7E5E4),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF10B981),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Search results info
              if (_searchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${filteredPatients.length} patient${filteredPatients.length != 1 ? 's' : ''} found for "$_searchQuery"',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF78716C),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              // Patients table
              Expanded(
                child: Card(
                  child: Column(
                    children: [
                      // Table header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFAFAF9),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'PATIENT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFA8A29E),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'TYPE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFA8A29E),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'ID',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFA8A29E),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'WARD',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFA8A29E),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'STATUS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFA8A29E),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'ACTION',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFA8A29E),
                                  letterSpacing: 1.5,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Table body
                      Expanded(
                        child: filteredPatients.isEmpty
                            ? _buildEmptyState()
                            : ListView.separated(
                                itemCount: filteredPatients.length,
                                separatorBuilder: (context, index) => const Divider(
                                  height: 1,
                                  color: Color(0xFFF5F5F4),
                                ),
                                itemBuilder: (context, index) {
                                  final patient = filteredPatients[index];
                                  return _buildPatientRow(patient);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPatientRow(Patient patient) {
    return InkWell(
      onTap: () => _navigateToBillingDetail(patient),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                patient.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1917),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: patient.type == PatientType.inPatient
                      ? const Color(0xFFDEF7EC) // Blue-50
                      : const Color(0xFFFEF3C7), // Orange-50
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  patient.type.displayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: patient.type == PatientType.inPatient
                        ? const Color(0xFF065F46) // Blue-600
                        : const Color(0xFF92400E), // Orange-600
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                patient.admissionNumber,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF78716C),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                patient.ward,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF78716C),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: patient.status == PatientStatus.active
                      ? const Color(0xFFD1FAE5) // Emerald-100
                      : const Color(0xFFF5F5F4), // Stone-100
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  patient.status.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: patient.status == PatientStatus.active
                        ? const Color(0xFF065F46) // Emerald-800
                        : const Color(0xFFA8A29E), // Stone-400
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'View Bill',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.receipt_outlined,
              size: 40,
              color: Color(0xFFA8A29E),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No patients found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF78716C),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Search for a patient to view their bill',
            style: TextStyle(
              color: Color(0xFFA8A29E),
            ),
          ),
        ],
      ),
    );
  }

  List<Patient> _filterPatients(List<Patient> patients) {
    if (_searchQuery.isEmpty) return patients;

    return patients.where((patient) {
      final query = _searchQuery.toLowerCase();
      return patient.name.toLowerCase().contains(query) ||
          patient.admissionNumber.toLowerCase().contains(query) ||
          patient.ward.toLowerCase().contains(query);
    }).toList();
  }

  void _navigateToBillingDetail(Patient patient) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BillingDetailScreen(patient: patient),
      ),
    );
  }
}