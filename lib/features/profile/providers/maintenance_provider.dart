import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../models/maintenance_entry.dart';

final _firestore = FirebaseFirestore.instance;

class MaintenanceNotifier extends StateNotifier<AsyncValue<List<MaintenanceEntry>>> {
  StreamSubscription<QuerySnapshot>? _sub;
  String? _uid;

  MaintenanceNotifier() : super(const AsyncValue.loading());

  void resubscribe(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    _sub?.cancel();
    if (uid == null) {
      state = const AsyncValue.data([]);
      return;
    }
    _sub = _firestore
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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> addEntry(MaintenanceEntry entry) async {
    if (_uid == null) return;
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('maintenance')
        .add(entry.toMap());
  }

  Future<void> updateEntry(MaintenanceEntry entry) async {
    if (_uid == null) return;
    final update = entry.toMap()..remove('createdAt');
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('maintenance')
        .doc(entry.entryId)
        .update(update);
  }

  Future<void> deleteEntry(String entryId) async {
    if (_uid == null) return;
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('maintenance')
        .doc(entryId)
        .delete();
  }
}

final maintenanceProvider = StateNotifierProvider<MaintenanceNotifier,
    AsyncValue<List<MaintenanceEntry>>>((ref) {
  final notifier = MaintenanceNotifier();
  // Drive the subscription from authStateProvider so it rebuilds on user change.
  ref.listen<AsyncValue<User?>>(
    authStateProvider,
    (_, next) => notifier.resubscribe(next.value?.uid),
    fireImmediately: true,
  );
  return notifier;
});