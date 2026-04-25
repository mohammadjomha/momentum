import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';

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
  final bool isRefreshing;
  final String? error;

  const LeaderboardState({
    this.entries = const [],
    this.allTimeByUid = const {},
    this.filter = LeaderboardFilter.thisWeek,
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  });

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    Map<String, LeaderboardEntry>? allTimeByUid,
    LeaderboardFilter? filter,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
  }) =>
      LeaderboardState(
        entries: entries ?? this.entries,
        allTimeByUid: allTimeByUid ?? this.allTimeByUid,
        filter: filter ?? this.filter,
        isLoading: isLoading ?? this.isLoading,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        error: error,
      );
}

class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  LeaderboardNotifier() : super(const LeaderboardState()) {
    _load();
  }

  // Session-level cache so filter switches never re-fetch the same user doc.
  final Map<String, String?> _carByUid = {};

  Future<void> setFilter(LeaderboardFilter filter) async {
    state = state.copyWith(filter: filter, error: null);
    await _load();
  }

  Future<void> refresh() => _load();

  Future<void> forceRefresh() {
    state = state.copyWith(allTimeByUid: {});
    return _load();
  }

  Future<void> _load() async {
    state = state.copyWith(
      isLoading: state.entries.isEmpty,
      isRefreshing: true,
      error: null,
    );
    try {
      final db = FirebaseFirestore.instance;
      final now = DateTime.now();
      final dateFilter = _startDate(state.filter, now);

      // Run filtered query and (if needed) all-time query in parallel.
      // Skip the all-time query when its result is already cached in state
      // (populated on the first load) or when the current filter IS allTime
      // (in which case filteredTrips == allTimeTrips).
      final needsAllTime = state.filter != LeaderboardFilter.allTime &&
          state.allTimeByUid.isEmpty;
      final filteredFuture = _queryTrips(db, dateFilter);
      final allTimeFuture = needsAllTime
          ? _queryTrips(db, null)
          : Future.value(<TripModel>[]);

      final results = await Future.wait([filteredFuture, allTimeFuture]);
      final filteredTrips = results[0];
      final allTimeTrips =
          state.filter == LeaderboardFilter.allTime ? filteredTrips : results[1];

      // Build filtered entries
      final allUids = <String>{};
      final entries = _buildEntries(filteredTrips, rankOffset: 1);
      allUids.addAll(entries.map((e) => e.uid));

      // Build all-time lookup only when fresh data was fetched; otherwise keep
      // the cached allTimeByUid already in state.
      final allTimeEntries = needsAllTime || state.filter == LeaderboardFilter.allTime
          ? _buildEntries(allTimeTrips, rankOffset: 1)
          : <LeaderboardEntry>[];
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

      // Only overwrite allTimeByUid when we actually fetched fresh all-time data.
      Map<String, LeaderboardEntry>? freshAllTimeByUid;
      if (allTimeEntries.isNotEmpty) {
        freshAllTimeByUid = {
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
      }

      state = state.copyWith(
        entries: rankedEntries,
        allTimeByUid: freshAllTimeByUid,
        isLoading: false,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, isRefreshing: false, error: e.toString());
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
    q = q.orderBy('date', descending: false);
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

    // Only fetch uids not already in the session cache.
    final missing = uids.where((uid) => !_carByUid.containsKey(uid)).toList();

    if (missing.isNotEmpty) {
      // Build one Future per batch of 10, then fire all batches in parallel.
      final futures = <Future<void>>[];
      for (var i = 0; i < missing.length; i += 10) {
        final batch = missing.sublist(
            i, i + 10 > missing.length ? missing.length : i + 10);
        futures.add(
          db
              .collection('users')
              .where(FieldPath.documentId, whereIn: batch)
              .get()
              .then((snap) {
            for (final doc in snap.docs) {
              final car = doc.data()['car'] as Map<String, dynamic>?;
              final make = car?['make'] as String?;
              final model = car?['model'] as String?;
              _carByUid[doc.id] =
                  (make != null && model != null) ? '$make $model' : null;
            }
          }),
        );
      }
      await Future.wait(futures);
    }

    return {for (final uid in uids) uid: _carByUid[uid]};
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
  (ref) => ref.watch(authStateProvider).valueOrNull?.uid,
);