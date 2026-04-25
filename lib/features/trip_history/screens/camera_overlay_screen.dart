import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../models/trip_model.dart';
import '../widgets/camera_overlay_painter.dart';

enum ShareAction { saveToGallery, share }

class CameraOverlayScreen extends ConsumerStatefulWidget {
  final TripModel trip;
  final List<RoutePoint> route;

  const CameraOverlayScreen({
    super.key,
    required this.trip,
    required this.route,
  });

  @override
  ConsumerState<CameraOverlayScreen> createState() =>
      _CameraOverlayScreenState();
}

class _CameraOverlayScreenState extends ConsumerState<CameraOverlayScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  ui.Image? _image;
  bool _isProcessing = false;
  ShareAction? _activeAction;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureAndProcess());
  }

  Future<void> _captureAndProcess() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (!mounted) return;
      if (picked == null) {
        Navigator.of(context).pop();
        return;
      }
      final bytes = await picked.readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      if (!mounted) return;
      setState(() => _image = decoded);
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
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

  String _smoothnessLabel(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 60) return 'Average';
    return 'Needs Work';
  }

  Future<void> _exportAndAct(ShareAction action) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _activeAction = action;
    });

    try {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/momentum_overlay_${widget.trip.id}.png';
      final file = await File(filePath).writeAsBytes(bytes);

      if (action == ShareAction.saveToGallery) {
        await _saveToGallery(file.path, bytes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to gallery')),
        );
      } else {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'My trip on Momentum',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _activeAction = null;
        });
      }
    }
  }

  Future<void> _saveToGallery(String path, Uint8List bytes) async {
    await Gal.putImage(path);
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.accent,
          ),
        ),
      );
    }

    final username = widget.trip.username;
    final dateText = DateFormat('MMM d, yyyy').format(widget.trip.date);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            key: _boundaryKey,
            child: CustomPaint(
              painter: CameraOverlayPainter(
                photo: _image!,
                route: widget.route,
                maxSpeed: widget.trip.maxSpeed,
                avgSpeed: widget.trip.avgSpeed,
                distanceKm: widget.trip.distance,
                duration: _formatDuration(widget.trip.duration),
                smoothnessScore: widget.trip.smoothnessScore,
                smoothnessLabel:
                    _smoothnessLabel(widget.trip.smoothnessScore),
                weatherLabel: widget.trip.weatherLabel,
                tempC: widget.trip.weatherTempC,
                date: dateText,
                username: username,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    _CloseButton(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Save to Gallery',
                        filled: false,
                        loading: _isProcessing &&
                            _activeAction == ShareAction.saveToGallery,
                        enabled: !_isProcessing,
                        onPressed: () =>
                            _exportAndAct(ShareAction.saveToGallery),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        label: 'Share',
                        filled: true,
                        loading: _isProcessing &&
                            _activeAction == ShareAction.share,
                        enabled: !_isProcessing,
                        onPressed: () => _exportAndAct(ShareAction.share),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _CloseButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.close, color: AppTheme.textPrimary),
        iconSize: 22,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.filled,
    required this.loading,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: filled ? AppTheme.background : AppTheme.accent,
              strokeWidth: 2.5,
            ),
          )
        : Text(
            label,
            style: TextStyle(
              color: filled ? AppTheme.background : AppTheme.accent,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          );

    if (filled) {
      return SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            disabledBackgroundColor:
                AppTheme.accent.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: Center(child: child),
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.5),
          side: BorderSide(
            color: AppTheme.accent.withValues(alpha: 0.6),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}
