import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/nhtsa_service.dart';

// ---------------------------------------------------------------------------
// User profile data (loaded from Firestore)
// ---------------------------------------------------------------------------

class UserProfile {
  final String username;
  final String email;
  final int totalTrips;
  final double totalDistance;
  final String? carMake;
  final String? carModel;
  final String? carYear;
  final String? carTrim;
  final String? carNotes;

  const UserProfile({
    required this.username,
    required this.email,
    required this.totalTrips,
    required this.totalDistance,
    this.carMake,
    this.carModel,
    this.carYear,
    this.carTrim,
    this.carNotes,
  });

  factory UserProfile.fromFirestore(Map<String, dynamic> data) {
    final car = data['car'] as Map<String, dynamic>?;
    return UserProfile(
      username: (data['username'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      totalTrips: (data['totalTrips'] as num?)?.toInt() ?? 0,
      totalDistance: (data['totalDistance'] as num?)?.toDouble() ?? 0.0,
      carMake: car?['make'] as String?,
      carModel: car?['model'] as String?,
      carYear: car?['year'] as String?,
      carTrim: car?['trim'] as String?,
      carNotes: car?['notes'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _firestore = FirebaseFirestore.instance;
final _auth = FirebaseAuth.instance;
final _nhtsaService = NhtsaService();

/// Streams the current user's Firestore document.
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = _auth.currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return _firestore.collection('users').doc(uid).snapshots().map((snap) {
    if (!snap.exists) return null;
    return UserProfile.fromFirestore(snap.data()!);
  });
});

// ---------------------------------------------------------------------------
// NHTSA makes
// ---------------------------------------------------------------------------

enum NhtsaLoadState { idle, loading, loaded, error }

class NhtsaMakesState {
  final NhtsaLoadState loadState;
  final List<String> items;
  final bool fallback; // true → show plain text field

  const NhtsaMakesState({
    this.loadState = NhtsaLoadState.idle,
    this.items = const [],
    this.fallback = false,
  });

  NhtsaMakesState copyWith({
    NhtsaLoadState? loadState,
    List<String>? items,
    bool? fallback,
  }) =>
      NhtsaMakesState(
        loadState: loadState ?? this.loadState,
        items: items ?? this.items,
        fallback: fallback ?? this.fallback,
      );
}

class NhtsaMakesNotifier extends StateNotifier<NhtsaMakesState> {
  NhtsaMakesNotifier() : super(const NhtsaMakesState());

  Future<void> load() async {
    state = state.copyWith(loadState: NhtsaLoadState.loading);
    try {
      final makes = await _nhtsaService.fetchMakes();
      state = state.copyWith(loadState: NhtsaLoadState.loaded, items: makes);
    } catch (_) {
      state = state.copyWith(loadState: NhtsaLoadState.error, fallback: true);
    }
  }
}

final nhtsaMakesProvider =
    StateNotifierProvider<NhtsaMakesNotifier, NhtsaMakesState>(
  (ref) => NhtsaMakesNotifier(),
);

// ---------------------------------------------------------------------------
// NHTSA models (keyed on selected make)
// ---------------------------------------------------------------------------

class NhtsaModelsState {
  final NhtsaLoadState loadState;
  final List<String> items;
  final bool fallback;
  final String? forMake; // which make these models belong to

  const NhtsaModelsState({
    this.loadState = NhtsaLoadState.idle,
    this.items = const [],
    this.fallback = false,
    this.forMake,
  });

  NhtsaModelsState copyWith({
    NhtsaLoadState? loadState,
    List<String>? items,
    bool? fallback,
    String? forMake,
  }) =>
      NhtsaModelsState(
        loadState: loadState ?? this.loadState,
        items: items ?? this.items,
        fallback: fallback ?? this.fallback,
        forMake: forMake ?? this.forMake,
      );
}

class NhtsaModelsNotifier extends StateNotifier<NhtsaModelsState> {
  NhtsaModelsNotifier() : super(const NhtsaModelsState());

  Future<void> loadForMake(String make) async {
    state = NhtsaModelsState(
      loadState: NhtsaLoadState.loading,
      forMake: make,
    );
    try {
      final models = await _nhtsaService.fetchModels(make);
      state = state.copyWith(loadState: NhtsaLoadState.loaded, items: models);
    } catch (_) {
      state = state.copyWith(loadState: NhtsaLoadState.error, fallback: true);
    }
  }

  void reset() {
    state = const NhtsaModelsState();
  }
}

final nhtsaModelsProvider =
    StateNotifierProvider<NhtsaModelsNotifier, NhtsaModelsState>(
  (ref) => NhtsaModelsNotifier(),
);

// ---------------------------------------------------------------------------
// Profile save
// ---------------------------------------------------------------------------

Future<void> saveProfile({
  required String username,
  required String? make,
  required String? model,
  required String? year,
  required String? trim,
  required String? notes,
}) async {
  final uid = _auth.currentUser?.uid;
  if (uid == null) throw Exception('Not signed in');

  final Map<String, dynamic> update = {
    'username': username.trim(),
  };

  final Map<String, dynamic> car = {};
  if (make != null && make.isNotEmpty) car['make'] = make.trim();
  if (model != null && model.isNotEmpty) car['model'] = model.trim();
  if (year != null && year.isNotEmpty) car['year'] = year.trim();
  if (trim != null && trim.isNotEmpty) car['trim'] = trim.trim();
  if (notes != null && notes.isNotEmpty) car['notes'] = notes.trim();

  if (car.isNotEmpty) update['car'] = car;

  await _firestore.collection('users').doc(uid).update(update);
}
