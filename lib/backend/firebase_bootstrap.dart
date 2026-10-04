import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool initialized = false;

  static Future<bool> initialize() async {
    if (initialized || Firebase.apps.isNotEmpty) {
      initialized = true;
      return true;
    }

    try {
      if (kIsWeb) {
        const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
        const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
        const messagingSenderId = String.fromEnvironment('FIREBASE_WEB_MESSAGING_SENDER_ID');
        const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
        const authDomain = String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
        const storageBucket = String.fromEnvironment('FIREBASE_WEB_STORAGE_BUCKET');

        if (apiKey.isEmpty ||
            appId.isEmpty ||
            messagingSenderId.isEmpty ||
            projectId.isEmpty ||
            authDomain.isEmpty) {
          return false;
        }

        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: apiKey,
            appId: appId,
            messagingSenderId: messagingSenderId,
            projectId: projectId,
            authDomain: authDomain,
            storageBucket: storageBucket.isEmpty ? null : storageBucket,
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
      initialized = true;
      return true;
    } catch (_) {
      return false;
    }
  }
}
