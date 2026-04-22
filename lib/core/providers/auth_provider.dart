import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared auth state provider. All per-user providers must ref.watch this
/// instead of reading FirebaseAuth.instance.currentUser synchronously, so
/// they rebuild automatically when a new user signs in.
final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);