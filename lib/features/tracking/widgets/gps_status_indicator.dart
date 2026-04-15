import 'package:flutter/material.dart';
import 'package:momentum/core/theme/app_theme.dart';

class GpsStatusIndicator extends StatelessWidget {
  final bool isWeak;

  const GpsStatusIndicator({super.key, required this.isWeak});

  @override
  Widget build(BuildContext context) {
    if (!isWeak) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.speedYellow.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.gps_not_fixed,
            color: AppTheme.speedYellow,
            size: 14,
          ),
          const SizedBox(width: 6),
          const Text(
            'WEAK GPS SIGNAL',
            style: TextStyle(
              color: AppTheme.speedYellow,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
