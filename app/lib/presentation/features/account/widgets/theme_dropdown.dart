import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';

class ThemeDropdown extends ConsumerWidget {
  const ThemeDropdown({super.key, required this.themeIndex});

  final int themeIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButton<int>(
      value: themeIndex,
      underline: const SizedBox.shrink(),
      onChanged: (value) {
        if (value == null) return;
        ref.read(appSettingsProvider.notifier).updateThemeIndex(value);
      },
      items: List.generate(AppTheme.palettes.length, (index) {
        return DropdownMenuItem(
          value: index,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppTheme.palettes[index].primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppTheme.palettes[index].name,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      }),
    );
  }
}
