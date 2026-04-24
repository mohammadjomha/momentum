import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../friends/widgets/user_mini_card.dart';
import '../providers/leaderboard_provider.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(leaderboardProvider);
    final currentUid = ref.watch(currentUidProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              filter: state.filter,
              onRefresh: () => ref.read(leaderboardProvider.notifier).refresh(),
            ),
            _FilterToggle(
              selected: state.filter,
              onSelect: (f) =>
                  ref.read(leaderboardProvider.notifier).setFilter(f),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _Body(
                state: state,
                currentUid: currentUid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final LeaderboardFilter filter;
  final VoidCallback onRefresh;

  const _Header({required this.filter, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
      child: Row(
        children: [
          const Text(
            'LEADERBOARD',
            style: TextStyle(
              color: AppTheme.accent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppTheme.textSecondary, size: 20),
            onPressed: onRefresh,
            splashRadius: 20,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }
}

class _FilterToggle extends StatelessWidget {
  final LeaderboardFilter selected;
  final ValueChanged<LeaderboardFilter> onSelect;

  const _FilterToggle({required this.selected, required this.onSelect});

  static const _labels = {
    LeaderboardFilter.today: 'Today',
    LeaderboardFilter.thisWeek: 'This Week',
    LeaderboardFilter.thisMonth: 'This Month',
    LeaderboardFilter.allTime: 'All Time',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: LeaderboardFilter.values.map((f) {
            final isActive = f == selected;
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.accent : Colors.transparent,
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
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final LeaderboardState state;
  final String? currentUid;

  const _Body({required this.state, required this.currentUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.entries.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.accent,
          strokeWidth: 2,
        ),
      );
    }

    if (state.error != null) {
      return const Center(
        child: Text(
          'Failed to load leaderboard',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
      );
    }

    if (state.entries.isEmpty) {
      return const Center(
        child: Text(
          'No trips recorded this period',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
      );
    }

    return AnimatedOpacity(
      opacity: state.isRefreshing ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: state.entries.length,
        itemBuilder: (context, i) {
          final entry = state.entries[i];
          final isSelf = entry.uid == currentUid;
          final allTime = state.allTimeByUid[entry.uid] ?? entry;
          return _EntryCard(
            entry: entry,
            isSelf: isSelf,
            onTap: isSelf || currentUid == null
                ? null
                : () => showUserMiniCard(
                      context,
                      ref,
                      currentUid: currentUid!,
                      targetUid: entry.uid,
                      username: entry.username,
                      carModel: entry.carModel,
                      tripCount: allTime.tripCount,
                      totalDistance: allTime.distance,
                      avgSmoothness: allTime.smoothnessScore,
                    ),
          );
        },
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isSelf;
  final VoidCallback? onTap;

  const _EntryCard({
    required this.entry,
    required this.isSelf,
    required this.onTap,
  });

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          // Rank
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
          // Username + car
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
          // Stats column
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
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '▪ ${entry.distance.toStringAsFixed(1)} km',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
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