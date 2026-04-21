import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../models/club.dart';
import '../providers/club_provider.dart';
import '../services/club_service.dart';

class ClubsHubScreen extends ConsumerStatefulWidget {
  const ClubsHubScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<ClubsHubScreen> createState() => _ClubsHubScreenState();
}

class _ClubsHubScreenState extends ConsumerState<ClubsHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _switchToDiscover() {
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppTheme.textPrimary, size: 20),
                onPressed: () => context.pop(),
              ),
        title: const Text(
          'CLUBS',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 2,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
          tabs: const [
            Tab(text: 'MY CLUBS'),
            Tab(text: 'DISCOVER'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MyClubsTab(onBrowse: _switchToDiscover),
          const _DiscoverTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accent,
        foregroundColor: AppTheme.background,
        onPressed: () => context.push('/clubs/create'),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MY CLUBS tab
// ---------------------------------------------------------------------------

class _MyClubsTab extends ConsumerWidget {
  const _MyClubsTab({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userClubsProvider);
    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: AppTheme.speedRed)),
      ),
      data: (clubs) {
        if (clubs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.groups_outlined,
                      color: AppTheme.textSecondary, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    "You haven't joined any clubs yet",
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: onBrowse,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accent,
                      side: const BorderSide(color: AppTheme.accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      'Browse clubs',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: clubs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _ClubCard(club: clubs[i]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// DISCOVER tab
// ---------------------------------------------------------------------------

class _DiscoverTab extends ConsumerStatefulWidget {
  const _DiscoverTab();

  @override
  ConsumerState<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<_DiscoverTab> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<Club> _searchResults = [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    if (q == _query) return;
    if (q.isEmpty) {
      setState(() {
        _query = '';
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _runSearch(q),
    );
  }

  Future<void> _runSearch(String q) async {
    _query = q;
    try {
      final results = await clubService.searchClubs(q);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            cursorColor: AppTheme.accent,
            style:
                const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search clubs...',
              hintStyle: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppTheme.textSecondary, size: 20),
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppTheme.accent.withValues(alpha: 0.15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppTheme.accent.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.accent, width: 1.5),
              ),
            ),
          ),
        ),
        Expanded(child: _buildBody(uid)),
      ],
    );
  }

  Widget _buildBody(String uid) {
    if (_searching) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    if (_query.isNotEmpty) {
      if (_searchResults.isEmpty) {
        return const _EmptyState(
          icon: Icons.search_off_rounded,
          label: 'No clubs found',
        );
      }
      return _ClubList(clubs: _searchResults, uid: uid);
    }

    final allAsync = ref.watch(allClubsProvider);
    return allAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: AppTheme.speedRed)),
      ),
      data: (clubs) {
        final sorted = [...clubs]
          ..sort((a, b) => b.memberCount.compareTo(a.memberCount));
        if (sorted.isEmpty) {
          return const _EmptyState(
            icon: Icons.groups_outlined,
            label: 'No clubs yet — be the first!',
          );
        }
        return _ClubList(clubs: sorted, uid: uid);
      },
    );
  }
}

class _ClubList extends StatelessWidget {
  const _ClubList({required this.clubs, required this.uid});

  final List<Club> clubs;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: clubs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) =>
          _ClubCard(club: clubs[i], uid: uid, showJoinAction: true),
    );
  }
}

// ---------------------------------------------------------------------------
// Club card (shared between tabs)
// ---------------------------------------------------------------------------

class _ClubCard extends ConsumerWidget {
  const _ClubCard({required this.club, this.uid, this.showJoinAction = false});

  final Club club;
  final String? uid;
  final bool showJoinAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMember = club.memberUids.contains(currentUid);

    return GestureDetector(
      onTap: () => context.push('/clubs/${club.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.accent.withValues(alpha: 0.15),
          ),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (club.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      club.description,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${club.memberCount} member${club.memberCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (showJoinAction)
              isMember
                  ? const _JoinedChip()
                  : _JoinButton(club: club)
            else
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Joined chip (non-tappable)
// ---------------------------------------------------------------------------

class _JoinedChip extends StatelessWidget {
  const _JoinedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
      ),
      child: const Text(
        'Joined',
        style: TextStyle(
          color: AppTheme.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Join button
// ---------------------------------------------------------------------------

class _JoinButton extends ConsumerStatefulWidget {
  const _JoinButton({required this.club});

  final Club club;

  @override
  ConsumerState<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends ConsumerState<_JoinButton> {
  bool _loading = false;

  Future<void> _join() async {
    if (widget.club.memberCount >= 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This club is full'),
          backgroundColor: AppTheme.surfaceHigh,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await clubService.joinClub(widget.club.id);
      ref.invalidate(userClubsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined ${widget.club.name}!'),
            backgroundColor: AppTheme.surfaceHigh,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.speedRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _loading ? null : _join,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.7)),
        ),
        child: _loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    color: AppTheme.accent, strokeWidth: 2),
              )
            : const Text(
                'Join',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state placeholder
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 48),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
