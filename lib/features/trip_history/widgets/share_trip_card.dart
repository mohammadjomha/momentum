import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/weather_utils.dart';
import '../models/trip_model.dart';
import 'share_card_painter.dart';

class ShareTripCard extends StatelessWidget {
  final TripModel trip;
  const ShareTripCard({super.key, required this.trip});

  static const double _cardWidth = 1080;
  static const double _cardHeight = 1920;

  static const double _topFraction = 0.78;
  static const double _midFraction = 0.11;
  // branding strip takes remaining ~0.11

  static const double _leftFraction = 0.65;
  static const double _rightFraction = 0.35;

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _descriptor(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 60) return 'Average';
    return 'Needs Work';
  }

  @override
  Widget build(BuildContext context) {
    final hasRoute = trip.route.length >= 2;
    final hasWeather = trip.weatherLabel.isNotEmpty;
    final hasSmoothness = trip.smoothnessScore > 0.0;
    final dateText = DateFormat('MMM d, yyyy').format(trip.date);

    final topH = _cardHeight * _topFraction;
    final midH = _cardHeight * _midFraction;
    final brandH = _cardHeight - topH - midH;

    final leftW = _cardWidth * _leftFraction;
    final rightW = _cardWidth * _rightFraction;

    return SizedBox(
      width: _cardWidth,
      height: _cardHeight,
      child: Container(
        color: AppTheme.background,
        child: Column(
          children: [
            // ── Top section: route map + stats ──────────────────────────
            SizedBox(
              width: _cardWidth,
              height: topH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left: route map
                  SizedBox(
                    width: leftW,
                    child: Stack(
                      children: [
                        if (hasRoute)
                          CustomPaint(
                            painter: ShareCardPainter(trip.route),
                            size: Size(leftW, topH),
                          )
                        else
                          Center(
                            child: Icon(
                              Icons.route,
                              color: AppTheme.accent,
                              size: 80,
                            ),
                          ),
                        // 1px teal right border
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 1,
                            color: AppTheme.background,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right: four stat blocks
                  SizedBox(
                    width: rightW,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatBlock(
                            label: 'MAX SPEED',
                            value: trip.maxSpeed.toStringAsFixed(0),
                            unit: 'km/h',
                          ),
                          _HDivider(),
                          _StatBlock(
                            label: 'AVG SPEED',
                            value: trip.avgSpeed.toStringAsFixed(0),
                            unit: 'km/h',
                          ),
                          _HDivider(),
                          _StatBlock(
                            label: 'DISTANCE',
                            value: trip.distance.toStringAsFixed(2),
                            unit: 'km',
                          ),
                          _HDivider(),
                          _StatBlock(
                            label: 'DURATION',
                            value: _formatDuration(trip.duration),
                            unit: null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Middle section: weather + smoothness ────────────────────
            Container(
              width: _cardWidth,
              height: midH,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.background, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: hasWeather
                        ? _WeatherBlock(trip: trip)
                        : const SizedBox.shrink(),
                  ),
                  Container(
                    width: 1,
                    color: AppTheme.background,
                  ),
                  Expanded(
                    child: hasSmoothness
                        ? _SmoothnessBlock(
                            score: trip.smoothnessScore,
                            descriptor: _descriptor(trip.smoothnessScore),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // ── Branding strip ──────────────────────────────────────────
            Container(
              width: _cardWidth,
              height: brandH,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.background, width: 1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dateText,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '@${trip.username}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Momentum',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  const _StatBlock({required this.label, required this.value, this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 22,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 44,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        if (unit != null)
          Text(
            unit!,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
            ),
          ),
      ],
    );
  }
}

class _HDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppTheme.background,
    );
  }
}

class _WeatherBlock extends StatelessWidget {
  final TripModel trip;
  const _WeatherBlock({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          weatherIcon(trip.weatherCode),
          color: AppTheme.accent,
          size: 52,
        ),
        const SizedBox(height: 8),
        Text(
          trip.weatherLabel,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '${trip.weatherTempC.toStringAsFixed(1)}°C',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 22,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SmoothnessBlock extends StatelessWidget {
  final double score;
  final String descriptor;
  const _SmoothnessBlock({required this.score, required this.descriptor});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          score.toStringAsFixed(1),
          style: const TextStyle(
            color: AppTheme.accent,
            fontSize: 64,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          descriptor,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}