import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/club.dart';
import '../models/club_post.dart';
import '../providers/club_provider.dart';
import '../services/club_service.dart';

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.clubId,
    required this.club,
    this.isPinned = false,
  });

  final ClubPost post;
  final String clubId;
  final Club club;
  final bool isPinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMember = club.memberUids.contains(uid);
    final isOwner = club.ownerUid == uid;
    final isAdmin = club.adminUids.contains(uid);
    final isAuthor = post.authorUid == uid;
    final isPrivileged = isOwner || isAdmin;
    final isLiked = post.likedBy.contains(uid);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPinned
              ? AppTheme.accent.withValues(alpha: 0.35)
              : AppTheme.accent.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pin indicator
          if (isPinned) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  const Icon(Icons.push_pin_rounded,
                      color: AppTheme.accent, size: 14),
                  const SizedBox(width: 4),
                  const Text(
                    'Pinned',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFF2A2A2A)),
            ),
          ],

          // Image
          if (post.imageUrl != null)
            ClipRRect(
              borderRadius: isPinned
                  ? BorderRadius.zero
                  : const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                post.imageUrl!,
                width: double.infinity,
                height: 260,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        height: 260,
                        color: AppTheme.surfaceHigh,
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.accent, strokeWidth: 2),
                        ),
                      ),
                errorBuilder: (context, error, e) => Container(
                  height: 120,
                  color: AppTheme.surfaceHigh,
                  child: const Center(
                    child: Icon(Icons.broken_image_rounded,
                        color: AppTheme.textSecondary, size: 32),
                  ),
                ),
              ),
            ),

          // Header row: author + time + menu
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: post.authorUsername,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(
                          text: '  ·  ',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        TextSpan(
                          text: _relTime(post.createdAt),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (post.editedAt != null)
                          const TextSpan(
                            text: '  (edited)',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _MoreButton(
                  post: post,
                  clubId: clubId,
                  club: club,
                  uid: uid,
                  isAuthor: isAuthor,
                  isPrivileged: isPrivileged,
                  isMember: isMember,
                  isPinned: isPinned,
                ),
              ],
            ),
          ),

          // Body text
          if (post.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: SelectableText(
                post.body,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),

          // Action row
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              children: [
                _ActionButton(
                  icon: isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isLiked ? AppTheme.accent : AppTheme.textSecondary,
                  count: post.likeCount,
                  enabled: isMember,
                  onTap: () => clubService.toggleLike(
                      clubId, post.id, uid),
                ),
                const SizedBox(width: 16),
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: AppTheme.textSecondary,
                  count: post.commentCount,
                  enabled: isMember,
                  onTap: () => _openComments(context, ref, uid, isMember),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openComments(
      BuildContext context, WidgetRef ref, String uid, bool isMember) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => CommentsSheet(
        post: post,
        clubId: clubId,
        uid: uid,
        isMember: isMember,
      ),
    );
  }

  static String _relTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ---------------------------------------------------------------------------
// Three-dot menu button
// ---------------------------------------------------------------------------

class _MoreButton extends ConsumerWidget {
  const _MoreButton({
    required this.post,
    required this.clubId,
    required this.club,
    required this.uid,
    required this.isAuthor,
    required this.isPrivileged,
    required this.isMember,
    required this.isPinned,
  });

  final ClubPost post;
  final String clubId;
  final Club club;
  final String uid;
  final bool isAuthor;
  final bool isPrivileged;
  final bool isMember;
  final bool isPinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.more_vert_rounded,
          color: AppTheme.textSecondary, size: 20),
      splashRadius: 18,
      onPressed: () => _showMenu(context, ref),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
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
            // View comments — always
            _MenuTile(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'View comments',
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppTheme.surface,
                  shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => CommentsSheet(
                    post: post,
                    clubId: clubId,
                    uid: uid,
                    isMember: isMember,
                  ),
                );
              },
            ),

            if (isAuthor) ...[
              _MenuTile(
                icon: Icons.edit_outlined,
                label: 'Edit post',
                onTap: () {
                  Navigator.pop(context);
                  _openEditSheet(context, ref);
                },
              ),
              _MenuTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete post',
                color: AppTheme.speedRed,
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, ref, isAdmin: false);
                },
              ),
            ] else if (isPrivileged) ...[
              _MenuTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete post',
                color: AppTheme.speedRed,
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, ref, isAdmin: true);
                },
              ),
            ],

            if (isPrivileged)
              _MenuTile(
                icon: isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                label: isPinned ? 'Unpin post' : 'Pin post',
                onTap: () async {
                  Navigator.pop(context);
                  await clubService.pinPost(clubId, post.id, uid);
                },
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditPostSheet(post: post, clubId: clubId),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref,
      {required bool isAdmin}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Post',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('This post will be permanently deleted.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await clubService.deletePost(
                    clubId, post.id, uid, isAdmin);
              } catch (_) {}
            },
            child: const Text('DELETE',
                style: TextStyle(color: AppTheme.speedRed)),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textPrimary;
    return ListTile(
      leading: Icon(icon, color: c, size: 20),
      title: Text(label,
          style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Like/comment action button
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.count,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final int count;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit post sheet
// ---------------------------------------------------------------------------

class _EditPostSheet extends ConsumerStatefulWidget {
  const _EditPostSheet({required this.post, required this.clubId});

  final ClubPost post;
  final String clubId;

  @override
  ConsumerState<_EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends ConsumerState<_EditPostSheet> {
  late final TextEditingController _ctrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.post.body);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || text == widget.post.body) {
      Navigator.pop(context);
      return;
    }
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await clubService.editPost(widget.clubId, widget.post.id, text, uid);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: AppTheme.speedRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'EDIT POST',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: AppTheme.textSecondary, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              maxLines: 4,
              autofocus: true,
              cursorColor: AppTheme.accent,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
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
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.background,
                  disabledBackgroundColor:
                      AppTheme.accent.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: AppTheme.background, strokeWidth: 2),
                      )
                    : const Text('SAVE',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comments sheet
// ---------------------------------------------------------------------------

class CommentsSheet extends ConsumerStatefulWidget {
  const CommentsSheet({
    super.key,
    required this.post,
    required this.clubId,
    required this.uid,
    required this.isMember,
  });

  final ClubPost post;
  final String clubId;
  final String uid;
  final bool isMember;

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();
      final username =
          (userDoc.data()?['username'] as String?) ?? widget.uid;
      await clubService.addComment(
        widget.clubId,
        widget.post.id,
        widget.uid,
        username,
        text,
      );
      _ctrl.clear();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(
        clubCommentsProvider((widget.clubId, widget.post.id)));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'COMMENTS',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          Expanded(
            child: commentsAsync.when(
              loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.accent)),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style:
                          const TextStyle(color: AppTheme.speedRed))),
              data: (comments) {
                if (comments.isEmpty) {
                  return const Center(
                    child: Text('No comments yet.',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13)),
                  );
                }
                return ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  itemCount: comments.length,
                  itemBuilder: (_, i) {
                    final c = comments[i];
                    final isOwn = c.authorUid == widget.uid;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text.rich(TextSpan(children: [
                                  TextSpan(
                                    text: c.authorUsername,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        '  ${_relTime(c.createdAt)}',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ])),
                                const SizedBox(height: 4),
                                Text(c.text,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13,
                                      height: 1.4,
                                    )),
                              ],
                            ),
                          ),
                          if (isOwn)
                            GestureDetector(
                              onTap: () => _deleteComment(
                                  context, c.commentId),
                              child: const Icon(Icons.close_rounded,
                                  color: AppTheme.textSecondary,
                                  size: 16),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          if (widget.isMember) ...[
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  8 + MediaQuery.of(context).viewInsets.bottom +
                      MediaQuery.of(context).padding.bottom),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      cursorColor: AppTheme.accent,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Add a comment…',
                        hintStyle: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13),
                        filled: true,
                        fillColor: AppTheme.surfaceHigh,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: AppTheme.accent
                                  .withValues(alpha: 0.15)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppTheme.accent, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _send,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _sending
                          ? const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: AppTheme.background,
                                    strokeWidth: 2),
                              ),
                            )
                          : const Icon(Icons.send_rounded,
                              color: AppTheme.background, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _deleteComment(BuildContext context, String commentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Comment',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Remove this comment?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await clubService.deleteComment(
                  widget.clubId,
                  widget.post.id,
                  commentId,
                  widget.uid,
                );
              } catch (_) {}
            },
            child: const Text('DELETE',
                style: TextStyle(color: AppTheme.speedRed)),
          ),
        ],
      ),
    );
  }

  static String _relTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
