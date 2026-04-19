import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/trip_model.dart';

class ShareCardPainter extends CustomPainter {
  final List<RoutePoint> route;
  const ShareCardPainter(this.route);

  static const double _padding = 48;
  static const double _markerRadius = 12;
  static const double _markerBorder = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = AppTheme.background;
    canvas.drawRect(Offset.zero & size, bg);

    if (route.length < 2) return;

    double minLat = route.first.lat;
    double maxLat = route.first.lat;
    double minLng = route.first.lng;
    double maxLng = route.first.lng;
    for (final p in route) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }

    final latRange = (maxLat - minLat).abs();
    final lngRange = (maxLng - minLng).abs();
    final safeLatRange = latRange < 1e-9 ? 1e-9 : latRange;
    final safeLngRange = lngRange < 1e-9 ? 1e-9 : lngRange;

    final drawW = size.width - _padding * 2;
    final drawH = size.height - _padding * 2;
    final scale = (drawW / safeLngRange) < (drawH / safeLatRange)
        ? drawW / safeLngRange
        : drawH / safeLatRange;

    final projectedW = safeLngRange * scale;
    final projectedH = safeLatRange * scale;
    final offsetX = _padding + (drawW - projectedW) / 2;
    final offsetY = _padding + (drawH - projectedH) / 2;

    Offset project(RoutePoint p) {
      final x = offsetX + (p.lng - minLng) * scale;
      final y = offsetY + (maxLat - p.lat) * scale;
      return Offset(x, y);
    }

    final path = Path();
    final first = project(route.first);
    path.moveTo(first.dx, first.dy);
    for (int i = 1; i < route.length; i++) {
      final pt = project(route[i]);
      path.lineTo(pt.dx, pt.dy);
    }

    final linePaint = Paint()
      ..color = AppTheme.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    _drawMarker(
      canvas,
      project(route.first),
      fill: AppTheme.speedGreen,
      border: Colors.white,
    );
    _drawMarker(
      canvas,
      project(route.last),
      fill: Colors.white,
      border: AppTheme.accent,
    );
  }

  void _drawMarker(
    Canvas canvas,
    Offset center, {
    required Color fill,
    required Color border,
  }) {
    canvas.drawCircle(center, _markerRadius, Paint()..color = fill);
    canvas.drawCircle(
      center,
      _markerRadius,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = _markerBorder,
    );
  }

  @override
  bool shouldRepaint(covariant ShareCardPainter oldDelegate) =>
      oldDelegate.route != route;
}