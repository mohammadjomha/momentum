import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String username,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;
    final trimmed = username.trim();
    final lower = trimmed.toLowerCase();

    final usernameRef = _firestore.collection('usernames').doc(lower);
    final userRef = _firestore.collection('users').doc(uid);

    try {
      await _firestore.runTransaction((tx) async {
        final usernameSnap = await tx.get(usernameRef);
        if (usernameSnap.exists) {
          throw Exception('Username already taken.');
        }
        tx.set(userRef, {
          'username': trimmed,
          'usernameLower': lower,
          'email': email.trim(),
          'totalDistance': 0.0,
          'totalTrips': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(usernameRef, {'uid': uid});
      });
    } catch (e) {
      // Roll back the Auth account so the user can retry cleanly.
      await credential.user!.delete();
      rethrow;
    }

    return credential;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
