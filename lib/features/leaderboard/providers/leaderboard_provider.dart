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
  final double distance;
  final double avgSpeed;
  final int tripCount;

  const LeaderboardEntry({
    required this.rank,
    required this.uid,
    required this.username,
    this.carModel,
    required this.smoothnessScore,
    required this.distance,
    required this.avgSpeed,
    required this.tripCount,
  });
}

class LeaderboardState {
  final List<LeaderboardEntry> entries;
  final Map<String, LeaderboardEntry> allTimeByUid;
  final LeaderboardFilter filter;
  final bool isLoading;
  final String? error;

  const LeaderboardState({
    this.entries = const [],
    this.allTimeByUid = const {},
    this.filter = LeaderboardFilter.thisWeek,
    this.isLoading = false,
    this.error,
  });

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    Map<String, LeaderboardEntry>? allTimeByUid,
    LeaderboardFilter? filter,
    bool? isLoading,
    String? error,
  }) =>
      LeaderboardState(
        entries: entries ?? this.entries,
        allTimeByUid: allTimeByUid ?? this.allTimeByUid,
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
      final now = DateTime.now();
      final dateFilter = _startDate(state.filter, now);

      // Run filtered query and all-time query in parallel
      // (skip second query if filter is already allTime)
      final filteredFuture = _queryTrips(db, dateFilter);
      final allTimeFuture = state.filter == LeaderboardFilter.allTime
          ? Future.value(<TripModel>[])
          : _queryTrips(db, null);

      final results = await Future.wait([filteredFuture, allTimeFuture]);
      final filteredTrips = results[0];
      final allTimeTrips =
          state.filter == LeaderboardFilter.allTime ? filteredTrips : results[1];

      // Build filtered entries
      final allUids = <String>{};
      final entries = _buildEntries(filteredTrips, rankOffset: 1);
      allUids.addAll(entries.map((e) => e.uid));

      // Build all-time lookup (includes any uid not in filtered set)
      final allTimeEntries = _buildEntries(allTimeTrips, rankOffset: 1);
      allUids.addAll(allTimeEntries.map((e) => e.uid));

      final carByUid = await _fetchCarModels(allUids.toList());

      final rankedEntries = entries
          .map((e) => LeaderboardEntry(
                rank: e.rank,
                uid: e.uid,
                username: e.username,
                carModel: carByUid[e.uid],
                smoothnessScore: e.smoothnessScore,
                distance: e.distance,
                avgSpeed: e.avgSpeed,
                tripCount: e.tripCount,
              ))
          .toList();

      final allTimeByUid = {
        for (final e in allTimeEntries)
          e.uid: LeaderboardEntry(
            rank: e.rank,
            uid: e.uid,
            username: e.username,
            carModel: carByUid[e.uid],
            smoothnessScore: e.smoothnessScore,
            distance: e.distance,
            avgSpeed: e.avgSpeed,
            tripCount: e.tripCount,
          ),
      };

      state = state.copyWith(
        entries: rankedEntries,
        allTimeByUid: allTimeByUid,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<List<TripModel>> _queryTrips(
    FirebaseFirestore db,
    DateTime? since,
  ) async {
    Query<Map<String, dynamic>> q = db.collection('trips');
    if (since != null) {
      q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    }
    q = q
        .orderBy('date', descending: false)
        .orderBy('smoothnessScore', descending: true)
        .orderBy('distance', descending: true)
        .orderBy('avgSpeed', descending: true);
    final snap = await q.get();
    return snap.docs.map(TripModel.fromDoc).toList();
  }

  List<LeaderboardEntry> _buildEntries(
    List<TripModel> trips, {
    required int rankOffset,
  }) {
    final Map<String, List<TripModel>> byUid = {};
    for (final t in trips.where((t) => t.distance >= 0.5)) {
      byUid.putIfAbsent(t.uid, () => []).add(t);
    }
    final agg = byUid.entries.map((e) {
      final userTrips = e.value;
      final scored = userTrips.where((t) => t.smoothnessScore > 0).toList();
      final avgSmoothness = scored.isEmpty
          ? 0.0
          : scored.fold(0.0, (s, t) => s + t.smoothnessScore) / scored.length;
      final totalDistance = userTrips.fold(0.0, (s, t) => s + t.distance);
      final avgSpd = userTrips.isEmpty
          ? 0.0
          : userTrips.fold(0.0, (s, t) => s + t.avgSpeed) / userTrips.length;
      return (
        uid: e.key,
        username: userTrips.first.username,
        avgSmoothness: avgSmoothness,
        totalDistance: totalDistance,
        avgSpeed: avgSpd,
        tripCount: userTrips.length,
      );
    }).toList()
      ..sort((a, b) {
        final cmp = b.avgSmoothness.compareTo(a.avgSmoothness);
        if (cmp != 0) return cmp;
        final cmp2 = b.totalDistance.compareTo(a.totalDistance);
        if (cmp2 != 0) return cmp2;
        return b.avgSpeed.compareTo(a.avgSpeed);
      });

    return agg.asMap().entries.map((e) {
      final a = e.value;
      return LeaderboardEntry(
        rank: e.key + rankOffset,
        uid: a.uid,
        username: a.username,
        carModel: null,
        smoothnessScore: a.avgSmoothness,
        distance: a.totalDistance,
        avgSpeed: a.avgSpeed,
        tripCount: a.tripCount,
      );
    }).toList();
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