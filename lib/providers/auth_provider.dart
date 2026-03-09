import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_models.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isAuthReady = false;

  User? get user => _user;
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isAuthReady => _isAuthReady;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    AuthService.authStateChanges.listen((User? user) async {
      _user = user;
      if (user != null) {
        _profile = await AuthService.getCurrentUserProfile();
      } else {
        _profile = null;
      }
      _isAuthReady = true;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<bool> signInWithEmailPassword(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final credential = await AuthService.signInWithEmailPassword(email, password);
      return credential != null;
    } catch (e) {
      debugPrint('Sign in error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<String> getTestUserEmails() {
    return AuthService.getTestUserEmails();
  }

  Map<String, String>? getTestUserData(String email) {
    return AuthService.getTestUserData(email);
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await AuthService.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}