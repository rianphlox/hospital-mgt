import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_models.dart';

enum NotificationType {
  treatmentLogged,      // New treatment logged by nurse
  treatmentPriced,      // Treatment priced by admin
  paymentReceived,      // Payment recorded by cashier
  patientAdmitted,      // New patient admission
  patientDischarged,    // Patient discharged
  shiftHandover,        // Shift change notification
  systemAlert,          // System-wide alerts
  emergencyAlert,       // Emergency/urgent notifications
  reminderAlert,        // Task reminders
}

enum NotificationPriority {
  low,     // General info
  normal,  // Standard workflow
  high,    // Important updates
  urgent,  // Emergency situations
}

extension NotificationTypeExtension on NotificationType {
  String get displayName {
    switch (this) {
      case NotificationType.treatmentLogged:
        return 'Treatment Logged';
      case NotificationType.treatmentPriced:
        return 'Treatment Priced';
      case NotificationType.paymentReceived:
        return 'Payment Received';
      case NotificationType.patientAdmitted:
        return 'Patient Admitted';
      case NotificationType.patientDischarged:
        return 'Patient Discharged';
      case NotificationType.shiftHandover:
        return 'Shift Handover';
      case NotificationType.systemAlert:
        return 'System Alert';
      case NotificationType.emergencyAlert:
        return 'Emergency Alert';
      case NotificationType.reminderAlert:
        return 'Reminder';
    }
  }

  String get icon {
    switch (this) {
      case NotificationType.treatmentLogged:
        return '💊';
      case NotificationType.treatmentPriced:
        return '💰';
      case NotificationType.paymentReceived:
        return '💵';
      case NotificationType.patientAdmitted:
        return '🏥';
      case NotificationType.patientDischarged:
        return '🚪';
      case NotificationType.shiftHandover:
        return '🔄';
      case NotificationType.systemAlert:
        return '⚠️';
      case NotificationType.emergencyAlert:
        return '🚨';
      case NotificationType.reminderAlert:
        return '⏰';
    }
  }

  NotificationPriority get defaultPriority {
    switch (this) {
      case NotificationType.emergencyAlert:
        return NotificationPriority.urgent;
      case NotificationType.treatmentLogged:
      case NotificationType.paymentReceived:
      case NotificationType.patientAdmitted:
      case NotificationType.patientDischarged:
        return NotificationPriority.high;
      case NotificationType.treatmentPriced:
      case NotificationType.shiftHandover:
        return NotificationPriority.normal;
      case NotificationType.systemAlert:
      case NotificationType.reminderAlert:
        return NotificationPriority.low;
    }
  }
}

extension NotificationPriorityExtension on NotificationPriority {
  String get displayName {
    switch (this) {
      case NotificationPriority.low:
        return 'Low';
      case NotificationPriority.normal:
        return 'Normal';
      case NotificationPriority.high:
        return 'High';
      case NotificationPriority.urgent:
        return 'Urgent';
    }
  }
}

class HospitalNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final NotificationPriority priority;
  final DateTime timestamp;
  final String? patientId;
  final String? patientName;
  final String? treatmentId;
  final String? paymentId;
  final String? recipientUserId;  // Specific user or null for broadcast
  final List<UserRole> targetRoles; // Target user roles
  final Map<String, dynamic>? data; // Additional data
  final bool isRead;
  final DateTime? readAt;
  final String? actionUrl; // Deep link for navigation

  HospitalNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.priority,
    required this.timestamp,
    this.patientId,
    this.patientName,
    this.treatmentId,
    this.paymentId,
    this.recipientUserId,
    this.targetRoles = const [],
    this.data,
    this.isRead = false,
    this.readAt,
    this.actionUrl,
  });

  factory HospitalNotification.fromJson(Map<String, dynamic> json, String id) {
    return HospitalNotification(
      id: id,
      title: json['title'] as String,
      body: json['body'] as String,
      type: NotificationType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => NotificationType.systemAlert,
      ),
      priority: NotificationPriority.values.firstWhere(
        (priority) => priority.name == json['priority'],
        orElse: () => NotificationPriority.normal,
      ),
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      patientId: json['patientId'] as String?,
      patientName: json['patientName'] as String?,
      treatmentId: json['treatmentId'] as String?,
      paymentId: json['paymentId'] as String?,
      recipientUserId: json['recipientUserId'] as String?,
      targetRoles: (json['targetRoles'] as List<dynamic>?)
          ?.map((role) => UserRole.values.firstWhere(
                (r) => r.name == role,
                orElse: () => UserRole.nurse,
              ))
          .toList() ?? [],
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['isRead'] as bool? ?? false,
      readAt: json['readAt'] != null
          ? (json['readAt'] as Timestamp).toDate()
          : null,
      actionUrl: json['actionUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'type': type.name,
      'priority': priority.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'patientId': patientId,
      'patientName': patientName,
      'treatmentId': treatmentId,
      'paymentId': paymentId,
      'recipientUserId': recipientUserId,
      'targetRoles': targetRoles.map((role) => role.name).toList(),
      'data': data,
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'actionUrl': actionUrl,
    };
  }

  HospitalNotification copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return HospitalNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      priority: priority,
      timestamp: timestamp,
      patientId: patientId,
      patientName: patientName,
      treatmentId: treatmentId,
      paymentId: paymentId,
      recipientUserId: recipientUserId,
      targetRoles: targetRoles,
      data: data,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      actionUrl: actionUrl,
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${difference.inDays ~/ 7}w ago';
    }
  }
}

// Factory methods for creating common notifications
class NotificationFactory {
  static HospitalNotification treatmentLogged({
    required String patientName,
    required String nurseName,
    required String patientId,
    required String treatmentId,
    required int itemCount,
  }) {
    return HospitalNotification(
      id: '',
      title: 'New Treatment Logged',
      body: '$nurseName logged $itemCount treatment(s) for $patientName',
      type: NotificationType.treatmentLogged,
      priority: NotificationType.treatmentLogged.defaultPriority,
      timestamp: DateTime.now(),
      patientId: patientId,
      patientName: patientName,
      treatmentId: treatmentId,
      targetRoles: [UserRole.admin],
      actionUrl: '/patient/$patientId/treatments',
      data: {
        'nurseName': nurseName,
        'itemCount': itemCount,
      },
    );
  }

  static HospitalNotification treatmentPriced({
    required String patientName,
    required String adminName,
    required String patientId,
    required String treatmentId,
    required int totalAmount,
  }) {
    return HospitalNotification(
      id: '',
      title: 'Treatment Priced',
      body: '$adminName priced treatment for $patientName (₦$totalAmount)',
      type: NotificationType.treatmentPriced,
      priority: NotificationType.treatmentPriced.defaultPriority,
      timestamp: DateTime.now(),
      patientId: patientId,
      patientName: patientName,
      treatmentId: treatmentId,
      targetRoles: [UserRole.cashier],
      actionUrl: '/patient/$patientId/billing',
      data: {
        'adminName': adminName,
        'totalAmount': totalAmount,
      },
    );
  }

  static HospitalNotification paymentReceived({
    required String patientName,
    required String cashierName,
    required String patientId,
    required String paymentId,
    required int amount,
    required String paymentMethod,
  }) {
    return HospitalNotification(
      id: '',
      title: 'Payment Received',
      body: '$cashierName recorded ₦$amount payment from $patientName via $paymentMethod',
      type: NotificationType.paymentReceived,
      priority: NotificationType.paymentReceived.defaultPriority,
      timestamp: DateTime.now(),
      patientId: patientId,
      patientName: patientName,
      paymentId: paymentId,
      targetRoles: [UserRole.admin, UserRole.nurse],
      actionUrl: '/patient/$patientId/billing',
      data: {
        'cashierName': cashierName,
        'amount': amount,
        'paymentMethod': paymentMethod,
      },
    );
  }

  static HospitalNotification patientAdmitted({
    required String patientName,
    required String admissionNumber,
    required String ward,
    required String patientId,
    required String admittedBy,
  }) {
    return HospitalNotification(
      id: '',
      title: 'New Patient Admitted',
      body: '$patientName (#$admissionNumber) admitted to $ward by $admittedBy',
      type: NotificationType.patientAdmitted,
      priority: NotificationType.patientAdmitted.defaultPriority,
      timestamp: DateTime.now(),
      patientId: patientId,
      patientName: patientName,
      targetRoles: [UserRole.nurse, UserRole.admin],
      actionUrl: '/patient/$patientId',
      data: {
        'admissionNumber': admissionNumber,
        'ward': ward,
        'admittedBy': admittedBy,
      },
    );
  }

  static HospitalNotification emergencyAlert({
    required String title,
    required String message,
    String? patientId,
    String? patientName,
  }) {
    return HospitalNotification(
      id: '',
      title: title,
      body: message,
      type: NotificationType.emergencyAlert,
      priority: NotificationPriority.urgent,
      timestamp: DateTime.now(),
      patientId: patientId,
      patientName: patientName,
      targetRoles: UserRole.values, // Broadcast to all roles
    );
  }
}