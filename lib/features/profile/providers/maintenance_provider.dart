import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/maintenance_entry.dart';

final _firestore = FirebaseFirestore.instance;
final _auth = FirebaseAuth.instance;

class MaintenanceNotifier extends StateNotifier<AsyncValue<List<MaintenanceEntry>>> {
  MaintenanceNotifier() : super(const AsyncValue.loading()) {
    _subscribe();
  }

  void _subscribe() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      state = const AsyncValue.data([]);
      return;
    }
    _firestore
        .collection('users')
        .doc(uid)
        .collection('maintenance')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snap) {
            final entries = snap.docs
                .map((doc) => MaintenanceEntry.fromDoc(doc))
                .toList();
            state = AsyncValue.data(entries);
          },
          onError: (e, st) => state = AsyncValue.error(e, st),
        );
  }

  Future<void> addEntry(MaintenanceEntry entry) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('maintenance')
        .add(entry.toMap());
  }

  Future<void> updateEntry(MaintenanceEntry entry) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final update = entry.toMap()..remove('createdAt');
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('maintenance')
        .doc(entry.entryId)
        .update(update);
  }

  Future<void> deleteEntry(String entryId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('maintenance')
        .doc(entryId)
        .delete();
  }
}

final maintenanceProvider = StateNotifierProvider<MaintenanceNotifier,
    AsyncValue<List<MaintenanceEntry>>>(
  (ref) => MaintenanceNotifier(),
);