import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_bootstrap.dart';

/// Initializes Firebase for the V2 runtime.
///
/// Authentication itself is handled explicitly by GoogleAuthV2 on Android.
class OnlineRuntimeV2 {
  OnlineRuntimeV2._();

  static Future<bool> ensureReady() async {
    final initialized = await FirebaseBootstrap.initialize();
    if (!initialized) return false;

    try {
      FirebaseAuth.instance;
      return true;
    } catch (_) {
      return false;
    }
  }
}
