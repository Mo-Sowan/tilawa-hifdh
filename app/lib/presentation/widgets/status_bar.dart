import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/data/datasources/auth_api_client.dart';
import 'package:tilawa/presentation/providers/auth_provider.dart';
import 'package:tilawa/presentation/providers/main_tab_provider.dart';
import 'package:tilawa/presentation/features/account/account_view.dart';

class AppStatusBar extends ConsumerWidget {
  const AppStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final xp = ref.watch(totalXpProvider);
    final strings = ref.watch(appStringsProvider);
    final muted = Theme.of(context).brightness == Brightness.dark
        ? AppColors.textMuted
        : AppColors.lightTextMuted;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.appName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                strings.dailyRevisionPath,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: muted),
              ),
            ],
          ),
        ),
        _StatusPill(
          label: '$streak',
          caption: strings.streak,
          color: Theme.of(context).colorScheme.secondary,
          onTap: () => ref.read(mainTabProvider.notifier).state = 2,
        ),
        const SizedBox(width: 8),
        _StatusPill(
          label: '$xp',
          caption: strings.xp,
          color: Theme.of(context).colorScheme.primary,
          onTap: () => ref.read(mainTabProvider.notifier).state = 2,
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountView()),
            );
          },
          child: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            child: Consumer(
              builder: (context, ref, child) {
                final user = ref.watch(authProvider).user;
                return Text(
                  _avatarInitial(user),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.caption,
    required this.color,
    this.onTap,
  });

  final String label;
  final String caption;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 68),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: .28)),
        ),
        child: Column(
          children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            caption,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textMuted
                      : AppColors.lightTextMuted,
                ),
          ),
        ],
      ),
      ),
    );
  }
}

/// First letter of whatever identity the provider gave us. Apple accounts can
/// arrive with no display name at all.
String _avatarInitial(AuthUser? user) {
  if (user == null) return '?';
  final source =
      user.displayName.trim().isNotEmpty ? user.displayName.trim() : user.email.trim();
  return source.isEmpty ? '?' : source[0].toUpperCase();
}
