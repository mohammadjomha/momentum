import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/trip_data.dart';
import '../../../presentation/widgets/speedometer_widget.dart';
import '../providers/tracking_provider.dart';

class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackingProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 16),
              _StatusBar(state: state),
              if (state.error != null) ...[
                const SizedBox(height: 10),
                _ErrorBanner(message: state.error!),
              ],
              const SizedBox(height: 8),
              Expanded(
                flex: 5,
                child: _AnimatedSpeedometer(
                  speed: state.tripData.currentSpeed,
                  isTracking: state.isTracking,
                ),
              ),
              const SizedBox(height: 8),
              _StatsRow(tripData: state.tripData),
              const SizedBox(height: 20),
              _ControlButton(state: state, ref: ref),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status bar ────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  final TrackingState state;
  const _StatusBar({required this.state});

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // App title / brand mark on the left
        const Text(
          'MOMENTUM',
          style: TextStyle(
            color: AppTheme.accent,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
        const Spacer(),
        if (state.isTracking)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
            ),
            child: Text(
              _formatDuration(state.tripData.duration),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.speedRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.speedRed.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.speedRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.speedRed, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated speedometer ──────────────────────────────────────────────────────

class _AnimatedSpeedometer extends StatefulWidget {
  final double speed;
  final bool isTracking;
  const _AnimatedSpeedometer({required this.speed, required this.isTracking});

  @override
  State<_AnimatedSpeedometer> createState() => _AnimatedSpeedometerState();
}

class _AnimatedSpeedometerState extends State<_AnimatedSpeedometer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _displayedSpeed = 0.0;
  double _targetSpeed = 0.0;

  @override
  void initState() {
    super.initState();
    _targetSpeed = widget.speed;
    _displayedSpeed = widget.speed;

    // Runs continuously at ~60 fps; each tick lerps displayedSpeed toward target.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _controller.addListener(_onTick);
  }

  void _onTick() {
    final next = _displayedSpeed + (_targetSpeed - _displayedSpeed) * 0.15;
    // Stop updating once close enough to avoid endless micro-rebuilds.
    if ((next - _displayedSpeed).abs() < 0.01) return;
    setState(() => _displayedSpeed = next);
  }

  @override
  void didUpdateWidget(_AnimatedSpeedometer old) {
    super.didUpdateWidget(old);
    _targetSpeed = widget.speed;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth.clamp(0.0, constraints.maxHeight);
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: SpeedometerWidget(
              speed: _displayedSpeed,
              maxSpeed: 240,
              isTracking: widget.isTracking,
            ),
          ),
        );
      },
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final TripData tripData;
  const _StatsRow({required this.tripData});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'DIST', value: tripData.distance.toStringAsFixed(2), unit: 'km')),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'DUR', value: _fmtMin(tripData.duration), unit: 'min')),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'AVG', value: tripData.averageSpeed.toStringAsFixed(0), unit: 'km/h')),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'MAX', value: tripData.maxSpeed.toStringAsFixed(0), unit: 'km/h')),
      ],
    );
  }

  String _fmtMin(Duration d) => d.inMinutes.toString();
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _StatCard({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.06),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.silver,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Text(
              value,
              key: ValueKey(value),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            unit,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Control button ────────────────────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  final TrackingState state;
  final WidgetRef ref;
  const _ControlButton({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isTracking = state.isTracking;
    final glowColor = isTracking ? AppTheme.speedRed : AppTheme.accent;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Soft glow beneath button
        Container(
          width: double.infinity,
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.30),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: () {
              if (isTracking) {
                ref.read(trackingProvider.notifier).stopTracking();
              } else {
                ref.read(trackingProvider.notifier).startTracking();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isTracking ? AppTheme.speedRed : AppTheme.accent,
              foregroundColor: isTracking ? AppTheme.textPrimary : AppTheme.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(
              isTracking ? 'STOP' : 'START',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
