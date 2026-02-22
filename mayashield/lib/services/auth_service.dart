import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;
  bool get isSignedIn => _auth.currentUser != null;

  Future<User?> signInAnonymously() async {
    if (isSignedIn) return currentUser;
    final credential = await _auth.signInAnonymously();
    return credential.user;
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
