import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthV2 {
  GoogleAuthV2._();

  static final GoogleAuthV2 instance = GoogleAuthV2._();

  final GoogleSignIn _google = GoogleSignIn.instance;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _google.initialize();
    _initialized = true;
  }

  User? get currentUser => FirebaseAuth.instance.currentUser;

  Future<UserCredential> signIn() async {
    await initialize();
    final account = await _google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('GOOGLE_ID_TOKEN_MISSING');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await initialize();
    await _google.signOut();
    await FirebaseAuth.instance.signOut();
  }
}
