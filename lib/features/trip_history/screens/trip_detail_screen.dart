import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 500,
                      child: hasRoute
                          ? _RouteMap(points: points)
                          : const _NoRouteCard(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _StatsPanel(
                        trip: trip, formatDuration: _formatDuration),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: _BrakingCard(trip: trip)),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: _AccelCard(trip: trip)),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
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
    return Container(
      color: AppTheme.background,
      child: Padding(
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
      ),
    );
  }
}

// ── Route map ─────────────────────────────────────────────────────────────────

// Google Maps dark style — dark grey/black background, white labels.
const _kDarkMapStyle = '''[
  {"elementType":"geometry","stylers":[{"color":"#212121"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#ffffff"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},
  {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#181818"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
  {"featureType":"poi.park","elementType":"labels.text.stroke","stylers":[{"color":"#1b1b1b"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
  {"featureType":"road.highway.controlled_access","elementType":"geometry","stylers":[{"color":"#4e4e4e"}]},
  {"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
  {"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}
]''';

class _RouteMap extends StatefulWidget {
  final List<LatLng> points;
  const _RouteMap({required this.points});

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  GoogleMapController? _controller;
  BitmapDescriptor? _startIcon;
  BitmapDescriptor? _endIcon;

  @override
  void initState() {
    super.initState();
    _initMarkerIcons();
  }

  Future<void> _initMarkerIcons() async {
    final start = await _buildCircleMarker(
      fillColor: AppTheme.speedGreen,
      borderColor: Colors.white,
    );
    final end = await _buildCircleMarker(
      fillColor: Colors.white,
      borderColor: AppTheme.accent,
    );
    if (mounted) {
      setState(() {
        _startIcon = start;
        _endIcon = end;
      });
    }
  }

  /// Draws a filled circle with a border onto a Canvas and returns a
  /// BitmapDescriptor suitable for use as a Google Maps marker icon.
  Future<BitmapDescriptor> _buildCircleMarker({
    required Color fillColor,
    required Color borderColor,
  }) async {
    const double radius = 12;
    const double borderWidth = 2;
    const double size = (radius + borderWidth) * 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = const Offset(size / 2, size / 2);

    // Fill
    canvas.drawCircle(center, radius, Paint()..color = fillColor);
    // Border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.bytes(bytes);
  }

  LatLngBounds _bounds() {
    double minLat = widget.points.first.latitude;
    double maxLat = widget.points.first.latitude;
    double minLng = widget.points.first.longitude;
    double maxLng = widget.points.first.longitude;
    for (final p in widget.points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat - 0.001, minLng - 0.001),
      northeast: LatLng(maxLat + 0.001, maxLng + 0.001),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    _controller!.animateCamera(
      CameraUpdate.newLatLngBounds(_bounds(), 40),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _bounds();
    final midLat = (bounds.southwest.latitude + bounds.northeast.latitude) / 2;
    final midLng = (bounds.southwest.longitude + bounds.northeast.longitude) / 2;

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
      child: GoogleMap(
        mapType: MapType.normal,
        style: _kDarkMapStyle,
        initialCameraPosition: CameraPosition(
          target: LatLng(midLat, midLng),
          zoom: 14,
        ),
        onMapCreated: _onMapCreated,
        // Disable all interaction — static display only
        zoomControlsEnabled: false,
        zoomGesturesEnabled: false,
        scrollGesturesEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        myLocationButtonEnabled: false,
        compassEnabled: false,
        mapToolbarEnabled: false,
        polylines: {
          Polyline(
            polylineId: const PolylineId('route'),
            points: widget.points,
            color: AppTheme.routeLine,
            width: 4,
          ),
        },
        markers: (_startIcon == null || _endIcon == null)
            ? {}
            : {
                // Start marker — speedGreen fill, white border
                Marker(
                  markerId: const MarkerId('start'),
                  position: widget.points.first,
                  icon: _startIcon!,
                  anchor: const Offset(0.5, 0.5),
                ),
                // End marker — white fill, accent teal border
                Marker(
                  markerId: const MarkerId('end'),
                  position: widget.points.last,
                  icon: _endIcon!,
                  anchor: const Offset(0.5, 0.5),
                ),
              },
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
          Text(
            unit,
            style: TextStyle(
              color: unit.isNotEmpty
                  ? AppTheme.textSecondary
                  : Colors.transparent,
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

// ── Sensor cards ──────────────────────────────────────────────────────────────

BoxDecoration _sensorCardDecoration() => BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: AppTheme.accent.withValues(alpha: 0.15),
      ),
    );

class _SensorStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _SensorStat({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            unit.isNotEmpty ? unit : ' ',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BrakingCard extends StatelessWidget {
  final TripModel trip;
  const _BrakingCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: _sensorCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BRAKING',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SensorStat(
                label: 'HARD BRAKES',
                value: '${trip.hardBrakeCount}',
                unit: '',
              ),
              _SensorStat(
                label: 'PEAK BRAKE',
                value: trip.peakBrakeG.toStringAsFixed(2),
                unit: 'G',
              ),
              _SensorStat(
                label: 'AVG BRAKE',
                value: trip.avgBrakeG.toStringAsFixed(2),
                unit: 'G',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccelCard extends StatelessWidget {
  final TripModel trip;
  const _AccelCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: _sensorCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACCELERATION',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SensorStat(
                label: 'HARD ACCELS',
                value: '${trip.hardAccelCount}',
                unit: '',
              ),
              _SensorStat(
                label: 'PEAK ACCEL',
                value: trip.peakAccelG.toStringAsFixed(2),
                unit: 'G',
              ),
              _SensorStat(
                label: 'AVG ACCEL',
                value: trip.avgAccelG.toStringAsFixed(2),
                unit: 'G',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
