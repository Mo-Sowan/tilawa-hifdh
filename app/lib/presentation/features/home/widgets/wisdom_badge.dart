import 'package:flutter/material.dart';
import 'package:tilawa/core/theme/app_theme.dart';

class WisdomBadge extends StatelessWidget {
  const WisdomBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AppColors.amber,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
