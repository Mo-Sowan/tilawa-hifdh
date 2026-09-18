import 'package:flutter/material.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/presentation/features/onboarding/widgets/onboarding_page_data.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, 
    required this.data,
    required this.isDark,
    required this.accentColor,
  });

  final OnboardingPageData data;
  final bool isDark;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              data.icon,
              size: 100,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}
