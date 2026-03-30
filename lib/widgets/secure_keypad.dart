import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/security_service.dart';

class SecureKeypad extends StatefulWidget {
  final Function(String) onNumberPressed;
  final VoidCallback? onDeletePressed;
  final VoidCallback? onClearPressed;
  final String title;
  final String? subtitle;
  final Widget? customHeader;
  final bool showBiometricOption;
  final VoidCallback? onBiometricPressed;
  final SecurityLevel securityLevel;

  const SecureKeypad({
    super.key,
    required this.onNumberPressed,
    this.onDeletePressed,
    this.onClearPressed,
    this.title = 'Secure Payment Entry',
    this.subtitle,
    this.customHeader,
    this.showBiometricOption = true,
    this.onBiometricPressed,
    this.securityLevel = SecurityLevel.enhanced,
  });

  @override
  State<SecureKeypad> createState() => _SecureKeypadState();
}

class _SecureKeypadState extends State<SecureKeypad>
    with TickerProviderStateMixin {
  bool _isSecurityActive = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeSecurity();
    _setupAnimations();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  Future<void> _initializeSecurity() async {
    await SecurityService().enableSecureContext(
      SecureContext.paymentEntry,
      level: widget.securityLevel,
      message: 'Securing payment keypad...',
    );

    if (mounted) {
      setState(() => _isSecurityActive = true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    SecurityService().disableSecureContext();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Security Header
          _buildSecurityHeader(),

          // Custom Header if provided
          if (widget.customHeader != null) widget.customHeader!,

          // Keypad
          Padding(
            padding: const EdgeInsets.all(24),
            child: _buildKeypad(),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityHeader() {
    return StreamBuilder<String>(
      stream: SecurityService().securityStatusStream,
      builder: (context, snapshot) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.shade600,
                Colors.green.shade700,
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Security indicator with animation
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isSecurityActive ? _pulseAnimation.value : 1.0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.security,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              snapshot.data ?? 'Securing keypad...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Protected from screenshots & recording',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              if (widget.subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  widget.subtitle!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        // Numbers 1-9
        for (int row = 0; row < 3; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int col = 1; col <= 3; col++)
                  _buildKeypadButton(
                    text: '${(row * 3) + col}',
                    onPressed: () => _handleNumberPress('${(row * 3) + col}'),
                  ),
              ],
            ),
          ),

        // Bottom row: *, 0, #
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Biometric option or empty
              widget.showBiometricOption
                  ? _buildKeypadButton(
                      icon: Icons.fingerprint,
                      onPressed: widget.onBiometricPressed ?? _handleBiometric,
                      isSpecial: true,
                    )
                  : _buildKeypadButton(
                      text: '*',
                      onPressed: () => _handleNumberPress('*'),
                      isSpecial: true,
                    ),

              // Zero
              _buildKeypadButton(
                text: '0',
                onPressed: () => _handleNumberPress('0'),
              ),

              // Delete
              _buildKeypadButton(
                icon: Icons.backspace_outlined,
                onPressed: widget.onDeletePressed ?? _handleDelete,
                isSpecial: true,
              ),
            ],
          ),
        ),

        // Clear button if callback provided
        if (widget.onClearPressed != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: widget.onClearPressed,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                ),
                child: const Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildKeypadButton({
    String? text,
    IconData? icon,
    required VoidCallback onPressed,
    bool isSpecial = false,
  }) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: isSpecial ? Colors.green.shade300 : Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: isSpecial ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(36),
        child: InkWell(
          onTap: () {
            _provideTactileFeedback();
            onPressed();
          },
          borderRadius: BorderRadius.circular(36),
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    size: 24,
                    color: isSpecial ? Colors.green.shade700 : Colors.grey.shade700,
                  )
                : Text(
                    text!,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isSpecial ? Colors.green.shade700 : Colors.grey.shade800,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _provideTactileFeedback() {
    HapticFeedback.lightImpact();
  }

  void _handleNumberPress(String number) {
    _provideTactileFeedback();
    widget.onNumberPressed(number);
  }

  void _handleDelete() {
    _provideTactileFeedback();
    // Default delete behavior if no callback provided
  }

  Future<void> _handleBiometric() async {
    _provideTactileFeedback();

    final isAuthenticated = await SecurityService().authenticateWithBiometrics(
      reason: 'Please authenticate to proceed with payment',
    );

    if (isAuthenticated && widget.onBiometricPressed != null) {
      widget.onBiometricPressed!();
    } else if (isAuthenticated) {
      // Default biometric success action
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Biometric authentication successful'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

// Secure Payment Amount Display Widget
class SecureAmountDisplay extends StatelessWidget {
  final String amount;
  final String currency;
  final String? label;
  final bool showSecurity;

  const SecureAmountDisplay({
    super.key,
    required this.amount,
    this.currency = '₦',
    this.label,
    this.showSecurity = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: showSecurity ? Colors.green.shade300 : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                currency,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                amount.isEmpty ? '0' : amount,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (showSecurity) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.shield,
                  color: Colors.green.shade600,
                  size: 20,
                ),
              ],
            ],
          ),
          if (showSecurity) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Protected Entry',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}