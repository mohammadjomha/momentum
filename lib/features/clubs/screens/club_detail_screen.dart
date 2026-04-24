import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../friends/widgets/user_mini_card.dart';
import '../../leaderboard/providers/leaderboard_provider.dart';
import '../models/club.dart';
import '../models/club_post.dart';
import '../providers/club_leaderboard_provider.dart';
import '../providers/club_provider.dart';
import '../services/club_service.dart';
import '../widgets/create_post_sheet.dart';
import '../widgets/post_card.dart';

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class ClubDetailScreen extends ConsumerWidget {
  const ClubDetailScreen({super.key, required this.clubId});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubAsync = ref.watch(clubDetailProvider(clubId));
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

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
        final isAdmin = club.adminUids.contains(uid);

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
                if (isOwner || isAdmin)
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: AppTheme.textPrimary, size: 20),
                    tooltip: 'Club settings',
                    onPressed: () =>
                        _showSettingsSheet(context, ref, club, uid, isOwner, isAdmin),
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

  void _showSettingsSheet(BuildContext context, WidgetRef ref, Club club,
      String uid, bool isOwner, bool isAdmin) {
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
            if (isOwner)
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
                  _showEditClubSheet(context, ref, club);
                },
              ),
            if (isOwner || isAdmin)
              ListTile(
                leading: const Icon(Icons.people_outline_rounded,
                    color: AppTheme.textPrimary, size: 20),
                title: const Text('Members',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _showMembersSheet(context, ref, club, uid);
                },
              ),
            if (isOwner)
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

  void _showEditClubSheet(BuildContext context, WidgetRef ref, Club club) {
    final nameController = TextEditingController(text: club.name);
    final descController = TextEditingController(text: club.description);
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'EDIT CLUB',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameController,
                  maxLength: 50,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Club name',
                    labelStyle:
                        const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surfaceHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    counterStyle:
                        const TextStyle(color: AppTheme.textSecondary),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descController,
                  maxLength: 200,
                  maxLines: 3,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle:
                        const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surfaceHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    counterStyle:
                        const TextStyle(color: AppTheme.textSecondary),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setState(() => saving = true);
                            try {
                              await clubService.updateClub(
                                clubId,
                                name: nameController.text,
                                description: descController.text,
                              );
                              if (sheetCtx.mounted) {
                                Navigator.pop(sheetCtx);
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Club updated')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            } finally {
                              if (sheetCtx.mounted) {
                                setState(() => saving = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: AppTheme.background,
                      disabledBackgroundColor:
                          AppTheme.accent.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: AppTheme.background, strokeWidth: 2),
                          )
                        : const Text('SAVE',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMembersSheet(
      BuildContext context, WidgetRef ref, Club club, String uid) async {
    // Fetch all member docs in parallel.
    List<_MemberInfo> members;
    try {
      final db = FirebaseFirestore.instance;
      final docs = await Future.wait(
        club.memberUids.map((id) => db.collection('users').doc(id).get()),
      );
      members = docs.map((doc) {
        final data = doc.data() ?? {};
        final carMap = data['car'] as Map<String, dynamic>?;
        final make = (carMap?['make'] as String?) ?? '';
        final model = (carMap?['model'] as String?) ?? '';
        final car =
            (make.isNotEmpty && model.isNotEmpty) ? '$make $model' : '';
        return _MemberInfo(
          uid: doc.id,
          username: (data['username'] as String?) ?? doc.id,
          car: car,
          isOwner: doc.id == club.ownerUid,
          isAdmin: club.adminUids.contains(doc.id),
        );
      }).toList();

      // Sort: owner first, then admins alpha, then members alpha.
      members.sort((_MemberInfo a, _MemberInfo b) {
        if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
        if (a.isAdmin != b.isAdmin) return a.isAdmin ? -1 : 1;
        return a.username.toLowerCase().compareTo(b.username.toLowerCase());
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading members: $e')),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final isViewerOwner = club.ownerUid == uid;
    final isViewerAdmin = club.adminUids.contains(uid);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Members (${club.memberUids.length})',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                itemCount: members.length,
                itemBuilder: (_, i) {
                  final member = members[i];
                  final isSelf = member.uid == uid;
                  final isTarget = !isSelf && !member.isOwner;

                  Widget? badge;
                  if (member.isOwner) {
                    badge = _RoleBadge(label: 'Owner');
                  } else if (member.isAdmin) {
                    badge = _RoleBadge(label: 'Admin');
                  }

                  Widget? menuButton;
                  if (isTarget) {
                    List<PopupMenuEntry<String>> menuItems = [];
                    if (isViewerOwner) {
                      if (member.isAdmin) {
                        menuItems = [
                          const PopupMenuItem(
                              value: 'demote',
                              child: Text('Demote from admin')),
                          const PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove from club')),
                        ];
                      } else {
                        menuItems = [
                          const PopupMenuItem(
                              value: 'promote',
                              child: Text('Make admin')),
                          const PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove from club')),
                        ];
                      }
                    } else if (isViewerAdmin && !member.isAdmin) {
                      menuItems = [
                        const PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove from club')),
                      ];
                    }

                    if (menuItems.isNotEmpty) {
                      menuButton = PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert,
                            color: AppTheme.textSecondary, size: 20),
                        color: AppTheme.surfaceHigh,
                        onSelected: (action) async {
                          Navigator.pop(sheetCtx);
                          try {
                            switch (action) {
                              case 'promote':
                                await clubService.promoteMember(
                                    clubId, member.uid);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Promoted to admin')),
                                  );
                                }
                              case 'demote':
                                await clubService.demoteAdmin(
                                    clubId, member.uid);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Demoted from admin')),
                                  );
                                }
                              case 'remove':
                                await clubService.removeMember(
                                    clubId, member.uid);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Member removed')),
                                  );
                                }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        itemBuilder: (_) => menuItems,
                      );
                    }
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.surfaceHigh,
                      child: Text(
                        member.username.isNotEmpty
                            ? member.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(member.username,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500)),
                    subtitle: member.car.isNotEmpty
                        ? Text(member.car,
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12))
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ?badge,
                        if (menuButton != null) ...[
                          if (badge != null) const SizedBox(width: 4),
                          menuButton,
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Member info model (local to this file)
// ---------------------------------------------------------------------------

class _MemberInfo {
  final String uid;
  final String username;
  final String car;
  final bool isOwner;
  final bool isAdmin;
  const _MemberInfo({
    required this.uid,
    required this.username,
    required this.car,
    required this.isOwner,
    required this.isAdmin,
  });
}

// ---------------------------------------------------------------------------
// Role badge widget (local to this file)
// ---------------------------------------------------------------------------

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
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
    final state = ref.watch(clubLeaderboardProvider(clubId));
    final notifier = ref.read(clubLeaderboardProvider(clubId).notifier);

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
                final isActive = f == state.filter;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => notifier.setFilter(f),
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
          child: _buildBody(context, ref, state),
        ),
      ],
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, ClubLeaderboardState state) {
    if (state.isLoading && state.entries.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.accent));
    }

    if (state.error != null) {
      return Center(
          child: Text('Error: ${state.error}',
              style: const TextStyle(color: AppTheme.speedRed)));
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
      duration: const Duration(milliseconds: 200),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: state.entries.length,
        itemBuilder: (context, i) {
          final entry = state.entries[i];
          final isSelf = entry.uid == uid;
          final allTime = state.allTimeByUid[entry.uid] ?? entry;
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
      ),
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
