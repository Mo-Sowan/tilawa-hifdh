import 'package:flutter/material.dart';
import 'package:tilawa/core/theme/app_theme.dart';

/// Surah name, length, and the basmala where the Mushaf prints one.
class SurahHeading extends StatelessWidget {
  const SurahHeading({
    super.key,
    required this.name,
    required this.ayahCount,
    required this.basmala,
    required this.hint,
    required this.fontSize,
  });

  final String name;
  final int ayahCount;
  final String? basmala;
  final String? hint;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.5);

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          style: AppTheme.arabicText(size: 26, color: scheme.onSurface),
        ),
        if (basmala != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              basmala!,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: AppTheme.quranText(
                size: fontSize * 0.85,
                color: scheme.primary.withValues(alpha: 0.85),
              ),
            ),
          ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              hint!,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        Divider(
          height: 20,
          color: scheme.onSurface.withValues(alpha: 0.10),
        ),
      ],
    );
  }
}
