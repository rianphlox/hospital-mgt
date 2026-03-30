import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_models.dart';
import '../models/user_models.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  final StreamController<List<HospitalNotification>> _notificationsController =
      StreamController<List<HospitalNotification>>.broadcast();

  String? _currentUserId;
  UserRole? _currentUserRole;

  // Public streams
  Stream<List<HospitalNotification>> get notificationsStream => _notificationsController.stream;

  Future<void> initialize({
    required String userId,
    required UserRole userRole,
  }) async {
    _currentUserId = userId;
    _currentUserRole = userRole;

    await _initializeFirebaseMessaging();
    await _initializeLocalNotifications();
    await _setupNotificationListeners();

    if (kDebugMode) {
      print('NotificationService initialized for user: $userId, role: $userRole');
    }
  }

  Future<void> _initializeFirebaseMessaging() async {
    // Request permission for notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('Firebase Messaging permission granted');
      }

      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      if (token != null && _currentUserId != null) {
        await _saveFCMToken(token);
      }

      // Handle token refresh
      _firebaseMessaging.onTokenRefresh.listen(_saveFCMToken);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background message taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);

      // Subscribe to role-based topics
      if (_currentUserRole != null) {
        await _firebaseMessaging.subscribeToTopic(_currentUserRole!.name);
        await _firebaseMessaging.subscribeToTopic('all_users');
      }
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
  }

  Future<void> _setupNotificationListeners() async {
    if (_currentUserId == null || _currentUserRole == null) return;

    // Listen for notifications targeted to this user or role
    Query query = _firestore
        .collection('notifications')
        .where('targetRoles', arrayContains: _currentUserRole!.name)
        .orderBy('timestamp', descending: true)
        .limit(50);

    _notificationSubscription = query.snapshots().listen(
      (snapshot) {
        final notifications = snapshot.docs
            .map((doc) => HospitalNotification.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ))
            .toList();

        _notificationsController.add(notifications);
      },
      onError: (error) {
        if (kDebugMode) {
          print('Error listening to notifications: $error');
        }
      },
    );
  }

  Future<void> _saveFCMToken(String token) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('users').doc(_currentUserId).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) {
        print('FCM token saved: $token');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving FCM token: $e');
      }
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Received foreground message: ${message.notification?.title}');
    }

    // Show local notification for foreground messages
    _showLocalNotification(
      title: message.notification?.title ?? 'CrownLog',
      body: message.notification?.body ?? 'New notification',
      payload: message.data['actionUrl'],
    );
  }

  void _handleBackgroundMessageTap(RemoteMessage message) {
    if (kDebugMode) {
      print('Background message tapped: ${message.data}');
    }

    // Handle navigation from background message tap
    final actionUrl = message.data['actionUrl'];
    if (actionUrl != null) {
      // TODO: Implement navigation logic
    }
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    if (kDebugMode) {
      print('Local notification tapped: ${response.payload}');
    }

    // Handle navigation from local notification tap
    if (response.payload != null) {
      // TODO: Implement navigation logic
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    NotificationPriority priority = NotificationPriority.normal,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'crownlog_channel',
      'CrownLog Notifications',
      channelDescription: 'Hospital management notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  // Public methods for creating notifications

  Future<void> createNotification(HospitalNotification notification) async {
    try {
      final notificationData = notification.toJson();
      final docRef = await _firestore.collection('notifications').add(notificationData);

      if (kDebugMode) {
        print('Notification created: ${docRef.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating notification: $e');
      }
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error marking notification as read: $e');
      }
    }
  }

  Future<void> markAllAsRead() async {
    if (_currentUserRole == null) return;

    try {
      final batch = _firestore.batch();
      final query = await _firestore
          .collection('notifications')
          .where('targetRoles', arrayContains: _currentUserRole!.name)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in query.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        print('Error marking all notifications as read: $e');
      }
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting notification: $e');
      }
    }
  }

  Future<int> getUnreadCount() async {
    if (_currentUserRole == null) return 0;

    try {
      final query = await _firestore
          .collection('notifications')
          .where('targetRoles', arrayContains: _currentUserRole!.name)
          .where('isRead', isEqualTo: false)
          .count()
          .get();

      return query.count ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting unread count: $e');
      }
      return 0;
    }
  }

  // Convenient methods for common notification types

  Future<void> notifyTreatmentLogged({
    required String patientName,
    required String nurseName,
    required String patientId,
    required String treatmentId,
    required int itemCount,
  }) async {
    final notification = NotificationFactory.treatmentLogged(
      patientName: patientName,
      nurseName: nurseName,
      patientId: patientId,
      treatmentId: treatmentId,
      itemCount: itemCount,
    );

    await createNotification(notification);
  }

  Future<void> notifyTreatmentPriced({
    required String patientName,
    required String adminName,
    required String patientId,
    required String treatmentId,
    required int totalAmount,
  }) async {
    final notification = NotificationFactory.treatmentPriced(
      patientName: patientName,
      adminName: adminName,
      patientId: patientId,
      treatmentId: treatmentId,
      totalAmount: totalAmount,
    );

    await createNotification(notification);
  }

  Future<void> notifyPaymentReceived({
    required String patientName,
    required String cashierName,
    required String patientId,
    required String paymentId,
    required int amount,
    required String paymentMethod,
  }) async {
    final notification = NotificationFactory.paymentReceived(
      patientName: patientName,
      cashierName: cashierName,
      patientId: patientId,
      paymentId: paymentId,
      amount: amount,
      paymentMethod: paymentMethod,
    );

    await createNotification(notification);
  }

  Future<void> notifyPatientAdmitted({
    required String patientName,
    required String admissionNumber,
    required String ward,
    required String patientId,
    required String admittedBy,
  }) async {
    final notification = NotificationFactory.patientAdmitted(
      patientName: patientName,
      admissionNumber: admissionNumber,
      ward: ward,
      patientId: patientId,
      admittedBy: admittedBy,
    );

    await createNotification(notification);
  }

  Future<void> notifyEmergency({
    required String title,
    required String message,
    String? patientId,
    String? patientName,
  }) async {
    final notification = NotificationFactory.emergencyAlert(
      title: title,
      message: message,
      patientId: patientId,
      patientName: patientName,
    );

    await createNotification(notification);

    // Also show immediate local notification for emergencies
    await _showLocalNotification(
      title: title,
      body: message,
      priority: NotificationPriority.urgent,
    );
  }

  void dispose() {
    _notificationSubscription?.cancel();
    _notificationsController.close();
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already done
  // await Firebase.initializeApp();

  if (kDebugMode) {
    print('Background message received: ${message.notification?.title}');
  }

  // Handle background message logic here if needed
}