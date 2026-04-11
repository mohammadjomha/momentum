import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SpeedometerWidget extends StatelessWidget {
  final double speed;
  final double maxSpeed;
  final bool isTracking;

  const SpeedometerWidget({
    super.key,
    required this.speed,
    this.maxSpeed = 240.0,
    this.isTracking = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        if (size <= 0) return const SizedBox.shrink();

        final fontSize = (size * 0.26).clamp(28.0, 84.0);
        final labelSize = (size * 0.045).clamp(9.0, 14.0);
        final statusSize = (size * 0.038).clamp(8.0, 12.0);
        // Frosted glass circle: just inside the arc stroke radius
        final arcRadius = size / 2 - 20;
        final glassRadius = arcRadius - 18.0;

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Arc painter (track + progress)
              CustomPaint(
                size: Size(size, size),
                painter: _SpeedometerPainter(
                  speed: speed,
                  maxSpeed: maxSpeed,
                ),
              ),
              // Frosted glass center circle
              Container(
                width: glassRadius * 2,
                height: glassRadius * 2,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHigh.withValues(alpha: 0.60),
                  shape: BoxShape.circle,
                ),
              ),
              // Speed number + labels stacked in center
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    speed.toInt().toString(),
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'KM/H',
                    style: TextStyle(
                      fontSize: labelSize,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.silver,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Status indicator inside the speedometer
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isTracking ? AppTheme.speedRed : AppTheme.accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isTracking ? AppTheme.speedRed : AppTheme.accent)
                                  .withValues(alpha: 0.7),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isTracking ? 'TRACKING' : 'READY',
                        style: TextStyle(
                          fontSize: statusSize,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.silver,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  final double speed;
  final double maxSpeed;

  _SpeedometerPainter({
    required this.speed,
    required this.maxSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    _drawBackgroundArc(canvas, center, radius);
    _drawSpeedArc(canvas, center, radius);
  }

  void _drawBackgroundArc(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = AppTheme.surface.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt;

    const startAngle = pi * 0.6;
    const sweepAngle = pi * 1.8;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  void _drawSpeedArc(Canvas canvas, Offset center, double radius) {
    final speedRatio = (speed / maxSpeed).clamp(0.0, 1.0);
    if (speedRatio <= 0) return;

    const startAngle = pi * 0.6;
    const arcSpan = pi * 1.8;
    final sweepAngle = arcSpan * speedRatio;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Anchor the gradient at 0 → arcSpan to avoid the 2π wrap-around bug:
    // startAngle (≈1.88) + arcSpan (≈5.65) ≈ 7.53 > 2π, which corrupts
    // Flutter's sweep gradient. We rotate the canvas by startAngle so the
    // arc draws at world-angle startAngle while the gradient stays in 0..arcSpan.
    final gradient = ui.Gradient.sweep(
      center,
      const [
        AppTheme.speedGreen,
        AppTheme.speedYellow,
        AppTheme.speedRed,
      ],
      [0.0, 0.55, 1.0],
      TileMode.clamp,
      0,
      arcSpan,
    );

    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(startAngle);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(rect, 0, sweepAngle, false, paint);
    canvas.restore();

    // Draw rounded caps as circles so we get the rounded look without
    // the StrokeCap.round overshoot that caused the colour artifacts.
    final strokeHalfWidth = 9.0;
    final capRadius = strokeHalfWidth;

    // Start cap — always speedGreen
    final startCapPos = Offset(
      center.dx + radius * cos(startAngle),
      center.dy + radius * sin(startAngle),
    );
    canvas.drawCircle(startCapPos, capRadius, Paint()..color = AppTheme.speedGreen);

    // End cap — sample the gradient colour at the current speedRatio
    final endAngle = startAngle + sweepAngle;
    final endCapPos = Offset(
      center.dx + radius * cos(endAngle),
      center.dy + radius * sin(endAngle),
    );
    final Color endColor = _gradientColorAt(speedRatio);
    canvas.drawCircle(endCapPos, capRadius, Paint()..color = endColor);
  }

  /// Returns the gradient colour at [t] (0.0 – 1.0) matching the three stops.
  Color _gradientColorAt(double t) {
    if (t <= 0.55) {
      final local = t / 0.55;
      return Color.lerp(AppTheme.speedGreen, AppTheme.speedYellow, local)!;
    } else {
      final local = (t - 0.55) / 0.45;
      return Color.lerp(AppTheme.speedYellow, AppTheme.speedRed, local)!;
    }
  }

  @override
  bool shouldRepaint(_SpeedometerPainter oldDelegate) {
    return oldDelegate.speed != speed || oldDelegate.maxSpeed != maxSpeed;
  }
}
