import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../models/patient_models.dart';
import '../../models/user_models.dart';
import '../../widgets/patient_card.dart';
import '../../widgets/add_patient_dialog.dart';
import 'patient_detail_screen.dart';

class NurseDashboard extends StatefulWidget {
  const NurseDashboard({super.key});

  @override
  State<NurseDashboard> createState() => _NurseDashboardState();
}

class _NurseDashboardState extends State<NurseDashboard> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Consumer2<DataProvider, AuthProvider>(
      builder: (context, dataProvider, authProvider, _) {
        final patients = dataProvider.patients;
        final filteredPatients = _filterPatients(patients);

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with filter tabs and add button
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 600) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ward Patients',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F4),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildFilterTab(
                                        'Active',
                                        PatientStatus.active,
                                        dataProvider,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildFilterTab(
                                        'Discharged',
                                        PatientStatus.discharged,
                                        dataProvider,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () => _showAddPatientDialog(context, authProvider.profile!),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ward Patients',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Filter tabs
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F4), // Stone-100
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildFilterTab(
                                    'Active',
                                    PatientStatus.active,
                                    dataProvider,
                                  ),
                                  _buildFilterTab(
                                    'Discharged',
                                    PatientStatus.discharged,
                                    dataProvider,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAddPatientDialog(context, authProvider.profile!),
                        icon: const Icon(Icons.add),
                        label: const Text('New Admission'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Search bar
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search by name, ID, or ward...',
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
              const SizedBox(height: 24),

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

              // Patients list
              Expanded(
                child: filteredPatients.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: filteredPatients.length,
                        itemBuilder: (context, index) {
                          final patient = filteredPatients[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: PatientCard(
                              patient: patient,
                              onTap: () => _navigateToPatientDetail(patient),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterTab(
    String label,
    PatientStatus status,
    DataProvider dataProvider,
  ) {
    final isActive = dataProvider.currentFilter == status;

    return GestureDetector(
      onTap: () => dataProvider.setPatientFilter(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFF10B981) : const Color(0xFF78716C),
            letterSpacing: 1,
          ),
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
              Icons.people_outline,
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
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search terms'
                : 'Start by admitting a new patient',
            style: const TextStyle(
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

  void _navigateToPatientDetail(Patient patient) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PatientDetailScreen(patient: patient),
      ),
    );
  }

  void _showAddPatientDialog(BuildContext context, UserProfile profile) {
    showDialog(
      context: context,
      builder: (context) => AddPatientDialog(profile: profile),
    );
  }

}