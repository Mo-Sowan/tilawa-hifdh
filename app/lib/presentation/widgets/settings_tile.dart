import 'package:flutter/material.dart';

import 'package:tilawa/core/theme/app_theme.dart';

/// One row of a settings list: icon, title, explanatory subtitle, and a control.
///
/// Shared by the Settings tab and the Account screen so a preference looks and
/// behaves the same wherever it is surfaced.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.color,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  /// Makes the whole row tappable. Leave null for rows whose only control is
  /// the [trailing] widget.
  final VoidCallback? onTap;

  /// Overrides the accent colour, for destructive rows.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = color ?? Theme.of(context).colorScheme.primary;
    final mutedColor = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    final content = LayoutBuilder(builder: (context, constraints) {
      final stacked = constraints.maxWidth < 380 &&
          trailing != null &&
          trailing is! Switch &&
          trailing is! IconButton;
      return Padding(
        padding: const EdgeInsets.all(14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(
            children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: accent.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: accent, size: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: mutedColor),
                    ),
                  ],
                ),
              ),
              if (trailing != null && !stacked) trailing!,
            ],
          ),
          if (stacked) ...[
            const SizedBox(height: 12),
            Align(alignment: AlignmentDirectional.centerEnd, child: trailing!)
          ],
        ]),
      );
    });

    return Container(
      decoration: BoxDecoration(
        color: color == null
            ? Theme.of(context).colorScheme.surface
            : accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color == null
              ? Theme.of(context).colorScheme.outline.withValues(alpha: .45)
              : accent.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// A labelled break between groups of [SettingsTile]s.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
