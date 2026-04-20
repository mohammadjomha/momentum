import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../services/friend_service.dart';

Future<void> showUserMiniCard(
  BuildContext context,
  WidgetRef ref, {
  required String currentUid,
  required String targetUid,
  required String username,
  required String? carModel,
  required int tripCount,
  required double totalDistance,
  required double avgSmoothness,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: _UserMiniCard(
        currentUid: currentUid,
        targetUid: targetUid,
        username: username,
        carModel: carModel,
        tripCount: tripCount,
        totalDistance: totalDistance,
        avgSmoothness: avgSmoothness,
      ),
    ),
  );
}


class _UserMiniCard extends ConsumerStatefulWidget {
  final String currentUid;
  final String targetUid;
  final String username;
  final String? carModel;
  final int tripCount;
  final double totalDistance;
  final double avgSmoothness;

  const _UserMiniCard({
    required this.currentUid,
    required this.targetUid,
    required this.username,
    required this.carModel,
    required this.tripCount,
    required this.totalDistance,
    required this.avgSmoothness,
  });

  @override
  ConsumerState<_UserMiniCard> createState() => _UserMiniCardState();
}

class _UserMiniCardState extends ConsumerState<_UserMiniCard> {
  RelationshipStatus? _status;
  String? _pendingRequestId;
  bool _loadingStatus = true;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await friendService.getRelationshipStatus(
      widget.currentUid,
      widget.targetUid,
    );
    if (!mounted) return;
    setState(() {
      _status = status;
      _loadingStatus = false;
    });
  }

  Future<void> _sendRequest() async {
    setState(() => _actionLoading = true);
    try {
      await friendService.sendFriendRequest(
        fromUid: widget.currentUid,
        fromUsername: '',
        toUid: widget.targetUid,
        toUsername: widget.username,
      );
      if (!mounted) return;
      setState(() {
        _status = RelationshipStatus.pendingSent;
        _actionLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _acceptRequest() async {
    setState(() => _actionLoading = true);
    try {
      final requestId = _pendingRequestId ??
          await friendService.getPendingRequestId(
            widget.targetUid,
            widget.currentUid,
          );
      if (requestId == null) {
        if (mounted) setState(() => _actionLoading = false);
        return;
      }
      await friendService.acceptRequest(
        requestId,
        widget.targetUid,
        widget.currentUid,
      );
      if (!mounted) return;
      setState(() {
        _status = RelationshipStatus.friends;
        _actionLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _rejectRequest() async {
    setState(() => _actionLoading = true);
    try {
      final requestId = _pendingRequestId ??
          await friendService.getPendingRequestId(
            widget.targetUid,
            widget.currentUid,
          );
      if (requestId == null) {
        if (mounted) setState(() => _actionLoading = false);
        return;
      }
      await friendService.rejectRequest(requestId);
      if (!mounted) return;
      setState(() {
        _status = RelationshipStatus.none;
        _actionLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Username + car
          Text(
            widget.username,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          if (widget.carModel != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.carModel!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                _StatCell(
                  label: 'TRIPS',
                  value: widget.tripCount.toString(),
                ),
                _Divider(),
                _StatCell(
                  label: 'DISTANCE',
                  value: '${widget.totalDistance.toStringAsFixed(1)} km',
                ),
                _Divider(),
                _StatCell(
                  label: 'AVG SMOOTH',
                  value: widget.avgSmoothness.toStringAsFixed(1),
                  accent: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Friend action button
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    if (_loadingStatus) {
      return _DisabledButton(label: 'LOADING...');
    }

    switch (_status) {
      case RelationshipStatus.none:
      case null:
        return _TealButton(
          label: 'ADD FRIEND',
          loading: _actionLoading,
          onTap: _sendRequest,
        );

      case RelationshipStatus.pendingSent:
        return _DisabledButton(label: 'REQUEST SENT');

      case RelationshipStatus.pendingReceived:
        return Row(
          children: [
            Expanded(
              child: _TealButton(
                label: 'ACCEPT',
                loading: _actionLoading,
                onTap: _acceptRequest,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OutlineButton(
                label: 'REJECT',
                loading: _actionLoading,
                onTap: _rejectRequest,
              ),
            ),
          ],
        );

      case RelationshipStatus.friends:
        return _DisabledButton(label: 'ALREADY FRIENDS');
    }
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;

  const _StatCell({
    required this.label,
    required this.value,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: accent ? AppTheme.accent : AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppTheme.accent.withValues(alpha: 0.12),
    );
  }
}

class _TealButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _TealButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accent,
          disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.background,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: AppTheme.background,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: loading ? null : onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: AppTheme.textSecondary.withValues(alpha: 0.4),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.textSecondary,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }
}

class _DisabledButton extends StatelessWidget {
  final String label;

  const _DisabledButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: AppTheme.surfaceHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: AppTheme.textSecondary.withValues(alpha: 0.2),
            ),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}