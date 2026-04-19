import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/trip_history/models/trip_model.dart';

enum LeaderboardFilter { today, thisWeek, thisMonth, allTime }

class LeaderboardEntry {
  final int rank;
  final String uid;
  final String username;
  final String? carModel;
  final double smoothnessScore;
  final double maxSpeed;
  final double distance;

  const LeaderboardEntry({
    required this.rank,
    required this.uid,
    required this.username,
    this.carModel,
    required this.smoothnessScore,
    required this.maxSpeed,
    required this.distance,
  });
}

class LeaderboardState {
  final List<LeaderboardEntry> entries;
  final LeaderboardFilter filter;
  final bool isLoading;
  final String? error;

  const LeaderboardState({
    this.entries = const [],
    this.filter = LeaderboardFilter.thisWeek,
    this.isLoading = false,
    this.error,
  });

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    LeaderboardFilter? filter,
    bool? isLoading,
    String? error,
  }) =>
      LeaderboardState(
        entries: entries ?? this.entries,
        filter: filter ?? this.filter,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  LeaderboardNotifier() : super(const LeaderboardState()) {
    _load();
  }

  Future<void> setFilter(LeaderboardFilter filter) async {
    state = state.copyWith(filter: filter, isLoading: true, error: null);
    await _load();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final db = FirebaseFirestore.instance;
      Query<Map<String, dynamic>> query = db.collection('trips');

      final now = DateTime.now();
      final dateFilter = _startDate(state.filter, now);
      if (dateFilter != null) {
        query = query.where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dateFilter),
        );
      }

      query = query
          .orderBy('date', descending: false)
          .orderBy('smoothnessScore', descending: true)
          .orderBy('distance', descending: true)
          .orderBy('avgSpeed', descending: true);

      final snapshot = await query.get();
      final trips = snapshot.docs.map(TripModel.fromDoc).toList();

      // Group by uid, keep best trip per user
      final Map<String, TripModel> bestByUid = {};
      for (final trip in trips) {
        final existing = bestByUid[trip.uid];
        if (existing == null || _isBetter(trip, existing)) {
          bestByUid[trip.uid] = trip;
        }
      }

      // Sort the winners
      final sorted = bestByUid.values.toList()
        ..sort((a, b) {
          final cmp = b.smoothnessScore.compareTo(a.smoothnessScore);
          if (cmp != 0) return cmp;
          final cmp2 = b.distance.compareTo(a.distance);
          if (cmp2 != 0) return cmp2;
          return b.avgSpeed.compareTo(a.avgSpeed);
        });

      // Fetch car info for each uid
      final uids = sorted.map((t) => t.uid).toList();
      final carByUid = await _fetchCarModels(uids);

      final entries = sorted.asMap().entries.map((e) {
        final trip = e.value;
        return LeaderboardEntry(
          rank: e.key + 1,
          uid: trip.uid,
          username: trip.username,
          carModel: carByUid[trip.uid],
          smoothnessScore: trip.smoothnessScore,
          maxSpeed: trip.maxSpeed,
          distance: trip.distance,
        );
      }).toList();

      state = state.copyWith(entries: entries, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  bool _isBetter(TripModel a, TripModel b) {
    final cmp = a.smoothnessScore.compareTo(b.smoothnessScore);
    if (cmp != 0) return cmp > 0;
    final cmp2 = a.distance.compareTo(b.distance);
    if (cmp2 != 0) return cmp2 > 0;
    return a.avgSpeed > b.avgSpeed;
  }

  Future<Map<String, String?>> _fetchCarModels(List<String> uids) async {
    if (uids.isEmpty) return {};
    final db = FirebaseFirestore.instance;
    final result = <String, String?>{};
    // Fetch in batches of 10 (Firestore whereIn limit)
    for (var i = 0; i < uids.length; i += 10) {
      final batch = uids.sublist(i, i + 10 > uids.length ? uids.length : i + 10);
      final docs = await db
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in docs.docs) {
        final car = doc.data()['car'] as Map<String, dynamic>?;
        if (car != null) {
          final make = car['make'] as String?;
          final model = car['model'] as String?;
          if (make != null && model != null) {
            result[doc.id] = '$make $model';
          } else {
            result[doc.id] = null;
          }
        } else {
          result[doc.id] = null;
        }
      }
    }
    return result;
  }

  DateTime? _startDate(LeaderboardFilter filter, DateTime now) {
    switch (filter) {
      case LeaderboardFilter.today:
        return DateTime(now.year, now.month, now.day);
      case LeaderboardFilter.thisWeek:
        final weekday = now.weekday; // Mon=1 … Sun=7
        return DateTime(now.year, now.month, now.day - (weekday - 1));
      case LeaderboardFilter.thisMonth:
        return DateTime(now.year, now.month, 1);
      case LeaderboardFilter.allTime:
        return null;
    }
  }
}

final leaderboardProvider =
    StateNotifierProvider<LeaderboardNotifier, LeaderboardState>(
  (_) => LeaderboardNotifier(),
);

final currentUidProvider = Provider<String?>(
  (_) => FirebaseAuth.instance.currentUser?.uid,
);