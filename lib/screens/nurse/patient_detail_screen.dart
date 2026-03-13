import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/data_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/patient_models.dart';
import '../../models/user_models.dart';
import '../../widgets/simple_add_treatment_dialog.dart';

class PatientDetailScreen extends StatefulWidget {
  final Patient patient;

  const PatientDetailScreen({
    super.key,
    required this.patient,
  });

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  String _treatmentFilter = 'all'; // all, pending, priced
  String _nurseFilter = 'all'; // all, or specific nurse
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    // Load treatments and payments for this patient
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      dataProvider.loadTreatments(widget.patient.id);
      dataProvider.loadPayments(widget.patient.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer2<DataProvider, AuthProvider>(
        builder: (context, dataProvider, authProvider, _) {
          final allTreatments = dataProvider.treatments;
          final treatments = _filterTreatments(allTreatments);
          final payments = dataProvider.payments;
          final profile = authProvider.profile!;

          // Calculate billing status
          final totalBilled = treatments.fold<int>(0, (sum, treatment) => sum + treatment.totalCharge);
          final totalPaid = payments.fold<int>(0, (sum, payment) => sum + payment.amount);
          final balance = totalBilled - totalPaid;

          // Check for pending treatments awaiting pricing
          final pendingTreatments = treatments.where((t) => t.pricingStatus == TreatmentPricingStatus.pending).length;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Patient info card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status badge at top right
                        Row(
                          children: [
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.patient.status == PatientStatus.active
                                    ? const Color(0xFFD1FAE5)
                                    : const Color(0xFFF5F5F4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.patient.status == PatientStatus.active ? 'ACTIVE' : 'DISCHARGED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: widget.patient.status == PatientStatus.active
                                      ? const Color(0xFF065F46)
                                      : const Color(0xFFA8A29E),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Patient info row
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1FAE5), // Emerald-100
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Color(0xFF10B981), // Emerald-500
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.patient.name,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${widget.patient.admissionNumber} • ${widget.patient.ward}',
                                    style: const TextStyle(
                                      color: Color(0xFF78716C),
                                    ),
                                  ),
                                  if (widget.patient.status == PatientStatus.discharged &&
                                      widget.patient.dischargedAt != null)
                                    Text(
                                      'Discharged: ${DateFormat('PPP').format(widget.patient.dischargedAt!)}',
                                      style: const TextStyle(
                                        color: Color(0xFFA8A29E),
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Billing status indicator (only if there are treatments)
                        if (treatments.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (pendingTreatments > 0 || balance > 0)
                                  ? (pendingTreatments > 0)
                                      ? const Color(0xFFFEF3C7) // Yellow for pending
                                      : const Color(0xFFFEE2E2) // Red for unpaid
                                  : const Color(0xFFD1FAE5), // Green for ready
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (pendingTreatments > 0 || balance > 0)
                                    ? (pendingTreatments > 0)
                                        ? const Color(0xFFFDE68A) // Yellow border
                                        : const Color(0xFFFECACA) // Red border
                                    : const Color(0xFFA7F3D0), // Green border
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  (pendingTreatments > 0)
                                      ? Icons.pending_actions
                                      : (balance > 0)
                                          ? Icons.warning_amber_rounded
                                          : Icons.check_circle,
                                  color: (pendingTreatments > 0)
                                      ? const Color(0xFFD97706) // Orange for pending
                                      : (balance > 0)
                                          ? const Color(0xFFDC2626) // Red for unpaid
                                          : const Color(0xFF059669), // Green for ready
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    (pendingTreatments > 0)
                                        ? '$pendingTreatments treatment${pendingTreatments > 1 ? 's' : ''} awaiting pricing'
                                        : (balance > 0)
                                            ? 'Outstanding balance: ₦${balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
                                            : 'All bills paid - Ready for discharge',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: (pendingTreatments > 0)
                                          ? const Color(0xFF92400E) // Dark orange for pending
                                          : (balance > 0)
                                              ? const Color(0xFF7F1D1D) // Dark red for unpaid
                                              : const Color(0xFF065F46), // Dark green for ready
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (treatments.isNotEmpty) const SizedBox(height: 16),

                        // Action buttons
                        if ((profile.role == UserRole.nurse || profile.role == UserRole.admin) &&
                            widget.patient.status == PatientStatus.active)
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => _showDischargeDialog(context, dataProvider),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF78716C),
                                ),
                                child: const Text(
                                  'Discharge',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: () => _showAddTreatmentDialog(context, profile),
                                icon: const Icon(Icons.add),
                                label: const Text('Log Treatment'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Treatment history header with filters
                Row(
                  children: [
                    const Icon(
                      Icons.list_alt,
                      color: Color(0xFF78716C),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Treatment History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _showFilterDialog(),
                      icon: Stack(
                        children: [
                          const Icon(
                            Icons.filter_list,
                            color: Color(0xFF78716C),
                          ),
                          if (_hasActiveFilters())
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Filter chips (if active)
                if (_hasActiveFilters())
                  Column(
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          if (_treatmentFilter != 'all')
                            Chip(
                              label: Text(
                                _treatmentFilter == 'pending' ? 'Pending' : 'Priced',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onDeleted: () => setState(() => _treatmentFilter = 'all'),
                              deleteIconColor: const Color(0xFF10B981),
                              backgroundColor: const Color(0xFFD1FAE5),
                            ),
                          if (_nurseFilter != 'all')
                            Chip(
                              label: Text(
                                'Nurse: $_nurseFilter',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onDeleted: () => setState(() => _nurseFilter = 'all'),
                              deleteIconColor: const Color(0xFF10B981),
                              backgroundColor: const Color(0xFFD1FAE5),
                            ),
                          if (_startDate != null || _endDate != null)
                            Chip(
                              label: Text(
                                'Date Range',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onDeleted: () => setState(() {
                                _startDate = null;
                                _endDate = null;
                              }),
                              deleteIconColor: const Color(0xFF10B981),
                              backgroundColor: const Color(0xFFD1FAE5),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),

                // Results info
                if (allTreatments.length != treatments.length)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Showing ${treatments.length} of ${allTreatments.length} treatments',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF78716C),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                // Treatment list
                Expanded(
                  child: treatments.isEmpty
                      ? _buildEmptyTreatments()
                      : ListView.separated(
                          itemCount: treatments.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final treatment = treatments[index];
                            return _buildTreatmentCard(treatment);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyTreatments() {
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
              Icons.medical_information_outlined,
              size: 40,
              color: Color(0xFFA8A29E),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No treatments recorded',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF78716C),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start by logging the first treatment',
            style: TextStyle(
              color: Color(0xFFA8A29E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentCard(Treatment treatment) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMM d, yyyy • h:mm a').format(treatment.timestamp),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFA8A29E),
                      ),
                    ),
                    Text(
                      'Administered by: ${treatment.nurseName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF78716C),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '₦${treatment.totalCharge.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...treatment.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.name} (x${item.quantity})',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        '₦${item.unitPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF78716C),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _showAddTreatmentDialog(BuildContext context, UserProfile profile) {
    showDialog(
      context: context,
      builder: (context) => SimpleAddTreatmentDialog(
        patient: widget.patient,
        profile: profile,
      ),
    );
  }

  void _showDischargeDialog(BuildContext context, DataProvider dataProvider) {
    // Calculate unpaid balance and pending treatments
    final treatments = dataProvider.treatments;
    final payments = dataProvider.payments;

    final totalBilled = treatments.fold<int>(0, (sum, treatment) => sum + treatment.totalCharge);
    final totalPaid = payments.fold<int>(0, (sum, payment) => sum + payment.amount);
    final balance = totalBilled - totalPaid;

    // Check for pending treatments awaiting pricing
    final pendingTreatments = treatments.where((t) => t.pricingStatus == TreatmentPricingStatus.pending).length;

    // If there are pending treatments, show pending warning dialog instead
    if (pendingTreatments > 0) {
      _showPendingTreatmentsWarning(context, pendingTreatments);
      return;
    }

    // If there's an unpaid balance, show unpaid balance warning dialog instead
    if (balance > 0) {
      _showUnpaidBalanceWarning(context, balance);
      return;
    }

    // Show standard discharge confirmation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(50),
          ),
          child: const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF10B981),
            size: 32,
          ),
        ),
        title: const Text(
          'Discharge Patient',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ready to discharge ${widget.patient.name}?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF059669),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'All bills have been paid',
                      style: TextStyle(
                        color: Color(0xFF065F46),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF78716C)),
            ),
          ),
          ElevatedButton(
            onPressed: () => _performDischarge(context, dataProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Discharge Patient',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUnpaidBalanceWarning(BuildContext context, int balance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(50),
          ),
          child: const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFDC2626),
            size: 32,
          ),
        ),
        title: const Text(
          'Unpaid Bills Warning',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFDC2626),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cannot discharge ${widget.patient.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This patient has outstanding bills that must be settled before discharge.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF78716C)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFECACA),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Outstanding Balance',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7F1D1D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₦${balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '📋 Please direct the patient to the cashier to settle all outstanding payments before proceeding with discharge.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF78716C),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Understood',
              style: TextStyle(color: Color(0xFF78716C)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close warning dialog
              // Navigate to billing - you might want to implement this
              _navigateToBilling(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Go to Billing',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPendingTreatmentsWarning(BuildContext context, int pendingCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(50),
          ),
          child: const Icon(
            Icons.pending_actions,
            color: Color(0xFFD97706),
            size: 32,
          ),
        ),
        title: const Text(
          'Pending Treatments Warning',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFD97706),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cannot discharge ${widget.patient.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This patient has $pendingCount treatment${pendingCount > 1 ? 's' : ''} awaiting pricing by doctor/admin.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF78716C)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFDE68A),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.pending_actions,
                        color: Color(0xFFD97706),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Pending Treatments',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$pendingCount treatment${pendingCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '⏳ Please wait for doctor/admin to price all treatments before discharge.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF78716C),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Understood',
              style: TextStyle(color: Color(0xFF78716C)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close warning dialog
              // Could navigate to admin dashboard for pricing
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performDischarge(BuildContext context, DataProvider dataProvider) async {
    try {
      await dataProvider.dischargePatient(widget.patient.id);
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        Navigator.of(context).pop(); // Return to patient list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('${widget.patient.name} discharged successfully'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Error discharging patient: $e'),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _navigateToBilling(BuildContext context) {
    // This would navigate to the billing screen for this patient
    // For now, just show a placeholder message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Billing navigation feature coming soon'),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  List<Treatment> _filterTreatments(List<Treatment> treatments) {
    List<Treatment> filtered = treatments;

    // Filter by pricing status
    if (_treatmentFilter == 'pending') {
      filtered = filtered.where((t) => t.pricingStatus == TreatmentPricingStatus.pending).toList();
    } else if (_treatmentFilter == 'priced') {
      filtered = filtered.where((t) => t.pricingStatus == TreatmentPricingStatus.priced).toList();
    }

    // Filter by nurse
    if (_nurseFilter != 'all') {
      filtered = filtered.where((t) => t.nurseName == _nurseFilter).toList();
    }

    // Filter by date range
    if (_startDate != null) {
      filtered = filtered.where((t) => t.timestamp.isAfter(_startDate!)).toList();
    }
    if (_endDate != null) {
      final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      filtered = filtered.where((t) => t.timestamp.isBefore(endOfDay)).toList();
    }

    return filtered;
  }

  bool _hasActiveFilters() {
    return _treatmentFilter != 'all' ||
           _nurseFilter != 'all' ||
           _startDate != null ||
           _endDate != null;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => FilterDialog(
        currentTreatmentFilter: _treatmentFilter,
        currentNurseFilter: _nurseFilter,
        currentStartDate: _startDate,
        currentEndDate: _endDate,
        availableNurses: _getAvailableNurses(),
        onApplyFilters: (treatmentFilter, nurseFilter, startDate, endDate) {
          setState(() {
            _treatmentFilter = treatmentFilter;
            _nurseFilter = nurseFilter;
            _startDate = startDate;
            _endDate = endDate;
          });
        },
      ),
    );
  }

  List<String> _getAvailableNurses() {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final nurses = dataProvider.treatments
        .map((t) => t.nurseName)
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    nurses.sort();
    return nurses;
  }
}

class FilterDialog extends StatefulWidget {
  final String currentTreatmentFilter;
  final String currentNurseFilter;
  final DateTime? currentStartDate;
  final DateTime? currentEndDate;
  final List<String> availableNurses;
  final Function(String, String, DateTime?, DateTime?) onApplyFilters;

  const FilterDialog({
    super.key,
    required this.currentTreatmentFilter,
    required this.currentNurseFilter,
    required this.currentStartDate,
    required this.currentEndDate,
    required this.availableNurses,
    required this.onApplyFilters,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late String _treatmentFilter;
  late String _nurseFilter;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _treatmentFilter = widget.currentTreatmentFilter;
    _nurseFilter = widget.currentNurseFilter;
    _startDate = widget.currentStartDate;
    _endDate = widget.currentEndDate;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Treatments'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pricing Status Filter
            const Text(
              'Pricing Status',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _treatmentFilter,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'priced', child: Text('Priced')),
              ],
              onChanged: (value) => setState(() => _treatmentFilter = value!),
            ),
            const SizedBox(height: 16),

            // Nurse Filter
            const Text(
              'Nurse',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: widget.availableNurses.contains(_nurseFilter) ? _nurseFilter : 'all',
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All Nurses')),
                ...widget.availableNurses.map((nurse) =>
                  DropdownMenuItem(value: nurse, child: Text(nurse)),
                ),
              ],
              onChanged: (value) => setState(() => _nurseFilter = value!),
            ),
            const SizedBox(height: 16),

            // Date Range
            const Text(
              'Date Range',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _startDate != null
                            ? DateFormat('MMM dd').format(_startDate!)
                            : 'Start Date',
                        style: TextStyle(
                          color: _startDate != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('to'),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _endDate != null
                            ? DateFormat('MMM dd').format(_endDate!)
                            : 'End Date',
                        style: TextStyle(
                          color: _endDate != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _treatmentFilter = 'all';
              _nurseFilter = 'all';
              _startDate = null;
              _endDate = null;
            });
          },
          child: const Text('Clear All'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApplyFilters(_treatmentFilter, _nurseFilter, _startDate, _endDate);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
    }
  }
}