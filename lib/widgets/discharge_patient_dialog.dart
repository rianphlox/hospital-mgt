import 'package:flutter/material.dart';
import '../models/patient_models.dart';
import '../models/user_models.dart';
import '../services/data_service.dart';

class DischargePatientDialog extends StatefulWidget {
  final Patient patient;
  final UserProfile adminProfile;
  final VoidCallback onSuccess;

  const DischargePatientDialog({
    super.key,
    required this.patient,
    required this.adminProfile,
    required this.onSuccess,
  });

  @override
  State<DischargePatientDialog> createState() => _DischargePatientDialogState();
}

class _DischargePatientDialogState extends State<DischargePatientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _billAmountController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  int _calculatedBill = 0;

  @override
  void initState() {
    super.initState();
    _loadPatientBill();
  }

  Future<void> _loadPatientBill() async {
    setState(() => _isLoading = true);

    try {
      final totalBill = await DataService.calculatePatientTotalBill(widget.patient.id);
      setState(() {
        _calculatedBill = totalBill;
        _billAmountController.text = totalBill.toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading bill: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.logout,
                      color: Color(0xFFDC2626),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Discharge Patient',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Patient: ${widget.patient.name}',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Patient info summary
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Patient Information',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'ID: ${widget.patient.admissionNumber}',
                                          style: const TextStyle(
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          'Ward: ${widget.patient.ward}',
                                          style: const TextStyle(
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Type: ${widget.patient.type.displayName}',
                                    style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Bill amount section
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Final Bill Amount',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF10B981)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        color: Color(0xFF10B981),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Calculated from priced treatments: ₦${_calculatedBill.toString()}',
                                        style: const TextStyle(
                                          color: Color(0xFF065F46),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _billAmountController,
                                  decoration: const InputDecoration(
                                    labelText: 'Final Amount (₦)',
                                    border: OutlineInputBorder(),
                                    prefixText: '₦ ',
                                    helperText: 'You can adjust the final amount if needed',
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    final amount = int.tryParse(value ?? '');
                                    if (amount == null || amount < 0) {
                                      return 'Enter a valid amount';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Discharge notes
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Discharge Notes',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _notesController,
                                      decoration: const InputDecoration(
                                        hintText: 'Enter discharge notes, medications, follow-up instructions...',
                                        border: OutlineInputBorder(),
                                        alignLabelWithHint: true,
                                      ),
                                      maxLines: null,
                                      expands: true,
                                      textAlignVertical: TextAlignVertical.top,
                                    ),
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
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _dischargePatient,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Discharge Patient',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dischargePatient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final billAmount = int.parse(_billAmountController.text);

      await DataService.dischargePatientWithBilling(
        patientId: widget.patient.id,
        finalBillAmount: billAmount,
        adminId: widget.adminProfile.uid,
        adminName: widget.adminProfile.name,
        dischargeNotes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient discharged successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error discharging patient: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _billAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}