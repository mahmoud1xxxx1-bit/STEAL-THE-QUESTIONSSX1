import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool initialized = false;
  static const String defaultProjectId = 'steal-the-questionssx1';
  static List<String> missingWebConfig = const <String>[];

  static Future<bool> initialize() async {
    if (initialized || Firebase.apps.isNotEmpty) {
      initialized = true;
      missingWebConfig = const <String>[];
      return true;
    }

    try {
      if (kIsWeb) {
        const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
        const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
        const messagingSenderId =
            String.fromEnvironment('FIREBASE_WEB_MESSAGING_SENDER_ID');
        const configuredProjectId =
            String.fromEnvironment('FIREBASE_PROJECT_ID');
        const configuredAuthDomain =
            String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
        const configuredStorageBucket =
            String.fromEnvironment('FIREBASE_WEB_STORAGE_BUCKET');

        final projectId = configuredProjectId.isEmpty
            ? defaultProjectId
            : configuredProjectId;
        final authDomain = configuredAuthDomain.isEmpty
            ? '$projectId.firebaseapp.com'
            : configuredAuthDomain;
        final storageBucket = configuredStorageBucket.isEmpty
            ? '$projectId.appspot.com'
            : configuredStorageBucket;

        final missing = <String>[
          if (apiKey.isEmpty) 'FIREBASE_WEB_API_KEY',
          if (appId.isEmpty) 'FIREBASE_WEB_APP_ID',
          if (messagingSenderId.isEmpty)
            'FIREBASE_WEB_MESSAGING_SENDER_ID',
        ];
        missingWebConfig = List<String>.unmodifiable(missing);
        if (missing.isNotEmpty) return false;

        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: apiKey,
            appId: appId,
            messagingSenderId: messagingSenderId,
            projectId: projectId,
            authDomain: authDomain,
            storageBucket: storageBucket,
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
      initialized = true;
      missingWebConfig = const <String>[];
      return true;
    } catch (_) {
      return false;
    }
  }
}
