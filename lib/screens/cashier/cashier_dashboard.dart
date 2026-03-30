import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/data_provider.dart';
import '../../models/patient_models.dart';
import '../../models/user_models.dart';
import 'billing_detail_screen.dart';
import 'cashier_main_screen.dart';

class CashierDashboard extends StatelessWidget {
  final UserProfile profile;

  const CashierDashboard({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return CashierMainScreen(profile: profile);
  }
}

class CashierBillingTab extends StatefulWidget {
  final UserProfile profile;

  const CashierBillingTab({
    super.key,
    required this.profile,
  });

  @override
  State<CashierBillingTab> createState() => _CashierBillingTabState();
}

class _CashierBillingTabState extends State<CashierBillingTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, _) {
        final patients = dataProvider.patients;
        final filteredPatients = _filterPatients(patients);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Billing Dashboard',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 32),

              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE7E5E4)),
                ),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: const InputDecoration(
                    hintText: 'Search patient for billing...',
                    hintStyle: TextStyle(
                      color: Color(0xFFA8A29E),
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(left: 20, right: 12),
                      child: Icon(
                        Icons.search,
                        color: Color(0xFF78716C),
                        size: 24,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Patients table
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: const Color(0xFFE7E5E4)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Column(
                      children: [
                        // Table header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFF5F5F4)),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'PATIENT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
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
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFA8A29E),
                                    letterSpacing: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'STATUS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFA8A29E),
                                    letterSpacing: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'ACTION',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
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
                                  padding: EdgeInsets.zero,
                                  itemCount: filteredPatients.length,
                                  separatorBuilder: (context, index) => const Divider(
                                    height: 1,
                                    color: Color(0xFFF5F5F4),
                                    thickness: 1,
                                    indent: 32,
                                    endIndent: 32,
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
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                patient.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5), // Emerald-100
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    patient.type == PatientType.inPatient ? 'IP' : 'OP',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF065F46), // Emerald-800
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5), // Emerald-100
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    patient.status.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF065F46), // Emerald-800
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 24,
                  color: const Color(0xFF10B981).withValues(alpha: 0.8),
                ),
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