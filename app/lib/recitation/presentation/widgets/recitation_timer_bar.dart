import 'package:flutter/material.dart';

class RecitationTimerBar extends StatelessWidget {
  const RecitationTimerBar({super.key, 
    required this.label,
    required this.isPaused,
    required this.onToggle,
    required this.isArabic,
    required this.primary,
  });

  final String label;
  final bool isPaused;
  final VoidCallback onToggle;
  final bool isArabic;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isPaused ? Icons.pause_circle_filled : Icons.timer_rounded,
            color: primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: primary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 16),
          Material(
            color: primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 20,
                      color: primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPaused
                          ? (isArabic ? 'استمر' : 'Resume')
                          : (isArabic ? 'إيقاف' : 'Pause'),
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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
