import 'package:flutter/material.dart';
import '../../models/patient_models.dart';
import '../../models/user_models.dart';
import '../../services/data_service.dart';
import '../../widgets/discharge_patient_dialog.dart';

class PatientManagementScreen extends StatefulWidget {
  final UserProfile adminProfile;

  const PatientManagementScreen({
    super.key,
    required this.adminProfile,
  });

  @override
  State<PatientManagementScreen> createState() => _PatientManagementScreenState();
}

class _PatientManagementScreenState extends State<PatientManagementScreen> {
  String _searchQuery = '';
  List<Patient> _patients = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);

    try {
      final patients = await DataService.getAllPatients();
      setState(() {
        _patients = patients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading patients: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Management'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1917),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFE7E5E4),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with stats
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            'Total Patients',
                            _patients.length.toString(),
                            Icons.people,
                            const Color(0xFF10B981),
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            'Active',
                            _patients.where((p) => p.status == PatientStatus.active).length.toString(),
                            Icons.local_hospital,
                            const Color(0xFF3B82F6),
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            'Discharged',
                            _patients.where((p) => p.status == PatientStatus.discharged).length.toString(),
                            Icons.check_circle,
                            const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Filters and search
                  Row(
                    children: [
                      // Status filter
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildFilterTab('All', 'all'),
                            _buildFilterTab('Active', 'active'),
                            _buildFilterTab('Discharged', 'discharged'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Search bar
                      Expanded(
                        child: TextField(
                          onChanged: (value) => setState(() => _searchQuery = value),
                          decoration: const InputDecoration(
                            hintText: 'Search by name or admission number...',
                            prefixIcon: Icon(Icons.search, color: Color(0xFF78716C)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Color(0xFFE7E5E4)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Color(0xFFE7E5E4)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Patients list
                  Expanded(
                    child: _buildPatientsList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTab(String label, String value) {
    final isSelected = _selectedStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? const Color(0xFF1C1917) : const Color(0xFF78716C),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientsList() {
    final filteredPatients = _filterPatients();

    if (filteredPatients.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      itemCount: filteredPatients.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final patient = filteredPatients[index];
        return _buildPatientCard(patient);
      },
    );
  }

  Widget _buildPatientCard(Patient patient) {
    final isActive = patient.status == PatientStatus.active;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1917),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${patient.admissionNumber} • Ward: ${patient.ward}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF78716C),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Discharged',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isActive ? const Color(0xFF166534) : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Patient details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Type: ${patient.type.displayName}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Admitted: ${_formatDate(patient.createdAt)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (patient.dischargedAt != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Discharged: ${_formatDate(patient.dischargedAt!)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (patient.outstandingBalance > 0)
                            Text(
                              'Outstanding: ₦${patient.outstandingBalance}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            if (isActive) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showDischargeDialog(patient),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text(
                    'Discharge Patient',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
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
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.people_outline,
              size: 40,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No patients found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1917),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search terms'
                : 'No patients match the selected filter',
            style: const TextStyle(
              color: Color(0xFF78716C),
            ),
          ),
        ],
      ),
    );
  }

  List<Patient> _filterPatients() {
    List<Patient> filtered = _patients;

    // Filter by status
    if (_selectedStatus != 'all') {
      final status = _selectedStatus == 'active'
          ? PatientStatus.active
          : PatientStatus.discharged;
      filtered = filtered.where((p) => p.status == status).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((patient) {
        return patient.name.toLowerCase().contains(query) ||
            patient.admissionNumber.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showDischargeDialog(Patient patient) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DischargePatientDialog(
        patient: patient,
        adminProfile: widget.adminProfile,
        onSuccess: _loadPatients,
      ),
    );
  }
}