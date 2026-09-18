import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/data/datasources/auth_api_client.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/features/account/widgets/profile_avatar.dart';

class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({super.key, required this.user, required this.isGuest});

  final AuthUser? user;
  final bool isGuest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = ref.watch(appStringsProvider);
    final displayName = (user?.displayName.isNotEmpty ?? false)
        ? user!.displayName
        : (isGuest ? strings.guestMode : (user?.email ?? ''));

    return Column(
      children: [
        ProfileAvatar(
          initial: _initial(user?.displayName ?? '', user?.email ?? ''),
        ),
        const SizedBox(height: 14),
        Text(
          displayName,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (user?.email.isNotEmpty ?? false) ...[
          const SizedBox(height: 4),
          Text(
            user!.email,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                ),
          ),
        ],
      ],
    );
  }

  /// First letter of the display name, falling back to the email local part —
  /// Apple accounts may supply neither on later sign-ins.
  static String _initial(String displayName, String email) {
    final source =
        displayName.trim().isNotEmpty ? displayName.trim() : email.trim();
    return source.isEmpty ? '?' : source[0].toUpperCase();
  }
}
