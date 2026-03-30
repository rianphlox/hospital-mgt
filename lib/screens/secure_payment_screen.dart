import 'package:flutter/material.dart';
import '../widgets/secure_keypad.dart';
import '../services/security_service.dart';
import '../models/patient_models.dart';

class SecurePaymentScreen extends StatefulWidget {
  final Patient patient;
  final int totalBillAmount;
  final String cashierName;
  final String cashierId;

  const SecurePaymentScreen({
    super.key,
    required this.patient,
    required this.totalBillAmount,
    required this.cashierName,
    required this.cashierId,
  });

  @override
  State<SecurePaymentScreen> createState() => _SecurePaymentScreenState();
}

class _SecurePaymentScreenState extends State<SecurePaymentScreen> {
  String _enteredAmount = '';
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  bool _isProcessing = false;
  bool _isBiometricVerified = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Initialize security when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSecurity();
    });
  }

  Future<void> _initializeSecurity() async {
    await SecurityService().enableSecureContext(
      SecureContext.paymentEntry,
      level: SecurityLevel.enhanced,
    );
  }

  @override
  void dispose() {
    SecurityService().disableSecureContext();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Secure Payment Entry'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: _handleBackPress,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          // Security indicator
          StreamBuilder<String>(
            stream: SecurityService().securityStatusStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.security,
                        color: Colors.green.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Secured',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentPage = index),
        children: [
          _buildAmountEntryPage(),
          _buildPaymentMethodPage(),
          _buildConfirmationPage(),
        ],
      ),
    );
  }

  Widget _buildAmountEntryPage() {
    return Column(
      children: [
        // Patient Info Header
        _buildPatientInfoHeader(),

        // Amount Display
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Enter Payment Amount',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total Bill: ₦${_formatNumber(widget.totalBillAmount)}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),

              // Secure Amount Display
              SecureAmountDisplay(
                amount: _formatNumber(_enteredAmount.isEmpty ? 0 : int.parse(_enteredAmount)),
                label: 'Payment Amount',
              ),

              const SizedBox(height: 24),

              // Quick Amount Buttons
              _buildQuickAmountButtons(),
            ],
          ),
        ),

        // Secure Keypad
        SecureKeypad(
          title: 'Secure Payment Keypad',
          subtitle: 'Enter the payment amount',
          onNumberPressed: _handleNumberInput,
          onDeletePressed: _handleDelete,
          onClearPressed: _handleClear,
          onBiometricPressed: _handleBiometricAuth,
          showBiometricOption: true,
        ),

        // Next Button
        _buildNextButton(
          text: 'Continue to Payment Method',
          onPressed: _enteredAmount.isNotEmpty ? _goToPaymentMethod : null,
        ),
      ],
    );
  }

  Widget _buildPaymentMethodPage() {
    return Column(
      children: [
        _buildPatientInfoHeader(),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Payment Method',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Amount: ₦${_formatNumber(int.parse(_enteredAmount))}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),

                // Payment method options
                ...PaymentMethod.values.map((method) =>
                  _buildPaymentMethodOption(method)
                ),

                const Spacer(),

                // Security reminder
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'All payment information is encrypted and protected from screenshots.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        _buildNextButton(
          text: 'Continue to Confirmation',
          onPressed: _goToConfirmation,
        ),
      ],
    );
  }

  Widget _buildConfirmationPage() {
    return Column(
      children: [
        _buildPatientInfoHeader(),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Confirm Payment Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),

                // Payment summary
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Patient', widget.patient.name),
                      _buildSummaryRow('Admission #', widget.patient.admissionNumber),
                      const Divider(height: 24),
                      _buildSummaryRow('Payment Amount', '₦${_formatNumber(int.parse(_enteredAmount))}'),
                      _buildSummaryRow('Payment Method', _selectedPaymentMethod.displayName),
                      _buildSummaryRow('Total Bill', '₦${_formatNumber(widget.totalBillAmount)}'),
                      const Divider(height: 24),
                      _buildSummaryRow(
                        'Remaining Balance',
                        '₦${_formatNumber(widget.totalBillAmount - int.parse(_enteredAmount))}',
                        isHighlighted: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Biometric verification requirement
                if (!_isBiometricVerified)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.fingerprint,
                          color: Colors.orange.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Biometric Verification Required',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              Text(
                                'Please authenticate to process this payment',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _handleBiometricAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade600,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Verify'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        _buildNextButton(
          text: _isProcessing ? 'Processing...' : 'Process Payment',
          onPressed: _isBiometricVerified && !_isProcessing ? _processPayment : null,
          isProcessing: _isProcessing,
        ),
      ],
    );
  }

  Widget _buildPatientInfoHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            child: Text(
              widget.patient.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patient.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Admission #${widget.patient.admissionNumber}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.security,
                  color: Colors.green.shade700,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  'Secured',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAmountButtons() {
    final quickAmounts = [
      widget.totalBillAmount ~/ 4,
      widget.totalBillAmount ~/ 2,
      widget.totalBillAmount,
    ];

    return Wrap(
      spacing: 12,
      children: quickAmounts.map((amount) =>
        OutlinedButton(
          onPressed: () => _setQuickAmount(amount),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.green.shade300),
            foregroundColor: Colors.green.shade700,
          ),
          child: Text('₦${_formatNumber(amount)}'),
        )
      ).toList(),
    );
  }

  Widget _buildPaymentMethodOption(PaymentMethod method) {
    final isSelected = _selectedPaymentMethod == method;

    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = method),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.green.shade300 : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              _getPaymentMethodIcon(method),
              color: isSelected ? Colors.green.shade700 : Colors.grey.shade600,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                method.displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.green.shade700 : Colors.black,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Colors.green.shade700,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isHighlighted ? 16 : 14,
              color: isHighlighted ? Colors.green.shade700 : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton({
    required String text,
    required VoidCallback? onPressed,
    bool isProcessing = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  // Event Handlers

  void _handleNumberInput(String number) {
    if (_enteredAmount.length < 10) {
      setState(() {
        _enteredAmount = _enteredAmount + number;
      });
    }
  }

  void _handleDelete() {
    if (_enteredAmount.isNotEmpty) {
      setState(() {
        _enteredAmount = _enteredAmount.substring(0, _enteredAmount.length - 1);
      });
    }
  }

  void _handleClear() {
    setState(() {
      _enteredAmount = '';
    });
  }

  void _setQuickAmount(int amount) {
    setState(() {
      _enteredAmount = amount.toString();
    });
  }

  Future<void> _handleBiometricAuth() async {
    final isAuthenticated = await SecurityService().authenticateWithBiometrics(
      reason: 'Authenticate to authorize this payment transaction',
    );

    if (isAuthenticated) {
      setState(() {
        _isBiometricVerified = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Authentication successful'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _goToPaymentMethod() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToConfirmation() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));

      // Create payment object
      final payment = Payment(
        id: '',
        patientId: widget.patient.id,
        amount: int.parse(_enteredAmount),
        paymentMethod: _selectedPaymentMethod.displayName,
        cashierName: widget.cashierName,
        cashierId: widget.cashierId,
        timestamp: DateTime.now(),
        paymentType: int.parse(_enteredAmount) >= widget.totalBillAmount
            ? PaymentType.full
            : PaymentType.partial,
        originalBillAmount: widget.totalBillAmount,
      );

      // TODO: Process payment through DataProvider
      // await context.read<DataProvider>().addPayment(widget.patient.id, payment);

      if (mounted) {
        Navigator.of(context).pop(payment);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Payment processed successfully'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _handleBackPress() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  // Helper methods

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  IconData _getPaymentMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.payments;
      case PaymentMethod.card:
        return Icons.credit_card;
      case PaymentMethod.bank:
        return Icons.account_balance;
      case PaymentMethod.insurance:
        return Icons.health_and_safety;
    }
  }
}

enum PaymentMethod {
  cash,
  card,
  bank,
  insurance,
}

extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash Payment';
      case PaymentMethod.card:
        return 'Card Payment';
      case PaymentMethod.bank:
        return 'Bank Transfer';
      case PaymentMethod.insurance:
        return 'Insurance';
    }
  }
}