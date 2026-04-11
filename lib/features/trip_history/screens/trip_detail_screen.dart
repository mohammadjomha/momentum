import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../models/trip_model.dart';

class TripDetailScreen extends StatelessWidget {
  final TripModel trip;
  const TripDetailScreen({super.key, required this.trip});

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final points = trip.route
        .map((p) => LatLng(p.lat, p.lng))
        .toList();

    final hasRoute = points.length >= 2;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(trip: trip),
            Expanded(
              flex: 3,
              child: hasRoute
                  ? _RouteMap(points: points)
                  : const _NoRouteCard(),
            ),
            _StatsPanel(trip: trip, formatDuration: _formatDuration),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final TripModel trip;
  const _TopBar({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: AppTheme.textPrimary,
            iconSize: 18,
          ),
          const Text(
            'TRIP DETAIL',
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

// ── Route map ─────────────────────────────────────────────────────────────────

class _RouteMap extends StatelessWidget {
  final List<LatLng> points;
  const _RouteMap({required this.points});

  LatLngBounds _bounds() {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      LatLng(minLat - 0.001, minLng - 0.001),
      LatLng(maxLat + 0.001, maxLng + 0.001),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: _bounds(),
            padding: const EdgeInsets.all(40),
          ),
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.momentum.app',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                strokeWidth: 3.5,
                color: AppTheme.routeLine,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              // Start marker — green circle
              Marker(
                point: points.first,
                width: 16,
                height: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.speedGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.textPrimary, width: 2),
                  ),
                ),
              ),
              // End marker — white circle
              Marker(
                point: points.last,
                width: 16,
                height: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.textPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accent, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── No route fallback ─────────────────────────────────────────────────────────

class _NoRouteCard extends StatelessWidget {
  const _NoRouteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, color: AppTheme.textSecondary, size: 36),
            SizedBox(height: 12),
            Text(
              'No route data for this trip.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats panel ───────────────────────────────────────────────────────────────

class _StatsPanel extends StatelessWidget {
  final TripModel trip;
  final String Function(Duration) formatDuration;
  const _StatsPanel({required this.trip, required this.formatDuration});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.20),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          _Stat(
            label: 'MAX SPEED',
            value: trip.maxSpeed.toStringAsFixed(0),
            unit: 'km/h',
          ),
          _Divider(),
          _Stat(
            label: 'AVG SPEED',
            value: trip.avgSpeed.toStringAsFixed(0),
            unit: 'km/h',
          ),
          _Divider(),
          _Stat(
            label: 'DISTANCE',
            value: trip.distance.toStringAsFixed(2),
            unit: 'km',
          ),
          _Divider(),
          _Stat(
            label: 'DURATION',
            value: formatDuration(trip.duration),
            unit: '',
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _Stat({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.silver,
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
            textAlign: TextAlign.center,
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 9,
                letterSpacing: 0.4,
              ),
              textAlign: TextAlign.center,
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
      height: 40,
      color: AppTheme.accent.withValues(alpha: 0.15),
    );
  }
}
