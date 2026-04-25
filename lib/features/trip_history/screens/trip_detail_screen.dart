import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/weather_utils.dart';
import '../../../features/leaderboard/providers/leaderboard_provider.dart';
import '../models/trip_model.dart';
import '../services/coaching_service.dart';
import '../services/trip_history_service.dart';
import '../widgets/share_trip_card.dart';
import 'camera_overlay_screen.dart';

class TripDetailScreen extends ConsumerStatefulWidget {
  final TripModel trip;
  const TripDetailScreen({super.key, required this.trip});

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  final GlobalKey _shareBoundaryKey = GlobalKey();
  bool _isSharing = false;
  bool _isDeleting = false;
  String? _coachingNote;
  bool _coachingLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCoaching();
  }

  Future<void> _loadCoaching() async {
    if (widget.trip.coachingNote != null) {
      setState(() => _coachingNote = widget.trip.coachingNote);
      return;
    }
    setState(() => _coachingLoading = true);
    try {
      final note =
          await CoachingService.generateAndStoreCoachingNote(widget.trip);
      if (mounted) setState(() => _coachingNote = note);
    } catch (_) {
      if (mounted) {
        setState(() => _coachingNote =
            'Unable to generate coaching note. Please try again later.');
      }
    } finally {
      if (mounted) setState(() => _coachingLoading = false);
    }
  }

  Future<void> _deleteTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        title: const Text(
          'Delete Trip',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'This trip will be permanently deleted.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.accent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await TripHistoryService()
          .deleteTrip(widget.trip.id, widget.trip.distance);
      ref.read(leaderboardProvider.notifier).forceRefresh();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip deleted')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete trip.')),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  void _showShareOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: AppTheme.accent),
              title: const Text(
                'Share Card',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Classic Momentum share card',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _shareTrip();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.accent),
              title: const Text(
                'Camera Overlay',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Take a photo with your trip overlaid',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CameraOverlayScreen(
                      trip: widget.trip,
                      route: widget.trip.route,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _shareTrip() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final boundary = _shareBoundaryKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/momentum_trip_${widget.trip.id}.png';
      final file = await File(filePath).writeAsBytes(bytes);

      try {
        final result = await Share.shareXFiles(
          [XFile(file.path)],
          text: 'My trip on Momentum',
        );
        // result comes back on both platforms after sheet interaction
        debugPrint('Share result: ${result.status}');
      } catch (e) {
        debugPrint('Share error: $e');
      } finally {
        if (mounted) setState(() => _isSharing = false);
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.trip.route
        .map((p) => LatLng(p.lat, p.lng))
        .toList();

    final hasRoute = points.length >= 2;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Positioned(
            left: -10000,
            top: -10000,
            child: RepaintBoundary(
              key: _shareBoundaryKey,
              child: MediaQuery(
                data: const MediaQueryData(),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Material(
                    color: AppTheme.background,
                    child: ShareTripCard(trip: widget.trip),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  trip: widget.trip,
                  isDeleting: _isDeleting,
                  onDelete: _deleteTrip,
                ),
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
                            trip: widget.trip,
                            formatDuration: _formatDuration),
                      ),
                      if (widget.trip.smoothnessScore > 0.0) ...[
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        SliverToBoxAdapter(
                            child: _SmoothnessCard(trip: widget.trip)),
                      ],
                      if (widget.trip.weatherLabel.isNotEmpty) ...[
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        SliverToBoxAdapter(
                            child: _WeatherCard(trip: widget.trip)),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverToBoxAdapter(
                          child: _BrakingCard(trip: widget.trip)),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverToBoxAdapter(
                          child: _AccelCard(trip: widget.trip)),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverToBoxAdapter(
                        child: _CoachingCard(
                          loading: _coachingLoading,
                          note: _coachingNote,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      SliverToBoxAdapter(
                        child: _ShareButton(
                          isSharing: _isSharing,
                          onPressed: _shareTrip,
                          onShowShareOptions: () => _showShareOptions(context),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final bool isSharing;
  final VoidCallback onPressed;
  final VoidCallback onShowShareOptions;
  const _ShareButton({
    required this.isSharing,
    required this.onPressed,
    required this.onShowShareOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: isSharing
            ? const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: AppTheme.accent,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            : OutlinedButton.icon(
                onPressed: onShowShareOptions,
                icon: const Icon(Icons.share, color: AppTheme.accent),
                label: const Text(
                  'Share Trip',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppTheme.accent.withValues(alpha: 0.6),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final TripModel trip;
  final bool isDeleting;
  final VoidCallback onDelete;
  const _TopBar({
    required this.trip,
    required this.isDeleting,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
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
            const Spacer(),
            if (isDeleting)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppTheme.textSecondary,
                  strokeWidth: 2,
                ),
              )
            else
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: AppTheme.textSecondary,
                iconSize: 22,
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
                label: 'TOTAL BRAKES',
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
                label: 'QUICK ACCELS',
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

class _SmoothnessCard extends StatelessWidget {
  final TripModel trip;
  const _SmoothnessCard({required this.trip});

  String _descriptor(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 60) return 'Average';
    return 'Needs Work';
  }

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
            'SMOOTHNESS SCORE',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                trip.smoothnessScore.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  _descriptor(trip.smoothnessScore),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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

const _kNoSensorMessage =
    'Sensor data unavailable for this trip. Record a new trip to receive AI coaching.';

class _CoachingCard extends StatelessWidget {
  final bool loading;
  final String? note;
  const _CoachingCard({required this.loading, required this.note});

  @override
  Widget build(BuildContext context) {
    final isNoSensor = note == _kNoSensorMessage;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: _sensorCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isNoSensor
                    ? Icons.sensors_off_outlined
                    : Icons.psychology_outlined,
                color: AppTheme.accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'AI COACHING',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: AppTheme.accent,
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Analyzing your drive…',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            )
          else
            Text(
              note ?? '',
              style: TextStyle(
                color: isNoSensor
                    ? AppTheme.textSecondary
                    : AppTheme.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  final TripModel trip;
  const _WeatherCard({required this.trip});

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
            'WEATHER',
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
              Icon(
                weatherIcon(trip.weatherCode),
                color: AppTheme.accent,
                size: 36,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.weatherLabel,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${trip.weatherTempC.toStringAsFixed(1)}°C',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (trip.weatherMultiplier > 1.0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '×${trip.weatherMultiplier.toStringAsFixed(2)} smoothness bonus',
                        style: const TextStyle(
                          color: AppTheme.silver,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}