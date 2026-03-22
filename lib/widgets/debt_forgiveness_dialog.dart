import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/patient_models.dart';
import '../models/user_models.dart';
import '../providers/data_provider.dart';

class DebtForgivenessDialog extends StatefulWidget {
  final Patient patient;
  final UserProfile profile;

  const DebtForgivenessDialog({
    super.key,
    required this.patient,
    required this.profile,
  });

  @override
  State<DebtForgivenessDialog> createState() => _DebtForgivenessDialogState();
}

class _DebtForgivenessDialogState extends State<DebtForgivenessDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _amountController = TextEditingController();

  bool _forgiveFullBalance = true;

  @override
  void initState() {
    super.initState();
    // Initialize with full outstanding balance
    _amountController.text = widget.patient.outstandingBalance.toString();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.money_off,
                    size: 32,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Debt Forgiveness',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Patient: ${widget.patient.name}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Outstanding Balance Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Outstanding Balance:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '₦${widget.patient.outstandingBalance.toString()}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Forgiveness Type
              const Text(
                'Forgiveness Type',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFA8A29E),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      leading: Radio<bool>(
                        value: true,
                        groupValue: _forgiveFullBalance,
                        onChanged: (value) {
                          setState(() {
                            _forgiveFullBalance = value!;
                            if (_forgiveFullBalance) {
                              _amountController.text = widget.patient.outstandingBalance.toString();
                            }
                          });
                        },
                      ),
                      title: const Text('Full Balance'),
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        setState(() {
                          _forgiveFullBalance = true;
                          _amountController.text = widget.patient.outstandingBalance.toString();
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      leading: Radio<bool>(
                        value: false,
                        groupValue: _forgiveFullBalance,
                        onChanged: (value) {
                          setState(() {
                            _forgiveFullBalance = value!;
                            if (!_forgiveFullBalance) {
                              _amountController.clear();
                            }
                          });
                        },
                      ),
                      title: const Text('Partial Amount'),
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        setState(() {
                          _forgiveFullBalance = false;
                          _amountController.clear();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount input (if partial)
              if (!_forgiveFullBalance)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount to Forgive (₦)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFA8A29E),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        hintText: '0',
                        contentPadding: EdgeInsets.all(16),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Please enter amount';
                        }
                        final amount = int.tryParse(value!);
                        if (amount == null || amount <= 0) {
                          return 'Please enter valid amount';
                        }
                        if (amount > widget.patient.outstandingBalance) {
                          return 'Amount cannot exceed outstanding balance';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              // Reason input
              const Text(
                'Reason for Forgiveness',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFA8A29E),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  hintText: 'Enter reason for debt forgiveness...',
                  contentPadding: EdgeInsets.all(16),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please provide a reason for forgiveness';
                  }
                  if (value!.length < 10) {
                    return 'Please provide a detailed reason (at least 10 characters)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Warning message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This action cannot be undone. Please ensure you have proper authorization.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF78716C),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Consumer<DataProvider>(
                      builder: (context, dataProvider, _) {
                        return ElevatedButton(
                          onPressed: dataProvider.isLoading ? null : _submitForgiveness,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade600,
                            foregroundColor: Colors.white,
                          ),
                          child: dataProvider.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Forgive Debt',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitForgiveness() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = int.parse(_amountController.text);

    final forgiveness = DebtForgiveness(
      id: '', // Will be generated by Firestore
      patientId: widget.patient.id,
      adminId: widget.profile.uid,
      adminName: widget.profile.name,
      forgivenAmount: amount,
      reason: _reasonController.text.trim(),
      timestamp: DateTime.now(),
    );

    try {
      await context.read<DataProvider>().addDebtForgiveness(
            widget.patient.id,
            forgiveness,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Debt of ₦${amount.toString()} forgiven for ${widget.patient.name}',
            ),
            backgroundColor: Colors.orange.shade600,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error forgiving debt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}