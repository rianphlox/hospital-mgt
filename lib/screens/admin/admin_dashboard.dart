import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/data_provider.dart';
import '../../models/user_models.dart';
import 'treatment_pricing_screen.dart';
import 'patient_management_screen.dart';
import 'financial_reports_screen.dart';
import '../patient_history_screen.dart';

class AdminDashboard extends StatefulWidget {
  final UserProfile profile;

  const AdminDashboard({
    super.key,
    required this.profile,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, _) {
        final stats = dataProvider.patientStats;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Admin Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Statistics cards - two rows
              Column(
                children: [
                  // First row - main stats
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Patients',
                          stats['total']?.toString() ?? '0',
                          Icons.people,
                          const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Active Patients',
                          stats['active']?.toString() ?? '0',
                          Icons.local_hospital,
                          const Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Discharged',
                          stats['discharged']?.toString() ?? '0',
                          Icons.check_circle,
                          const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Second row - alerts and today's stats
                  Row(
                    children: [
                      Expanded(
                        child: _buildAlertCard(
                          'Pending Treatments',
                          stats['pendingTreatments']?.toString() ?? '0',
                          Icons.pending_actions,
                          const Color(0xFFD97706),
                          isPending: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Today\'s Admissions',
                          stats['todayAdmissions']?.toString() ?? '0',
                          Icons.today,
                          const Color(0xFF8B5CF6),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Today\'s Treatments',
                          stats['todayTreatments']?.toString() ?? '0',
                          Icons.medical_services,
                          const Color(0xFF06B6D4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Management sections - grid layout
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    _buildManagementCard(
                      'Treatment Pricing',
                      'Review and price pending treatments',
                      Icons.attach_money,
                      const Color(0xFF10B981),
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => TreatmentPricingScreen(profile: widget.profile),
                        ),
                      ),
                    ),
                    _buildManagementCard(
                      'Staff Management',
                      'Manage staff accounts and permissions',
                      Icons.people_outline,
                      const Color(0xFF3B82F6),
                      () => _showComingSoonDialog('Staff Management'),
                    ),
                    _buildManagementCard(
                      'Financial Reports',
                      'View revenue and financial analytics',
                      Icons.assessment,
                      const Color(0xFF8B5CF6),
                      () => _showComingSoonDialog('Financial Reports'),
                    ),
                    _buildManagementCard(
                      'Patient Management',
                      'Discharge patients and manage records',
                      Icons.people,
                      const Color(0xFFDC2626),
                      () => _showPatientManagement(),
                    ),
                    _buildManagementCard(
                      'Financial Reports',
                      'View revenue and payment analytics',
                      Icons.analytics,
                      const Color(0xFF8B5CF6),
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => FinancialReportsScreen(adminProfile: widget.profile),
                        ),
                      ),
                    ),
                    _buildManagementCard(
                      'Patient History',
                      'View patient history with date range filtering',
                      Icons.history,
                      const Color(0xFF059669),
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const PatientHistoryScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isPending = false,
  }) {
    final int count = int.tryParse(value) ?? 0;
    final bool hasAlert = isPending && count > 0;

    return GestureDetector(
      onTap: hasAlert && isPending
          ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TreatmentPricingScreen(profile: widget.profile),
                ),
              )
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasAlert ? const Color(0xFFFEF3C7) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasAlert ? const Color(0xFFFDE68A) : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
                const Spacer(),
                Row(
                  children: [
                    if (hasAlert)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'ALERT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: hasAlert ? const Color(0xFF92400E) : const Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (hasAlert)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Needs pricing by doctor/admin',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF92400E),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.3,
                ),
                overflow: TextOverflow.fade,
                maxLines: 2,
              ),
            ),
            Row(
              children: [
                Text(
                  'Manage',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: color,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPatientManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PatientManagementScreen(adminProfile: widget.profile),
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(feature),
        content: const Text(
          'This feature is coming soon! Stay tuned for updates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}