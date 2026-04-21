import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/trip_history/models/trip_model.dart';
import '../../friends/widgets/user_mini_card.dart';
import '../../leaderboard/providers/leaderboard_provider.dart';
import '../models/club.dart';
import '../models/club_post.dart';
import '../providers/club_provider.dart';
import '../services/club_service.dart';
import '../widgets/create_post_sheet.dart';
import '../widgets/post_card.dart';

// ---------------------------------------------------------------------------
// Local providers for club leaderboard (not exported to club_provider.dart)
// ---------------------------------------------------------------------------

final _clubLbFilterProvider =
    StateProvider.family<LeaderboardFilter, String>((_, id) =>
        LeaderboardFilter.thisWeek);

final _clubLbProvider =
    FutureProvider.family<_ClubLbResult, (String, LeaderboardFilter)>(
        (ref, args) async {
  final (clubId, filter) = args;

  // We need memberUids — read from the club stream's current value
  final clubAsync = ref.read(clubDetailProvider(clubId));
  final club = clubAsync.valueOrNull;
  if (club == null || club.memberUids.isEmpty) {
    return _ClubLbResult(entries: [], allTimeByUid: {});
  }

  final db = FirebaseFirestore.instance;
  final now = DateTime.now();
  final since = _startDate(filter, now);

  final memberUids = club.memberUids;

  Future<List<TripModel>> queryBatch(List<String> uids, DateTime? from) async {
    Query<Map<String, dynamic>> q = db
        .collection('trips')
        .where('uid', whereIn: uids)
        .where('smoothnessScore', isGreaterThan: 0);
    if (from != null) {
      q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    final snap = await q.get();
    return snap.docs.map(TripModel.fromDoc).toList();
  }

  // Split into batches of 30 (Firestore whereIn limit)
  final filteredTrips = <TripModel>[];
  final allTimeTrips = <TripModel>[];

  for (var i = 0; i < memberUids.length; i += 30) {
    final batch =
        memberUids.sublist(i, (i + 30).clamp(0, memberUids.length));
    final fRes = queryBatch(batch, since);
    final aRes = filter == LeaderboardFilter.allTime
        ? Future.value(<TripModel>[])
        : queryBatch(batch, null);
    final results = await Future.wait([fRes, aRes]);
    filteredTrips.addAll(results[0]);
    allTimeTrips.addAll(results[1]);
  }

  final effectiveAllTime =
      filter == LeaderboardFilter.allTime ? filteredTrips : allTimeTrips;

  final entries = _buildEntries(filteredTrips);
  final allTimeEntries = _buildEntries(effectiveAllTime);

  // Fetch car models
  final allUids = {
    ...entries.map((e) => e.uid),
    ...allTimeEntries.map((e) => e.uid),
  }.toList();
  final carByUid = await _fetchCarModels(allUids, db);

  final ranked = entries
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

  return _ClubLbResult(entries: ranked, allTimeByUid: allTimeByUid);
});

class _ClubLbResult {
  final List<LeaderboardEntry> entries;
  final Map<String, LeaderboardEntry> allTimeByUid;
  const _ClubLbResult({required this.entries, required this.allTimeByUid});
}

List<LeaderboardEntry> _buildEntries(List<TripModel> trips) {
  final byUid = <String, List<TripModel>>{};
  for (final t in trips.where((t) => t.distance >= 0.5)) {
    byUid.putIfAbsent(t.uid, () => []).add(t);
  }
  final agg = byUid.entries.map((e) {
    final userTrips = e.value;
    final scored =
        userTrips.where((t) => t.smoothnessScore > 0).toList();
    final avgSmooth = scored.isEmpty
        ? 0.0
        : scored.fold(0.0, (s, t) => s + t.smoothnessScore) /
            scored.length;
    final totalDist = userTrips.fold(0.0, (s, t) => s + t.distance);
    final avgSpd = userTrips.isEmpty
        ? 0.0
        : userTrips.fold(0.0, (s, t) => s + t.avgSpeed) /
            userTrips.length;
    return (
      uid: e.key,
      username: userTrips.first.username,
      avgSmoothness: avgSmooth,
      totalDistance: totalDist,
      avgSpeed: avgSpd,
      tripCount: userTrips.length,
    );
  }).toList()
    ..sort((a, b) {
      final c1 = b.avgSmoothness.compareTo(a.avgSmoothness);
      if (c1 != 0) return c1;
      final c2 = b.totalDistance.compareTo(a.totalDistance);
      if (c2 != 0) return c2;
      return b.avgSpeed.compareTo(a.avgSpeed);
    });

  return agg.asMap().entries
      .map((e) => LeaderboardEntry(
            rank: e.key + 1,
            uid: e.value.uid,
            username: e.value.username,
            carModel: null,
            smoothnessScore: e.value.avgSmoothness,
            distance: e.value.totalDistance,
            avgSpeed: e.value.avgSpeed,
            tripCount: e.value.tripCount,
          ))
      .toList();
}

Future<Map<String, String?>> _fetchCarModels(
    List<String> uids, FirebaseFirestore db) async {
  if (uids.isEmpty) return {};
  final result = <String, String?>{};
  for (var i = 0; i < uids.length; i += 10) {
    final batch = uids.sublist(i, (i + 10).clamp(0, uids.length));
    final docs = await db
        .collection('users')
        .where(FieldPath.documentId, whereIn: batch)
        .get();
    for (final doc in docs.docs) {
      final car = doc.data()['car'] as Map<String, dynamic>?;
      final make = car?['make'] as String?;
      final model = car?['model'] as String?;
      result[doc.id] =
          (make != null && model != null) ? '$make $model' : null;
    }
  }
  return result;
}

DateTime? _startDate(LeaderboardFilter filter, DateTime now) {
  switch (filter) {
    case LeaderboardFilter.today:
      return DateTime(now.year, now.month, now.day);
    case LeaderboardFilter.thisWeek:
      return DateTime(now.year, now.month, now.day - (now.weekday - 1));
    case LeaderboardFilter.thisMonth:
      return DateTime(now.year, now.month, 1);
    case LeaderboardFilter.allTime:
      return null;
  }
}

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class ClubDetailScreen extends ConsumerWidget {
  const ClubDetailScreen({super.key, required this.clubId});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubAsync = ref.watch(clubDetailProvider(clubId));
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return clubAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.accent)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
            child: Text('Error: $e',
                style: const TextStyle(color: AppTheme.speedRed))),
      ),
      data: (club) {
        if (club == null) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            appBar: AppBar(backgroundColor: AppTheme.background, elevation: 0),
            body: const Center(
              child: Text('Club not found.',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
          );
        }

        final isMember = club.memberUids.contains(uid);
        final isOwner = club.ownerUid == uid;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: AppTheme.background,
            appBar: AppBar(
              backgroundColor: AppTheme.background,
              elevation: 0,
              title: Text(
                club.name.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              actions: [
                if (isOwner)
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: AppTheme.textPrimary, size: 20),
                    tooltip: 'Club settings',
                    onPressed: () =>
                        _showSettingsSheet(context, ref, club, uid),
                  ),
              ],
              bottom: const TabBar(
                indicatorColor: AppTheme.accent,
                indicatorWeight: 2,
                labelColor: AppTheme.accent,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
                tabs: [
                  Tab(text: 'FEED'),
                  Tab(text: 'LEADERBOARD'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _FeedTab(club: club, clubId: clubId, uid: uid,
                    isMember: isMember, isOwner: isOwner),
                _LeaderboardTab(clubId: clubId, uid: uid),
              ],
            ),
            bottomNavigationBar: _buildBottomBar(
                context, ref, club, uid, isMember, isOwner),
          ),
        );
      },
    );
  }

  Widget? _buildBottomBar(BuildContext context, WidgetRef ref, Club club,
      String uid, bool isMember, bool isOwner) {
    if (!isMember) {
      return _JoinBar(clubId: clubId, ref: ref);
    }
    if (!isOwner) {
      return _LeaveBar(club: club, uid: uid);
    }
    return null;
  }

  void _showSettingsSheet(
      BuildContext context, WidgetRef ref, Club club, String uid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: AppTheme.textPrimary, size: 20),
              title: const Text('Edit club',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Coming soon'),
                    backgroundColor: AppTheme.surfaceHigh,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.speedRed, size: 20),
              title: const Text('Delete club',
                  style: TextStyle(
                      color: AppTheme.speedRed,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, ref, uid);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, String uid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Club',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'This will permanently delete the club and all its content.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await clubService.deleteClub(clubId);
              if (context.mounted) context.go('/clubs');
            },
            child: const Text('DELETE',
                style: TextStyle(color: AppTheme.speedRed)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FEED tab
// ---------------------------------------------------------------------------

class _FeedTab extends ConsumerWidget {
  const _FeedTab({
    required this.club,
    required this.clubId,
    required this.uid,
    required this.isMember,
    required this.isOwner,
  });

  final Club club;
  final String clubId;
  final String uid;
  final bool isMember;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(clubPostsProvider(clubId));

    return postsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accent)),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppTheme.speedRed))),
      data: (posts) {
        final pinnedId = club.pinnedPostId;
        final feedPosts =
            pinnedId != null ? posts.where((p) => p.id != pinnedId).toList() : posts;

        return Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, isMember ? 76 : 16),
              children: [
                // Club header
                _ClubHeader(club: club),
                const SizedBox(height: 16),

                // Pinned post
                if (pinnedId != null)
                  _PinnedPostLoader(
                      pinnedId: pinnedId, clubId: clubId, club: club),

                // Posts or empty state
                if (feedPosts.isEmpty && pinnedId == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Column(
                      children: [
                        const Icon(Icons.article_outlined,
                            color: AppTheme.textSecondary, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          isMember
                              ? 'No posts yet. Be the first to post!'
                              : 'No posts yet.',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ...feedPosts.map((p) => PostCard(
                        post: p,
                        clubId: clubId,
                        club: club,
                      )),
              ],
            ),

            // Post creation bar (members only, pinned at bottom)
            if (isMember)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _PostCreationBar(clubId: clubId),
              ),
          ],
        );
      },
    );
  }
}

class _PinnedPostLoader extends ConsumerWidget {
  const _PinnedPostLoader({
    required this.pinnedId,
    required this.clubId,
    required this.club,
  });

  final String pinnedId;
  final String clubId;
  final Club club;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<ClubPost?>(
      future: ref.read(clubServiceProvider).fetchPost(pinnedId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        return PostCard(
          post: snapshot.data!,
          clubId: clubId,
          club: club,
          isPinned: true,
        );
      },
    );
  }
}

// Provider so widgets can call clubService via ref.read
final clubServiceProvider = Provider<ClubService>((_) => clubService);

class _ClubHeader extends StatelessWidget {
  const _ClubHeader({required this.club});

  final Club club;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.group_rounded,
                color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${club.memberCount} member${club.memberCount == 1 ? '' : 's'} · by ${club.ownerUsername}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
                if (club.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    club.description,
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCreationBar extends StatelessWidget {
  const _PostCreationBar({required this.clubId});

  final String clubId;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: GestureDetector(
        onTap: () => _showCreatePost(context),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppTheme.accent.withValues(alpha: 0.5)),
          ),
          child: const Row(
            children: [
              Icon(Icons.add_rounded, color: AppTheme.accent, size: 18),
              SizedBox(width: 8),
              Text(
                'New post',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreatePost(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreatePostSheet(clubId: clubId),
    );
  }
}

// ---------------------------------------------------------------------------
// Join bar (non-member)
// ---------------------------------------------------------------------------

class _JoinBar extends ConsumerStatefulWidget {
  const _JoinBar({required this.clubId, required this.ref});

  final String clubId;
  final WidgetRef ref;

  @override
  ConsumerState<_JoinBar> createState() => _JoinBarState();
}

class _JoinBarState extends ConsumerState<_JoinBar> {
  bool _loading = false;

  Future<void> _join() async {
    setState(() => _loading = true);
    try {
      await clubService.joinClub(widget.clubId);
      ref.invalidate(userClubsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You joined the club!'),
            backgroundColor: AppTheme.surfaceHigh,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.speedRed),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: _loading ? null : _join,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: AppTheme.background,
            disabledBackgroundColor:
                AppTheme.accent.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: AppTheme.background, strokeWidth: 2),
                )
              : const Text('JOIN CLUB',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leave bar (member, non-owner)
// ---------------------------------------------------------------------------

class _LeaveBar extends ConsumerWidget {
  const _LeaveBar({required this.club, required this.uid});

  final Club club;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppTheme.background,
      padding: EdgeInsets.fromLTRB(
          20, 4, 20, 4 + MediaQuery.of(context).padding.bottom),
      child: TextButton(
        onPressed: () => _confirmLeave(context, ref),
        child: const Text(
          'Leave club',
          style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  void _confirmLeave(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Leave Club',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Leave ${club.name}?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await clubService.leaveClub(club.id);
              ref.invalidate(userClubsProvider);
              if (context.mounted) context.go('/clubs');
            },
            child: const Text('LEAVE',
                style: TextStyle(color: AppTheme.speedRed)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LEADERBOARD tab
// ---------------------------------------------------------------------------

class _LeaderboardTab extends ConsumerWidget {
  const _LeaderboardTab({required this.clubId, required this.uid});

  final String clubId;
  final String uid;

  static const _labels = {
    LeaderboardFilter.today: 'Today',
    LeaderboardFilter.thisWeek: 'This Week',
    LeaderboardFilter.thisMonth: 'This Month',
    LeaderboardFilter.allTime: 'All Time',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_clubLbFilterProvider(clubId));
    final async = ref.watch(_clubLbProvider((clubId, filter)));

    return Column(
      children: [
        // Filter toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: LeaderboardFilter.values.map((f) {
                final isActive = f == filter;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => ref
                        .read(_clubLbFilterProvider(clubId).notifier)
                        .state = f,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _labels[f]!,
                        style: TextStyle(
                          color: isActive
                              ? AppTheme.background
                              : AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w400,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        Expanded(
          child: async.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accent)),
            error: (e, _) => Center(
                child: Text('Error: $e',
                    style:
                        const TextStyle(color: AppTheme.speedRed))),
            data: (result) {
              if (result.entries.isEmpty) {
                return const Center(
                  child: Text(
                    'Not enough data',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 14),
                  ),
                );
              }
              return ListView.builder(
                padding:
                    const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: result.entries.length,
                itemBuilder: (context, i) {
                  final entry = result.entries[i];
                  final isSelf = entry.uid == uid;
                  final allTime =
                      result.allTimeByUid[entry.uid] ?? entry;
                  return _LbEntryCard(
                    entry: entry,
                    isSelf: isSelf,
                    onTap: isSelf
                        ? null
                        : () => showUserMiniCard(
                              context,
                              ref,
                              currentUid: uid,
                              targetUid: entry.uid,
                              username: entry.username,
                              carModel: entry.carModel,
                              tripCount: allTime.tripCount,
                              totalDistance: allTime.distance,
                              avgSmoothness: allTime.smoothnessScore,
                            ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LbEntryCard extends StatelessWidget {
  const _LbEntryCard({
    required this.entry,
    required this.isSelf,
    required this.onTap,
  });

  final LeaderboardEntry entry;
  final bool isSelf;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppTheme.accent.withValues(alpha: 0.08),
        highlightColor: AppTheme.accent.withValues(alpha: 0.04),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelf
                  ? AppTheme.accent.withValues(alpha: 0.3)
                  : AppTheme.accent.withValues(alpha: 0.08),
              width: isSelf ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  '#${entry.rank}',
                  style: TextStyle(
                    color: entry.rank <= 3
                        ? AppTheme.accent
                        : AppTheme.textSecondary,
                    fontSize: entry.rank <= 3 ? 22 : 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.username,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.carModel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.carModel!,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    entry.smoothnessScore.toStringAsFixed(1),
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.tripCount} trip${entry.tripCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '▪ ${entry.distance.toStringAsFixed(1)} km',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
