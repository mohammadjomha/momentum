import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../services/friend_service.dart';
import '../widgets/user_mini_card.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class FriendSearchScreen extends ConsumerStatefulWidget {
  const FriendSearchScreen({super.key});

  @override
  ConsumerState<FriendSearchScreen> createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState extends ConsumerState<FriendSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<_UserResult> _results = [];
  bool _loading = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String raw) {
    _debounce?.cancel();
    final query = raw.trim();
    if (query == _lastQuery) return;
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
        _lastQuery = '';
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    _lastQuery = query;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: '$query\uf8ff')
          .limit(20)
          .get();

      if (!mounted) return;

      final results = snap.docs
          .where((d) => d.id != myUid)
          .map((d) {
            final data = d.data();
            final car = data['car'] as Map<String, dynamic>? ?? {};
            final make = (car['make'] as String?) ?? '';
            final model = (car['model'] as String?) ?? '';
            final carLine = [make, model].where((s) => s.isNotEmpty).join(' ');
            return _UserResult(
              uid: d.id,
              username: (data['username'] as String?) ?? d.id,
              carLine: carLine,
            );
          })
          .toList();

      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

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
          'FIND FRIENDS',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onQueryChanged,
              cursorColor: AppTheme.accent,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search by username…',
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
                  borderSide:
                      BorderSide(color: AppTheme.accent.withValues(alpha: 0.15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppTheme.accent.withValues(alpha: 0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.accent, width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody(myUid)),
        ],
      ),
    );
  }

  Widget _buildBody(String myUid) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    if (_lastQuery.isEmpty) {
      return const Center(
        child: _Placeholder(
          icon: Icons.person_search_rounded,
          label: 'Search for a username to find friends',
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: _Placeholder(
          icon: Icons.search_off_rounded,
          label: 'No users found',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final user = _results[i];
        return _SearchResultTile(
          user: user,
          myUid: myUid,
          ref: ref,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Result tile — stateful so it can show relationship status inline
// ---------------------------------------------------------------------------

class _SearchResultTile extends StatefulWidget {
  final _UserResult user;
  final String myUid;
  final WidgetRef ref;

  const _SearchResultTile({
    required this.user,
    required this.myUid,
    required this.ref,
  });

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  RelationshipStatus? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await friendService.getRelationshipStatus(
        widget.myUid, widget.user.uid);
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: () => showUserMiniCard(
          context,
          widget.ref,
          currentUid: widget.myUid,
          targetUid: widget.user.uid,
          username: widget.user.username,
          carModel:
              widget.user.carLine.isNotEmpty ? widget.user.carLine : null,
          tripCount: 0,
          totalDistance: 0,
          avgSmoothness: 0,
        ),
        title: Text(
          widget.user.username,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: widget.user.carLine.isNotEmpty
            ? Text(
                widget.user.carLine,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              )
            : null,
        trailing: _StatusBadge(status: _status),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status badge — read-only indicator (action happens inside mini card)
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final RelationshipStatus? status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case null:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 1.5, color: AppTheme.textSecondary),
        );
      case RelationshipStatus.friends:
        return const _Chip(label: 'FRIENDS', color: AppTheme.accent);
      case RelationshipStatus.pendingSent:
        return _Chip(
            label: 'PENDING',
            color: AppTheme.textSecondary.withValues(alpha: 0.6));
      case RelationshipStatus.pendingReceived:
        return const _Chip(label: 'INCOMING', color: AppTheme.speedYellow);
      case RelationshipStatus.none:
        return const SizedBox.shrink();
    }
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder
// ---------------------------------------------------------------------------

class _Placeholder extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Placeholder({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 48),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _UserResult {
  final String uid;
  final String username;
  final String carLine;

  const _UserResult(
      {required this.uid, required this.username, required this.carLine});
}