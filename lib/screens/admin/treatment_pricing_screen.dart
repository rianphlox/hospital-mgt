import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/patient_models.dart';
import '../../models/user_models.dart';
import '../../services/data_service.dart';
import '../../providers/data_provider.dart';

class TreatmentPricingScreen extends StatefulWidget {
  final UserProfile profile;

  const TreatmentPricingScreen({
    super.key,
    required this.profile,
  });

  @override
  State<TreatmentPricingScreen> createState() => _TreatmentPricingScreenState();
}

class _TreatmentPricingScreenState extends State<TreatmentPricingScreen> {
  String _searchQuery = '';
  List<Treatment> _pendingTreatments = [];
  List<Patient> _patients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final treatments = await DataService.getPendingTreatments();
      final patients = await DataService.getAllPatients();

      setState(() {
        _pendingTreatments = treatments;
        _patients = patients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
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
        title: const Text('Treatment Pricing'),
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
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE7E5E4)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PENDING PRICING',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFA8A29E),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _pendingTreatments.length.toString(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEAB308),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.pending_actions,
                            color: Color(0xFFEAB308),
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Search bar
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: const InputDecoration(
                      hintText: 'Search by patient name or nurse...',
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
                  const SizedBox(height: 24),

                  // Treatments list
                  Expanded(
                    child: _buildTreatmentsList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTreatmentsList() {
    final filteredTreatments = _filterTreatments();

    if (filteredTreatments.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      itemCount: filteredTreatments.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final treatment = filteredTreatments[index];
        final patient = _patients.firstWhere(
          (p) => p.id == treatment.patientId,
          orElse: () => Patient(
            id: '',
            name: 'Unknown Patient',
            admissionNumber: '',
            ward: '',
            type: PatientType.outPatient,
            status: PatientStatus.active,
            createdAt: DateTime.now(),
          ),
        );

        return _buildTreatmentCard(treatment, patient);
      },
    );
  }

  Widget _buildTreatmentCard(Treatment treatment, Patient patient) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    treatment.pricingStatus.displayName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEAB308),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Treatment info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text(
                        'Nurse: ${treatment.nurseName}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Logged: ${_formatDate(treatment.timestamp)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  if (treatment.shift != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          'Shift: ${treatment.shift!.displayName}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Items list
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Treatment Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(height: 8),
                ...treatment.items.map((item) => _buildItemRow(item)),
              ],
            ),
            const SizedBox(height: 16),

            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showPricingDialog(treatment, patient),
                icon: const Icon(Icons.attach_money, size: 20),
                label: const Text(
                  'Set Pricing',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(TreatmentItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7E5E4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1C1917),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Qty: ${item.quantity}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'Pending',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFEAB308),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
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
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 40,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'All treatments priced!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1917),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No pending treatments need pricing',
            style: TextStyle(
              color: Color(0xFF78716C),
            ),
          ),
        ],
      ),
    );
  }

  List<Treatment> _filterTreatments() {
    if (_searchQuery.isEmpty) return _pendingTreatments;

    return _pendingTreatments.where((treatment) {
      final patient = _patients.firstWhere(
        (p) => p.id == treatment.patientId,
        orElse: () => Patient(
          id: '',
          name: '',
          admissionNumber: '',
          ward: '',
          type: PatientType.outPatient,
          status: PatientStatus.active,
          createdAt: DateTime.now(),
        ),
      );

      final query = _searchQuery.toLowerCase();
      return patient.name.toLowerCase().contains(query) ||
          treatment.nurseName.toLowerCase().contains(query) ||
          patient.admissionNumber.toLowerCase().contains(query);
    }).toList();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showPricingDialog(Treatment treatment, Patient patient) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PricingDialog(
        treatment: treatment,
        patient: patient,
        adminProfile: widget.profile,
        onComplete: _loadData,
      ),
    );
  }
}

class _PricingDialog extends StatefulWidget {
  final Treatment treatment;
  final Patient patient;
  final UserProfile adminProfile;
  final VoidCallback onComplete;

  const _PricingDialog({
    required this.treatment,
    required this.patient,
    required this.adminProfile,
    required this.onComplete,
  });

  @override
  State<_PricingDialog> createState() => _PricingDialogState();
}

class _PricingDialogState extends State<_PricingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _totalAmountController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _totalAmountController.text = '';
  }

  @override
  void dispose() {
    _totalAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE7E5E4))),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Set Treatment Pricing',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Patient: ${widget.patient.name}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Treatment info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Logged by: ${widget.treatment.nurseName}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF475569),
                              ),
                            ),
                            if (widget.treatment.shift != null)
                              Text(
                                'Shift: ${widget.treatment.shift!.displayName}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            Text(
                              'Date: ${_formatDate(widget.treatment.timestamp)}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Treatment Items (Read-only)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE7E5E4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Treatment Items',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1C1917),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...widget.treatment.items.map((item) => Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    'Qty: ${item.quantity}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Total Amount Input
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.attach_money,
                                  color: Color(0xFF10B981),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Total Treatment Bill',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1C1917),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Enter the total amount to charge for this treatment',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF059669),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _totalAmountController,
                              decoration: const InputDecoration(
                                labelText: 'Total Amount (₦)',
                                hintText: 'e.g., 5000',
                                prefixText: '₦ ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                  borderSide: BorderSide(color: Color(0xFF10B981)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                  borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.all(12),
                              ),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter treatment amount';
                                }
                                final amount = int.tryParse(value.replaceAll(',', ''));
                                if (amount == null || amount <= 0) {
                                  return 'Please enter a valid amount';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE7E5E4))),
              ),
              child: Row(
                children: [
                  // Total Display
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '₦${_getDisplayTotal()}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Actions
                  Row(
                    children: [
                      TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitPricing,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save Pricing'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDisplayTotal() {
    final value = _totalAmountController.text.replaceAll(',', '');
    final amount = int.tryParse(value);
    return amount?.toString() ?? '0';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submitPricing() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final totalAmount = int.parse(_totalAmountController.text.replaceAll(',', ''));
      final originalItems = widget.treatment.items;

      final updatedTreatment = Treatment(
        id: widget.treatment.id,
        patientId: widget.treatment.patientId,
        nurseId: widget.treatment.nurseId,
        nurseName: widget.treatment.nurseName,
        items: originalItems,
        totalCharge: totalAmount,
        timestamp: widget.treatment.timestamp,
        shift: widget.treatment.shift,
        pricingStatus: TreatmentPricingStatus.priced,
        adminId: widget.adminProfile.uid,
        adminName: widget.adminProfile.name,
        pricedAt: DateTime.now(),
      );

      await DataService.updateTreatmentPricing(updatedTreatment);

      if (mounted) {
        // Refresh dashboard stats
        final dataProvider = Provider.of<DataProvider>(context, listen: false);
        await dataProvider.refreshStats();

        if (mounted) {
          Navigator.of(context).pop();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Treatment pricing saved successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving pricing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}