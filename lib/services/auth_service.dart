import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_models.dart';
import '../services/firebase_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseService.auth;
  static final FirebaseFirestore _firestore = FirebaseService.firestore;

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Predefined test users
  static const Map<String, Map<String, String>> testUsers = {
    'admin@test.com': {
      'password': 'test123',
      'uid': 'X7xcQuadvcbkiobht5XNzgMdsdB3',
      'name': 'Admin User',
      'role': 'admin',
    },
    'cashier@test.com': {
      'password': 'test123',
      'uid': 'bwbjAcqhSofmJ9r1GI53vDDiIRM2',
      'name': 'Cashier User',
      'role': 'cashier',
    },
    'nurse@test.com': {
      'password': 'test123',
      'uid': 'evE2YDH6LZdcfy3elMMQVzzjPxE2',
      'name': 'Nurse User',
      'role': 'nurse',
    },
  };

  static Future<UserCredential?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Create or update user profile if it doesn't exist
      await _createOrUpdateUserProfile(userCredential.user!);

      return userCredential;
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.create, 'auth');
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  static List<String> getTestUserEmails() {
    return testUsers.keys.toList();
  }

  static Map<String, String>? getTestUserData(String email) {
    return testUsers[email];
  }

  static Future<UserProfile?> getCurrentUserProfile() async {
    final User? user = currentUser;
    if (user == null) return null;

    try {
      final DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists) {
        return UserProfile.fromJson(doc.data() as Map<String, dynamic>);
      } else {
        // Create default profile for new users
        final profile = UserProfile(
          uid: user.uid,
          name: user.displayName ?? 'Staff Member',
          email: user.email ?? '',
          role: UserRole.nurse, // Default role
          ward: 'General Ward',
        );
        await _updateUserProfile(profile);
        return profile;
      }
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.get, 'users');
      return null;
    }
  }

  static Future<void> _createOrUpdateUserProfile(User user) async {
    try {
      final DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();
      
      final userData = testUsers[user.email];

      if (!doc.exists) {
        // Create profile with predefined data or defaults
        final profile = UserProfile(
          uid: user.uid,
          name: userData?['name'] ?? user.displayName ?? 'Staff Member',
          email: user.email ?? '',
          role: _parseRole(userData?['role'] ?? 'nurse'),
          ward: userData?['role'] == 'admin' ? 'Hospital' : 'General Ward',
        );

        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(profile.toJson());
      } else if (userData != null) {
        // If it's a test user, ensure the role is correct in Firestore
        final currentData = doc.data() as Map<String, dynamic>;
        final correctRole = userData['role']!;
        
        if (currentData['role'] != correctRole) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({'role': correctRole});
        }
      }
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.create, 'users');
    }
  }

  static UserRole _parseRole(String roleString) {
    switch (roleString.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'cashier':
        return UserRole.cashier;
      case 'nurse':
      default:
        return UserRole.nurse;
    }
  }

  static Future<void> _updateUserProfile(UserProfile profile) async {
    try {
      await _firestore
          .collection('users')
          .doc(profile.uid)
          .set(profile.toJson());
    } catch (e) {
      FirebaseService.handleFirestoreError(e, OperationType.update, 'users');
    }
  }
}