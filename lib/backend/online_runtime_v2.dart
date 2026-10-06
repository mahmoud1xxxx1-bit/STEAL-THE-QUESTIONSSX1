import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_bootstrap.dart';

/// Initializes Firebase and guarantees an authenticated Firebase session for V2.
///
/// Existing signed-in users are preserved. If there is no user yet, an
/// anonymous account is created so server-authoritative bot/PvP/profile calls
/// work immediately and can later be linked to a permanent identity.
class OnlineRuntimeV2 {
  OnlineRuntimeV2._();

  static Future<bool> ensureReady() async {
    final initialized = await FirebaseBootstrap.initialize();
    if (!initialized) return false;

    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        try {
          await auth.signInAnonymously();
        } catch (_) {
          // Firebase itself is initialized; the UI can still load from the
          // local V2 cache while authentication is unavailable/misconfigured.
        }
      }
      return true;
    } catch (_) {
      return true;
    }
  }
}
