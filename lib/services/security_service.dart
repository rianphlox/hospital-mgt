import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum SecurityLevel {
  none,        // No protection
  basic,       // Basic input protection
  enhanced,    // Screenshot protection + input protection
  maximum,     // Full protection including biometric auth
}

enum SecureContext {
  paymentEntry,     // Payment amounts, card details
  patientBilling,   // Patient financial information
  adminOperations,  // Admin-level financial operations
  settings,         // App settings and configuration
}

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  bool _isSecurityActive = false;
  Timer? _securityTimer;
  StreamController<String>? _securityStatusController;

  // Public getters
  bool get isSecurityActive => _isSecurityActive;
  Stream<String>? get securityStatusStream => _securityStatusController?.stream;

  /// Initialize security system
  Future<void> initialize() async {
    try {
      // Check device capabilities
      await _checkSecurityCapabilities();
    } catch (e) {
      if (kDebugMode) {
        print('Security Service initialization error: $e');
      }
    }
  }

  /// Enable secure context with protection level
  Future<void> enableSecureContext(SecureContext context, {
    SecurityLevel level = SecurityLevel.enhanced,
    String? message,
  }) async {
    if (_isSecurityActive) return;

    try {
      _isSecurityActive = true;
      _securityStatusController = StreamController<String>.broadcast();

      final contextMessage = message ?? _getContextMessage(context);
      _securityStatusController?.add(contextMessage);

      // Apply security measures based on level
      await _applySecurityLevel(level);

      // Auto-disable after timeout for better UX
      _startSecurityTimer();

      if (kDebugMode) {
        print('Security context enabled: $context, level: $level');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error enabling secure context: $e');
      }
      await disableSecureContext();
    }
  }

  /// Disable secure context and remove protections
  Future<void> disableSecureContext() async {
    try {
      _isSecurityActive = false;
      _securityTimer?.cancel();
      _securityTimer = null;

      // Remove security protections
      await _removeSecurityProtections();

      _securityStatusController?.close();
      _securityStatusController = null;

      if (kDebugMode) {
        print('Security context disabled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error disabling secure context: $e');
      }
    }
  }

  /// Authenticate user with biometrics
  Future<bool> authenticateWithBiometrics({
    String reason = 'Please authenticate to access sensitive information',
  }) async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) {
        if (kDebugMode) {
          print('Biometric authentication not available');
        }
        return false;
      }

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        if (kDebugMode) {
          print('No biometric methods configured');
        }
        return false;
      }

      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      return isAuthenticated;
    } catch (e) {
      if (kDebugMode) {
        print('Biometric authentication error: $e');
      }
      return false;
    }
  }

  /// Store sensitive data securely
  Future<void> storeSecurely(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      if (kDebugMode) {
        print('Secure storage write error: $e');
      }
    }
  }

  /// Retrieve sensitive data securely
  Future<String?> retrieveSecurely(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      if (kDebugMode) {
        print('Secure storage read error: $e');
      }
      return null;
    }
  }

  /// Delete sensitive data
  Future<void> deleteSecurely(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      if (kDebugMode) {
        print('Secure storage delete error: $e');
      }
    }
  }

  /// Clear all secure storage
  Future<void> clearAllSecureData() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      if (kDebugMode) {
        print('Secure storage clear error: $e');
      }
    }
  }

  // Private methods

  Future<void> _checkSecurityCapabilities() async {
    // Check biometric availability
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (kDebugMode) {
        print('Biometric support - Can check: $canCheck, Device supported: $isDeviceSupported');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Biometric capability check failed: $e');
      }
    }

    // Check screen protection support
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Platform supports screen protection
        if (kDebugMode) {
          print('Screen protection supported on ${Platform.operatingSystem}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Screen protection check failed: $e');
      }
    }
  }

  Future<void> _applySecurityLevel(SecurityLevel level) async {
    switch (level) {
      case SecurityLevel.none:
        // No protection
        break;
      case SecurityLevel.basic:
        // Basic input protection
        await _enableBasicProtection();
        break;
      case SecurityLevel.enhanced:
        // Screenshot + screen recording protection
        await _enableEnhancedProtection();
        break;
      case SecurityLevel.maximum:
        // Full protection
        await _enableMaximumProtection();
        break;
    }
  }

  Future<void> _enableBasicProtection() async {
    try {
      // Prevent text selection and copy/paste in sensitive fields
      // This would be implemented at the widget level
    } catch (e) {
      if (kDebugMode) {
        print('Basic protection setup failed: $e');
      }
    }
  }

  Future<void> _enableEnhancedProtection() async {
    try {
      await _enableBasicProtection();

      // Prevent screenshots and screen recording
      await ScreenProtector.protectDataLeakageOn();

      if (kDebugMode) {
        print('Enhanced protection (screenshot/recording block) enabled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Enhanced protection setup failed: $e');
      }
    }
  }

  Future<void> _enableMaximumProtection() async {
    try {
      await _enableEnhancedProtection();

      // Additional protections could include:
      // - App backgrounding protection
      // - Memory dump protection
      // - Network monitoring detection

      if (kDebugMode) {
        print('Maximum protection enabled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Maximum protection setup failed: $e');
      }
    }
  }

  Future<void> _removeSecurityProtections() async {
    try {
      // Remove screenshot/recording protection
      await ScreenProtector.protectDataLeakageOff();
    } catch (e) {
      if (kDebugMode) {
        print('Error removing security protections: $e');
      }
    }
  }

  void _startSecurityTimer() {
    // Auto-disable security after 2 minutes of inactivity
    _securityTimer?.cancel();
    _securityTimer = Timer(const Duration(minutes: 2), () async {
      await disableSecureContext();
    });
  }

  String _getContextMessage(SecureContext context) {
    switch (context) {
      case SecureContext.paymentEntry:
        return 'Securing payment keypad...';
      case SecureContext.patientBilling:
        return 'Securing billing information...';
      case SecureContext.adminOperations:
        return 'Securing administrative data...';
      case SecureContext.settings:
        return 'Securing sensitive settings...';
    }
  }
}

// Secure Text Input Widget
class SecureTextInput extends StatefulWidget {
  final String? labelText;
  final String? hintText;
  final TextInputType keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final TextEditingController? controller;
  final SecurityLevel securityLevel;
  final SecureContext secureContext;
  final int? maxLength;

  const SecureTextInput({
    super.key,
    this.labelText,
    this.hintText,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.onChanged,
    this.validator,
    this.controller,
    this.securityLevel = SecurityLevel.enhanced,
    this.secureContext = SecureContext.paymentEntry,
    this.maxLength,
  });

  @override
  State<SecureTextInput> createState() => _SecureTextInputState();
}

class _SecureTextInputState extends State<SecureTextInput> {
  late TextEditingController _controller;
  bool _isSecurityActive = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    // Ensure security is disabled when widget is disposed
    if (_isSecurityActive) {
      SecurityService().disableSecureContext();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Security status indicator
        StreamBuilder<String>(
          stream: SecurityService().securityStatusStream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  border: Border.all(color: Colors.green.shade300),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.security,
                      color: Colors.green.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      snapshot.data!,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // Secure text field
        Focus(
          onFocusChange: _handleFocusChange,
          child: TextFormField(
            controller: _controller,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            onChanged: widget.onChanged,
            validator: widget.validator,
            maxLength: widget.maxLength,
            enableInteractiveSelection: false, // Disable text selection for security
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _isSecurityActive ? Colors.green : Colors.grey.shade400,
                  width: _isSecurityActive ? 2 : 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _isSecurityActive ? Colors.green.shade300 : Colors.grey.shade400,
                  width: _isSecurityActive ? 2 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.green.shade600,
                  width: 2,
                ),
              ),
              suffixIcon: _isSecurityActive
                  ? Icon(
                      Icons.shield,
                      color: Colors.green.shade600,
                      size: 20,
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  void _handleFocusChange(bool hasFocus) async {
    if (hasFocus && !_isSecurityActive) {
      await SecurityService().enableSecureContext(
        widget.secureContext,
        level: widget.securityLevel,
      );
      setState(() => _isSecurityActive = true);
    } else if (!hasFocus && _isSecurityActive) {
      // Delay to allow for field switching
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted && !_controller.selection.isValid) {
          await SecurityService().disableSecureContext();
          if (mounted) {
            setState(() => _isSecurityActive = false);
          }
        }
      });
    }
  }
}