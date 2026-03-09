enum UserRole { nurse, cashier, admin }

enum NursingShift {
  morning,   // 6 AM - 2 PM
  afternoon, // 2 PM - 10 PM
  night      // 10 PM - 6 AM
}

extension NursingShiftExtension on NursingShift {
  String get displayName {
    switch (this) {
      case NursingShift.morning:
        return 'Morning (6 AM - 2 PM)';
      case NursingShift.afternoon:
        return 'Afternoon (2 PM - 10 PM)';
      case NursingShift.night:
        return 'Night (10 PM - 6 AM)';
    }
  }

  String get shortName {
    switch (this) {
      case NursingShift.morning:
        return 'Morning';
      case NursingShift.afternoon:
        return 'Afternoon';
      case NursingShift.night:
        return 'Night';
    }
  }

  static NursingShift getCurrentShift() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour >= 6 && hour < 14) {
      return NursingShift.morning;
    } else if (hour >= 14 && hour < 22) {
      return NursingShift.afternoon;
    } else {
      return NursingShift.night;
    }
  }
}

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String? ward;
  final NursingShift? shift;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.ward,
    this.shift,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => UserRole.nurse,
      ),
      ward: json['ward'] as String?,
      shift: json['shift'] != null
          ? NursingShift.values.firstWhere(
              (s) => s.name == json['shift'],
              orElse: () => NursingShift.morning,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role.name,
      'ward': ward,
      'shift': shift?.name,
    };
  }

  UserProfile copyWith({
    String? uid,
    String? name,
    String? email,
    UserRole? role,
    String? ward,
    NursingShift? shift,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      ward: ward ?? this.ward,
      shift: shift ?? this.shift,
    );
  }
}