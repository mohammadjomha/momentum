import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/trip_model.dart';

class CameraOverlayPainter extends CustomPainter {
  final ui.Image photo;
  final List<RoutePoint> route;
  final double maxSpeed;
  final double avgSpeed;
  final double distanceKm;
  final String duration;
  final double smoothnessScore;
  final String smoothnessLabel;
  final String weatherLabel;
  final double tempC;
  final String date;
  final String username;

  const CameraOverlayPainter({
    required this.photo,
    required this.route,
    required this.maxSpeed,
    required this.avgSpeed,
    required this.distanceKm,
    required this.duration,
    required this.smoothnessScore,
    required this.smoothnessLabel,
    required this.weatherLabel,
    required this.tempC,
    required this.date,
    required this.username,
  });

  // Match share_trip_card.dart proportions exactly.
  static const double _topFraction = 0.78;
  static const double _midFraction = 0.11;
  // branding = 1 - top - mid = ~0.11

  static const double _leftFraction = 0.65;
  // right = 1 - left = 0.35

  static const double _routePadding = 24;
  static const double _statsLeftPadding = 16;
  static const double _markerRadius = 8;
  static const double _markerBorder = 2;

  @override
  void paint(Canvas canvas, Size size) {
    _drawPhotoCover(canvas, size);

    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.35);
    canvas.drawRect(Offset.zero & size, overlayPaint);

    final topH = size.height * _topFraction;
    final midH = size.height * _midFraction;
    final brandTop = topH + midH;
    final brandH = size.height - brandTop;

    final leftW = size.width * _leftFraction;
    final rightW = size.width - leftW;

    if (route.length >= 2) {
      _drawRoute(canvas, Rect.fromLTWH(0, 0, leftW, topH));
    }

    _drawStats(canvas, Rect.fromLTWH(leftW, 0, rightW, topH));
    _drawMidStrip(canvas, Rect.fromLTWH(0, topH, size.width, midH));
    _drawBranding(canvas, Rect.fromLTWH(0, brandTop, size.width, brandH));
  }

  void _drawPhotoCover(Canvas canvas, Size size) {
    final photoW = photo.width.toDouble();
    final photoH = photo.height.toDouble();
    if (photoW <= 0 || photoH <= 0) return;

    final scale = (size.width / photoW) > (size.height / photoH)
        ? size.width / photoW
        : size.height / photoH;

    final destW = photoW * scale;
    final destH = photoH * scale;
    final dx = (size.width - destW) / 2;
    final dy = (size.height - destH) / 2;

    final src = Rect.fromLTWH(0, 0, photoW, photoH);
    final dst = Rect.fromLTWH(dx, dy, destW, destH);
    canvas.drawImageRect(photo, src, dst, Paint());
  }

  void _drawRoute(Canvas canvas, Rect region) {
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

    final drawW = region.width - _routePadding * 2;
    final drawH = region.height - _routePadding * 2;
    final scale = (drawW / safeLngRange) < (drawH / safeLatRange)
        ? drawW / safeLngRange
        : drawH / safeLatRange;

    final projectedW = safeLngRange * scale;
    final projectedH = safeLatRange * scale;
    final offsetX = region.left + _routePadding + (drawW - projectedW) / 2;
    final offsetY = region.top + _routePadding + (drawH - projectedH) / 2;

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
      ..strokeWidth = 3
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

  void _drawStats(Canvas canvas, Rect region) {
    final stats = <_Stat>[
      _Stat(
        label: 'MAX SPEED',
        valueLine: '${maxSpeed.toStringAsFixed(0)} km/h',
      ),
      _Stat(
        label: 'AVG SPEED',
        valueLine: '${avgSpeed.toStringAsFixed(0)} km/h',
      ),
      _Stat(
        label: 'DISTANCE',
        valueLine: '${distanceKm.toStringAsFixed(2)} km',
      ),
      _Stat(label: 'DURATION', valueLine: duration),
    ];

    final blockHeight = region.height / stats.length;
    final left = region.left + _statsLeftPadding;
    final maxWidth = region.width - _statsLeftPadding;

    for (int i = 0; i < stats.length; i++) {
      final blockTop = region.top + blockHeight * i;
      final blockCenterY = blockTop + blockHeight / 2;
      _drawStatBlock(
        canvas,
        stats[i],
        left: left,
        centerY: blockCenterY,
        maxWidth: maxWidth,
      );
    }
  }

  void _drawStatBlock(
    Canvas canvas,
    _Stat stat, {
    required double left,
    required double centerY,
    required double maxWidth,
  }) {
    final labelPainter = TextPainter(
      text: TextSpan(
        text: stat.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    final valuePainter = TextPainter(
      text: TextSpan(
        text: stat.valueLine,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    const gap = 8.0;
    final totalH = labelPainter.height + gap + valuePainter.height;
    final startY = centerY - totalH / 2;

    labelPainter.paint(canvas, Offset(left, startY));
    valuePainter.paint(
      canvas,
      Offset(left, startY + labelPainter.height + gap),
    );
  }

  void _drawMidStrip(Canvas canvas, Rect region) {
    final hasWeather = weatherLabel.isNotEmpty;
    final hasSmoothness = smoothnessScore > 0.0;
    if (!hasWeather && !hasSmoothness) return;

    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    canvas.drawRect(region, bgPaint);

    final halfW = region.width / 2;
    final centerY = region.top + region.height / 2;

    if (hasWeather) {
      _drawWeatherBlock(
        canvas,
        center: Offset(region.left + halfW / 2, centerY),
        maxWidth: halfW - 32,
      );
    }

    if (hasSmoothness) {
      _drawSmoothnessBlock(
        canvas,
        center: Offset(region.left + halfW + halfW / 2, centerY),
        maxWidth: halfW - 32,
      );
    }
  }

  void _drawWeatherBlock(
    Canvas canvas, {
    required Offset center,
    required double maxWidth,
  }) {
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.wb_sunny_outlined.codePoint),
        style: const TextStyle(
          fontSize: 24,
          color: AppTheme.accent,
          fontFamily: 'MaterialIcons',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelPainter = TextPainter(
      text: TextSpan(
        text: weatherLabel,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    final tempPainter = TextPainter(
      text: TextSpan(
        text: '${tempC.toStringAsFixed(1)}°C',
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth);

    const iconGap = 4.0;
    const textGap = 2.0;
    final stackH = iconPainter.height +
        iconGap +
        labelPainter.height +
        textGap +
        tempPainter.height;
    final startY = center.dy - stackH / 2;

    iconPainter.paint(
      canvas,
      Offset(center.dx - iconPainter.width / 2, startY),
    );
    final labelY = startY + iconPainter.height + iconGap;
    labelPainter.paint(
      canvas,
      Offset(center.dx - labelPainter.width / 2, labelY),
    );
    tempPainter.paint(
      canvas,
      Offset(
        center.dx - tempPainter.width / 2,
        labelY + labelPainter.height + textGap,
      ),
    );
  }

  void _drawSmoothnessBlock(
    Canvas canvas, {
    required Offset center,
    required double maxWidth,
  }) {
    final scorePainter = TextPainter(
      text: TextSpan(
        text: smoothnessScore.toStringAsFixed(1),
        style: const TextStyle(
          color: AppTheme.accent,
          fontSize: 36,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth);

    final labelPainter = TextPainter(
      text: TextSpan(
        text: smoothnessLabel,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    const gap = 4.0;
    final stackH = scorePainter.height + gap + labelPainter.height;
    final startY = center.dy - stackH / 2;

    scorePainter.paint(
      canvas,
      Offset(center.dx - scorePainter.width / 2, startY),
    );
    labelPainter.paint(
      canvas,
      Offset(
        center.dx - labelPainter.width / 2,
        startY + scorePainter.height + gap,
      ),
    );
  }

  void _drawBranding(Canvas canvas, Rect region) {
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    canvas.drawRect(region, bgPaint);

    final centerY = region.top + region.height / 2;
    final third = region.width / 3;

    final brandPainter = TextPainter(
      text: const TextSpan(
        text: 'Momentum',
        style: TextStyle(
          color: AppTheme.accent,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
      maxLines: 1,
    )..layout();

    final datePainter = TextPainter(
      text: TextSpan(
        text: date,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: third);

    final userPainter = TextPainter(
      text: TextSpan(
        text: '@$username',
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: third);

    datePainter.paint(
      canvas,
      Offset(region.left + third / 2 - datePainter.width / 2,
          centerY - datePainter.height / 2),
    );
    userPainter.paint(
      canvas,
      Offset(
        region.left + region.width / 2 - userPainter.width / 2,
        centerY - userPainter.height / 2,
      ),
    );
    brandPainter.paint(
      canvas,
      Offset(
        region.left + region.width - third / 2 - brandPainter.width / 2,
        centerY - brandPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CameraOverlayPainter oldDelegate) {
    return oldDelegate.photo != photo ||
        oldDelegate.route != route ||
        oldDelegate.maxSpeed != maxSpeed ||
        oldDelegate.avgSpeed != avgSpeed ||
        oldDelegate.distanceKm != distanceKm ||
        oldDelegate.duration != duration ||
        oldDelegate.smoothnessScore != smoothnessScore ||
        oldDelegate.smoothnessLabel != smoothnessLabel ||
        oldDelegate.weatherLabel != weatherLabel ||
        oldDelegate.tempC != tempC ||
        oldDelegate.date != date ||
        oldDelegate.username != username;
  }
}

class _Stat {
  final String label;
  final String valueLine;
  const _Stat({required this.label, required this.valueLine});
}
