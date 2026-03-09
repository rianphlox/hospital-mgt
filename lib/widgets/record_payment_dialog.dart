import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/patient_models.dart';
import '../models/user_models.dart';
import '../providers/data_provider.dart';

class RecordPaymentDialog extends StatefulWidget {
  final Patient patient;
  final UserProfile profile;

  const RecordPaymentDialog({
    super.key,
    required this.patient,
    required this.profile,
  });

  @override
  State<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedMethod = 'Cash';
  final List<String> _paymentMethods = ['Cash', 'Transfer', 'Card'];

  int _totalBill = 0;
  int _totalPaid = 0;
  int _currentBalance = 0;
  bool _isPartialPayment = false;

  @override
  void initState() {
    super.initState();
    _calculateBillSummary();
  }

  void _calculateBillSummary() {
    final provider = Provider.of<DataProvider>(context, listen: false);

    // Calculate total bill from treatments
    final treatments = provider.treatments;
    _totalBill = treatments.fold(0, (sum, treatment) => sum + treatment.totalCharge);

    // Calculate total payments made
    final payments = provider.payments;
    _totalPaid = payments.fold(0, (sum, payment) => sum + payment.amount);

    // Add outstanding balance from previous visits
    _totalBill += widget.patient.outstandingBalance;

    // Calculate current balance
    _currentBalance = _totalBill - _totalPaid;

    setState(() {});
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                'Receive Payment',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Amount input
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Amount (₦)',
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
                      contentPadding: EdgeInsets.all(20),
                    ),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please enter amount';
                      }
                      final amount = int.tryParse(value!);
                      if (amount == null || amount <= 0) {
                        return 'Please enter valid amount';
                      }
                      if (_isPartialPayment && amount > _currentBalance) {
                        return 'Amount cannot exceed outstanding balance';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Bill Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Bill:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '₦${_totalBill.toString()}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Paid:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '₦${_totalPaid.toString()}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Outstanding Balance:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '₦${_currentBalance.toString()}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _currentBalance > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Payment Type Toggle
              if (_currentBalance > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Type',
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
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isPartialPayment = false;
                                _amountController.text = _currentBalance.toString();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: !_isPartialPayment ? const Color(0xFF10B981) : const Color(0xFFFAFAF9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: !_isPartialPayment ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                'Full Payment',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: !_isPartialPayment ? Colors.white : const Color(0xFF78716C),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isPartialPayment = true;
                                _amountController.clear();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _isPartialPayment ? const Color(0xFF10B981) : const Color(0xFFFAFAF9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isPartialPayment ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                'Partial Payment',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _isPartialPayment ? Colors.white : const Color(0xFF78716C),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),

              // Payment method selector
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Method',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA8A29E),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _paymentMethods.map((method) {
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(
                            right: method == _paymentMethods.last ? 0 : 8,
                          ),
                          child: _buildMethodButton(method),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 32),

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
                          onPressed: dataProvider.isLoading
                              ? null
                              : _submitPayment,
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
                                  'Confirm Payment',
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

  Widget _buildMethodButton(String method) {
    final isSelected = _selectedMethod == method;

    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981) : const Color(0xFFFAFAF9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          method,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF78716C),
          ),
        ),
      ),
    );
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = int.parse(_amountController.text);

    final payment = Payment(
      id: '', // Will be generated by Firestore
      patientId: widget.patient.id,
      cashierId: widget.profile.uid,
      cashierName: widget.profile.name,
      amount: amount,
      paymentMethod: _selectedMethod,
      timestamp: DateTime.now(),
      paymentType: _isPartialPayment ? PaymentType.partial : PaymentType.full,
      originalBillAmount: _isPartialPayment ? _currentBalance : null,
      notes: _isPartialPayment && _notesController.text.isNotEmpty ? _notesController.text : null,
    );

    try {
      await context.read<DataProvider>().addPayment(
            widget.patient.id,
            payment,
          );

      if (mounted) {
        Navigator.of(context).pop();
        final remainingBalance = _currentBalance - amount;
        final message = _isPartialPayment && remainingBalance > 0
            ? 'Partial payment of ₦${amount.toString()} recorded. Outstanding: ₦${remainingBalance.toString()}'
            : 'Payment of ₦${amount.toString()} recorded successfully';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}