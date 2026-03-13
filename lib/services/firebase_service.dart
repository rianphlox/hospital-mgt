import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/firebase_config.dart';
import 'dart:io' show Platform;

enum OperationType {
  create,
  update,
  delete,
  list,
  get,
  write,
}

class FirebaseService {
  static FirebaseApp? _app;
  static FirebaseAuth? _auth;
  static FirebaseFirestore? _firestore;

  static FirebaseAuth get auth => _auth!;
  static FirebaseFirestore get firestore => _firestore!;

  static Future<void> initialize() async {
    const firebaseOptions = FirebaseOptions(
      apiKey: FirebaseConfig.apiKey,
      appId: FirebaseConfig.appId,
      messagingSenderId: FirebaseConfig.messagingSenderId,
      projectId: FirebaseConfig.projectId,
      authDomain: FirebaseConfig.authDomain,
      storageBucket: FirebaseConfig.storageBucket,
    );

    _app = await Firebase.initializeApp(
      options: firebaseOptions,
    );

    _auth = FirebaseAuth.instanceFor(app: _app!);
    _firestore = FirebaseFirestore.instanceFor(app: _app!);

    // Disable reCAPTCHA for testing (Android emulator only)
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _auth!.setSettings(
          appVerificationDisabledForTesting: true,
        );
        debugPrint('✅ Firebase Auth: reCAPTCHA disabled for testing');
      } catch (e) {
        debugPrint('⚠️ Firebase Auth settings error: $e');
      }
    }

    // Enable offline persistence
    try {
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
      );
      debugPrint('✅ Firestore: Offline persistence enabled');
    } catch (e) {
      debugPrint('⚠️ Firestore persistence error: $e');
    }
  }

  static void handleFirestoreError(
    dynamic error,
    OperationType operationType,
    String? path,
  ) {
    final User? currentUser = _auth?.currentUser;
    final errorInfo = {
      'error': error.toString(),
      'operationType': operationType.name,
      'path': path,
      'authInfo': {
        'userId': currentUser?.uid,
        'email': currentUser?.email,
        'emailVerified': currentUser?.emailVerified,
        'isAnonymous': currentUser?.isAnonymous,
        'tenantId': currentUser?.tenantId,
        'providerInfo': currentUser?.providerData
                .map((provider) => {
                      'providerId': provider.providerId,
                      'displayName': provider.displayName,
                      'email': provider.email,
                      'photoUrl': provider.photoURL,
                    })
                .toList() ??
            [],
      },
    };

    debugPrint('Firestore Error: ${errorInfo.toString()}');
    throw Exception(errorInfo.toString());
  }
}