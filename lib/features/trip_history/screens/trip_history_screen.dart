import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/trip_model.dart';
import '../providers/trip_history_provider.dart';
import 'trip_detail_screen.dart';

class TripHistoryScreen extends ConsumerWidget {
  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripHistoryProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(),
            Expanded(
              child: tripsAsync.when(
                data: (trips) => trips.isEmpty
                    ? const _EmptyState()
                    : _TripList(trips: trips),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Failed to load trips.',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          const Text(
            'HISTORY',
            style: TextStyle(
              color: AppTheme.accent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.route_outlined,
              color: AppTheme.accent,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No drives yet.',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hit the road.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trip list ─────────────────────────────────────────────────────────────────

class _TripList extends StatelessWidget {
  final List<TripModel> trips;
  const _TripList({required this.trips});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: trips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _TripCard(
        trip: trips[i],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TripDetailScreen(trip: trips[i]),
          ),
        ),
      ),
    );
  }
}

// ── Trip card ─────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback onTap;
  const _TripCard({required this.trip, required this.onTap});

  String _formatDate(DateTime d) =>
      DateFormat('EEE, MMM d · HH:mm').format(d);

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.accent.withValues(alpha: 0.20),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.07),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date row
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(trip.date),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Stats row
            Row(
              children: [
                _CardStat(
                  label: 'DISTANCE',
                  value: trip.distance.toStringAsFixed(2),
                  unit: 'km',
                ),
                _CardStat(
                  label: 'DURATION',
                  value: _formatDuration(trip.duration),
                  unit: '',
                ),
                _CardStat(
                  label: 'MAX',
                  value: trip.maxSpeed.toStringAsFixed(0),
                  unit: 'km/h',
                ),
                _CardStat(
                  label: 'AVG',
                  value: trip.avgSpeed.toStringAsFixed(0),
                  unit: 'km/h',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _CardStat({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.silver,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: unit.isNotEmpty
                  ? AppTheme.textSecondary
                  : Colors.transparent,
              fontSize: 9,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
