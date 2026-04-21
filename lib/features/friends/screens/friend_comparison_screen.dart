import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/trip_history/models/trip_model.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _db = FirebaseFirestore.instance;

class _ComparisonData {
  final String myUsername;
  final String myCarLine;
  final String friendUsername;
  final String friendCarLine;

  final int myTrips;
  final double myDistance;
  final double myBestSmooth;
  final double myAvgSmooth;
  final double myAvgSpeed;
  final int myHardBrakes;
  final int myHardAccels;

  final int friendTrips;
  final double friendDistance;
  final double friendBestSmooth;
  final double friendAvgSmooth;
  final double friendAvgSpeed;
  final int friendHardBrakes;
  final int friendHardAccels;

  const _ComparisonData({
    required this.myUsername,
    required this.myCarLine,
    required this.friendUsername,
    required this.friendCarLine,
    required this.myTrips,
    required this.myDistance,
    required this.myBestSmooth,
    required this.myAvgSmooth,
    required this.myAvgSpeed,
    required this.myHardBrakes,
    required this.myHardAccels,
    required this.friendTrips,
    required this.friendDistance,
    required this.friendBestSmooth,
    required this.friendAvgSmooth,
    required this.friendAvgSpeed,
    required this.friendHardBrakes,
    required this.friendHardAccels,
  });
}

final _comparisonProvider =
    FutureProvider.family<_ComparisonData, String>((ref, friendUid) async {
  final myUid = FirebaseAuth.instance.currentUser!.uid;

  final results = await Future.wait([
    _db
        .collection('trips')
        .where('uid', isEqualTo: myUid)
        .get(),
    _db
        .collection('trips')
        .where('uid', isEqualTo: friendUid)
        .get(),
    _db.collection('users').doc(myUid).get(),
    _db.collection('users').doc(friendUid).get(),
  ]);

  final mySnap = results[0] as QuerySnapshot;
  final friendSnap = results[1] as QuerySnapshot;
  final myUserDoc = results[2] as DocumentSnapshot;
  final friendUserDoc = results[3] as DocumentSnapshot;

  List<TripModel> parseTrips(QuerySnapshot snap) => snap.docs
      .map((d) => TripModel.fromDoc(d))
      .where((t) => t.smoothnessScore > 0 && t.distance >= 0.5)
      .toList();

  final myTrips = parseTrips(mySnap);
  final friendTrips = parseTrips(friendSnap);

  _ComparisonStats buildStats(List<TripModel> trips) {
    if (trips.isEmpty) {
      return const _ComparisonStats(
        count: 0,
        distance: 0,
        bestSmooth: 0,
        avgSmooth: 0,
        avgSpeed: 0,
        hardBrakes: 0,
        hardAccels: 0,
      );
    }
    final count = trips.length;
    final distance = trips.fold(0.0, (s, t) => s + t.distance);
    final bestSmooth =
        trips.map((t) => t.smoothnessScore).reduce((a, b) => a > b ? a : b);
    final avgSmooth =
        trips.fold(0.0, (s, t) => s + t.smoothnessScore) / count;
    final avgSpeed = trips.fold(0.0, (s, t) => s + t.avgSpeed) / count;
    final hardBrakes = trips.fold(0, (s, t) => s + t.hardBrakeCount);
    final hardAccels = trips.fold(0, (s, t) => s + t.hardAccelCount);
    return _ComparisonStats(
      count: count,
      distance: distance,
      bestSmooth: bestSmooth,
      avgSmooth: avgSmooth,
      avgSpeed: avgSpeed,
      hardBrakes: hardBrakes,
      hardAccels: hardAccels,
    );
  }

  String carLineFrom(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final car = data['car'] as Map<String, dynamic>? ?? {};
    return [car['make'] as String? ?? '', car['model'] as String? ?? '']
        .where((s) => s.isNotEmpty)
        .join(' ');
  }

  String usernameFrom(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return (data['username'] as String?) ?? '';
  }

  final my = buildStats(myTrips);
  final fr = buildStats(friendTrips);

  return _ComparisonData(
    myUsername: usernameFrom(myUserDoc),
    myCarLine: carLineFrom(myUserDoc),
    friendUsername: usernameFrom(friendUserDoc),
    friendCarLine: carLineFrom(friendUserDoc),
    myTrips: my.count,
    myDistance: my.distance,
    myBestSmooth: my.bestSmooth,
    myAvgSmooth: my.avgSmooth,
    myAvgSpeed: my.avgSpeed,
    myHardBrakes: my.hardBrakes,
    myHardAccels: my.hardAccels,
    friendTrips: fr.count,
    friendDistance: fr.distance,
    friendBestSmooth: fr.bestSmooth,
    friendAvgSmooth: fr.avgSmooth,
    friendAvgSpeed: fr.avgSpeed,
    friendHardBrakes: fr.hardBrakes,
    friendHardAccels: fr.hardAccels,
  );
});

class _ComparisonStats {
  final int count;
  final double distance;
  final double bestSmooth;
  final double avgSmooth;
  final double avgSpeed;
  final int hardBrakes;
  final int hardAccels;

  const _ComparisonStats({
    required this.count,
    required this.distance,
    required this.bestSmooth,
    required this.avgSmooth,
    required this.avgSpeed,
    required this.hardBrakes,
    required this.hardAccels,
  });
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class FriendComparisonScreen extends ConsumerWidget {
  final String friendUid;

  const FriendComparisonScreen({super.key, required this.friendUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_comparisonProvider(friendUid));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'COMPARISON',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
        error: (e, st) => Center(
          child: Text(
            'Failed to load comparison.',
            style: const TextStyle(color: AppTheme.speedRed, fontSize: 14),
          ),
        ),
        data: (data) => _ComparisonBody(data: data),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _ComparisonBody extends StatelessWidget {
  final _ComparisonData data;

  const _ComparisonBody({required this.data});

  String _winner() {
    if (data.myAvgSmooth > data.friendAvgSmooth) return 'me';
    if (data.friendAvgSmooth > data.myAvgSmooth) return 'friend';
    return 'tie';
  }

  @override
  Widget build(BuildContext context) {
    final winner = _winner();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildWinnerBanner(winner),
          const SizedBox(height: 20),
          _buildStatsCard(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(child: _buildDriverChip(data.myUsername, data.myCarLine, true)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: const Text(
            'VS',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
            child:
                _buildDriverChip(data.friendUsername, data.friendCarLine, false)),
      ],
    );
  }

  Widget _buildDriverChip(String username, String carLine, bool isMe) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(
            username,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (carLine.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              carLine,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWinnerBanner(String winner) {
    final String label;
    if (winner == 'me') {
      label = '${data.myUsername} is smoother';
    } else if (winner == 'friend') {
      label = '${data.friendUsername} is smoother';
    } else {
      label = 'Evenly Matched';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_rounded,
              color: AppTheme.accent, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          _statRow(
            label: 'Total Trips',
            myVal: data.myTrips.toString(),
            friendVal: data.friendTrips.toString(),
            myWins: data.myTrips > data.friendTrips,
            friendWins: data.friendTrips > data.myTrips,
            isFirst: true,
          ),
          _divider(),
          _statRow(
            label: 'Distance (km)',
            myVal: data.myDistance.toStringAsFixed(1),
            friendVal: data.friendDistance.toStringAsFixed(1),
            myWins: data.myDistance > data.friendDistance,
            friendWins: data.friendDistance > data.myDistance,
          ),
          _divider(),
          _statRow(
            label: 'Best Smoothness',
            myVal: data.myBestSmooth.toStringAsFixed(1),
            friendVal: data.friendBestSmooth.toStringAsFixed(1),
            myWins: data.myBestSmooth > data.friendBestSmooth,
            friendWins: data.friendBestSmooth > data.myBestSmooth,
          ),
          _divider(),
          _statRow(
            label: 'Avg Smoothness',
            myVal: data.myAvgSmooth.toStringAsFixed(1),
            friendVal: data.friendAvgSmooth.toStringAsFixed(1),
            myWins: data.myAvgSmooth > data.friendAvgSmooth,
            friendWins: data.friendAvgSmooth > data.myAvgSmooth,
          ),
          _divider(),
          _statRow(
            label: 'Avg Speed (km/h)',
            myVal: data.myAvgSpeed.toStringAsFixed(1),
            friendVal: data.friendAvgSpeed.toStringAsFixed(1),
            myWins: data.myAvgSpeed > data.friendAvgSpeed,
            friendWins: data.friendAvgSpeed > data.myAvgSpeed,
          ),
          _divider(),
          _statRow(
            label: 'Hard Brakes',
            myVal: data.myHardBrakes.toString(),
            friendVal: data.friendHardBrakes.toString(),
            // fewer brakes = better
            myWins: data.myHardBrakes < data.friendHardBrakes,
            friendWins: data.friendHardBrakes < data.myHardBrakes,
          ),
          _divider(),
          _statRow(
            label: 'Quick Accels',
            myVal: data.myHardAccels.toString(),
            friendVal: data.friendHardAccels.toString(),
            myWins: data.myHardAccels < data.friendHardAccels,
            friendWins: data.friendHardAccels < data.myHardAccels,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        thickness: 1,
        color: AppTheme.accent.withValues(alpha: 0.08),
        indent: 16,
        endIndent: 16,
      );

  Widget _statRow({
    required String label,
    required String myVal,
    required String friendVal,
    required bool myWins,
    required bool friendWins,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final myColor = myWins
        ? AppTheme.accent
        : (friendWins ? AppTheme.textSecondary : AppTheme.textPrimary);
    final friendColor = friendWins
        ? AppTheme.accent
        : (myWins ? AppTheme.textSecondary : AppTheme.textPrimary);

    final radius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(16) : Radius.zero,
      bottom: isLast ? const Radius.circular(16) : Radius.zero,
    );

    return ClipRRect(
      borderRadius: radius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // My value
            Expanded(
              child: Text(
                myVal,
                style: TextStyle(
                  color: myColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            // Label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Friend value
            Expanded(
              child: Text(
                friendVal,
                style: TextStyle(
                  color: friendColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}