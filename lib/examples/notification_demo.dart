import 'package:flutter/material.dart';
import '../widgets/notification_center.dart';
import '../services/notification_service.dart';
import '../models/user_models.dart';

/// Example screen showing how to integrate notifications
class NotificationDemoScreen extends StatefulWidget {
  const NotificationDemoScreen({super.key});

  @override
  State<NotificationDemoScreen> createState() => _NotificationDemoScreenState();
}

class _NotificationDemoScreenState extends State<NotificationDemoScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize notification service for current user
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    // Initialize with user ID and role (you'd get these from your auth provider)
    await NotificationService().initialize(
      userId: 'demo_user_123',
      userRole: UserRole.nurse,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Dashboard'),
        actions: [
          // Add the notification bell to any app bar
          const NotificationBell(),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Demo buttons to trigger notifications
            const Text(
              'Notification Demo',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: _sendTestTreatmentNotification,
              icon: const Icon(Icons.medical_services),
              label: const Text('Send Treatment Notification'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 48),
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _sendTestPaymentNotification,
              icon: const Icon(Icons.payment),
              label: const Text('Send Payment Notification'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 48),
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _sendEmergencyNotification,
              icon: const Icon(Icons.emergency),
              label: const Text('Send Emergency Alert'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 48),
              ),
            ),
            const SizedBox(height: 32),

            // Compact notification bell for smaller spaces
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('Compact notification bell: '),
                    const SizedBox(width: 16),
                    const CompactNotificationBell(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendTestTreatmentNotification() async {
    await NotificationService().notifyTreatmentLogged(
      patientName: 'John Doe',
      nurseName: 'Nurse Jane',
      patientId: 'patient_123',
      treatmentId: 'treatment_456',
      itemCount: 3,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treatment notification sent!')),
      );
    }
  }

  Future<void> _sendTestPaymentNotification() async {
    await NotificationService().notifyPaymentReceived(
      patientName: 'John Doe',
      cashierName: 'Cashier Bob',
      patientId: 'patient_123',
      paymentId: 'payment_789',
      amount: 15000,
      paymentMethod: 'Cash',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment notification sent!')),
      );
    }
  }

  Future<void> _sendEmergencyNotification() async {
    await NotificationService().notifyEmergency(
      title: 'Emergency Alert',
      message: 'Patient John Doe requires immediate attention in Ward A',
      patientId: 'patient_123',
      patientName: 'John Doe',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency notification sent!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Usage Guide:
///
/// 1. Add to your app bar:
/// ```dart
/// AppBar(
///   title: Text('My Screen'),
///   actions: [
///     NotificationBell(),
///   ],
/// )
/// ```
///
/// 2. Initialize in your main app:
/// ```dart
/// void initState() {
///   super.initState();
///   NotificationService().initialize(
///     userId: authProvider.user.uid,
///     userRole: authProvider.user.role,
///   );
/// }
/// ```
///
/// 3. Trigger notifications anywhere in your app:
/// ```dart
/// NotificationService().notifyTreatmentLogged(...);
/// NotificationService().notifyPaymentReceived(...);
/// NotificationService().notifyEmergency(...);
/// ```