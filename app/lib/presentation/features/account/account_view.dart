
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/core/utils/file_exporter.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/auth_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/presentation/widgets/settings_tile.dart';
import 'package:tilawa/presentation/features/account/widgets/profile_header.dart';
import 'package:tilawa/presentation/features/account/widgets/sync_tile.dart';
import 'package:tilawa/presentation/features/account/widgets/statistics_grid.dart';
import 'package:tilawa/presentation/features/account/widgets/theme_dropdown.dart';

/// The signed-in account: who you are, what syncs, what the app has recorded,
/// and the preferences that belong to *you* rather than to the device.
///
/// Device-wide configuration — server URL, font size, notification behaviour —
/// stays in the Settings tab; this screen never duplicates that state, it reads
/// and writes the same providers.
class AccountView extends ConsumerWidget {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final strings = ref.watch(appStringsProvider);
    final settings = ref.watch(appSettingsProvider);
    final user = authState.user;

    if (authState.isLoading && user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(strings.accountTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          ProfileHeader(user: user, isGuest: authState.isGuest),

          SettingsSectionHeader(strings.accountSection),
          if (authState.isGuest)
            SettingsTile(
              icon: Icons.person_outline_rounded,
              title: strings.guestMode,
              subtitle: strings.guestModeDesc,
              trailing: FilledButton.tonal(
                onPressed: () => ref.read(authProvider.notifier).signOut(),
                child: Text(strings.signInToSync),
              ),
            )
          else ...[
            SettingsTile(
              icon: Icons.verified_user_outlined,
              title: strings.signedInWith,
              subtitle: _providerLabel(user?.provider),
              trailing: Icon(
                _providerIcon(user?.provider),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            SettingsTile(
              icon: Icons.alternate_email_rounded,
              title: strings.isArabic ? 'البريد الإلكتروني' : 'Email',
              subtitle: (user?.email.isNotEmpty ?? false)
                  ? user!.email
                  : (strings.isArabic ? 'غير متاح' : 'Not provided'),
            ),
          ],

          SettingsSectionHeader(strings.syncSection),
          const SyncTile(),

          SettingsSectionHeader(strings.statisticsSection),
          const StatisticsGrid(),

          SettingsSectionHeader(strings.preferencesSection),
          SettingsTile(
            icon: Icons.language_rounded,
            title: strings.languageLabel,
            subtitle: settings.language == AppLanguage.arabic
                ? strings.arabic
                : 'English',
            trailing: FilledButton.tonal(
              onPressed: () =>
                  ref.read(appSettingsProvider.notifier).toggleLanguage(),
              child: Text(
                settings.language == AppLanguage.arabic
                    ? 'English'
                    : strings.arabic,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.color_lens_rounded,
            title: strings.theme,
            subtitle: AppTheme.palettes[settings.themeIndex].name,
            trailing: ThemeDropdown(themeIndex: settings.themeIndex),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.timer_rounded,
            title: strings.dailyGoalSetting,
            subtitle: strings.goalMinutes(settings.dailyGoalMinutes),
            trailing: DropdownButton<int>(
              value: settings.dailyGoalMinutes,
              underline: const SizedBox.shrink(),
              onChanged: (value) {
                if (value == null) return;
                ref
                    .read(appSettingsProvider.notifier)
                    .updateDailyGoalMinutes(value);
              },
              items: [10, 15, 20, 30, 45, 60, 90]
                  .map(
                    (minutes) => DropdownMenuItem(
                      value: minutes,
                      child: Text(strings.goalMinutes(minutes)),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.list_alt_rounded,
            title: strings.defaultSurahListView,
            subtitle: strings.defaultSurahListViewDesc,
            trailing: Switch.adaptive(
              value: settings.showSurahListExpandedDefault,
              onChanged: (_) => ref
                  .read(appSettingsProvider.notifier)
                  .toggleSurahListDefault(),
            ),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.auto_stories_rounded,
            title: strings.wisdomAutoRotate,
            subtitle: strings.wisdomAutoRotateDesc,
            trailing: Switch.adaptive(
              value: settings.dailyWisdomAutoRotate,
              onChanged: (_) => ref
                  .read(appSettingsProvider.notifier)
                  .toggleDailyWisdomAutoRotate(),
            ),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.notifications_active_outlined,
            title: strings.lifecycleAlerts,
            subtitle: strings.lifecycleAlertsDesc,
            trailing: Switch.adaptive(
              value: settings.lifecycleAlertsEnabled,
              onChanged: (_) =>
                  ref.read(appSettingsProvider.notifier).toggleLifecycleAlerts(),
            ),
          ),

          SettingsSectionHeader(strings.dataSection),
          SettingsTile(
            icon: Icons.download_rounded,
            title: strings.exportDataSetting,
            subtitle: strings.exportSubtitle,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _exportProgress(context, ref),
          ),

          const SizedBox(height: 24),
          SettingsTile(
            icon: Icons.logout_rounded,
            title: strings.isArabic ? 'تسجيل الخروج' : 'Sign Out',
            subtitle: strings.isArabic
                ? 'يبقى تقدمك محفوظاً على هذا الجهاز'
                : 'Your progress stays saved on this device',
            color: AppColors.rose,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
    );
  }

  static String _providerLabel(String? provider) {
    return switch (provider) {
      'google' => 'Google',
      'apple' => 'Apple',
      _ => '—',
    };
  }

  static IconData _providerIcon(String? provider) {
    return switch (provider) {
      'google' => Icons.g_mobiledata_rounded,
      'apple' => Icons.apple_rounded,
      _ => Icons.person_outline_rounded,
    };
  }

  Future<void> _exportProgress(BuildContext context, WidgetRef ref) async {
    final strings = ref.read(appStringsProvider);
    final surahs = ref.read(revisionOverviewProvider).valueOrNull;
    if (surahs == null || surahs.isEmpty) return;

    final buffer = StringBuffer()
      ..writeln('Tilawa progress export - ${DateTime.now().toIso8601String()}')
      ..writeln('Surah,English,Arabic,Mastery,MistakeRate,Revisions,LastReviewed');
    for (final surah in surahs) {
      buffer.writeln(
        '${surah.number},${surah.englishName},${surah.arabicName},'
        '${surah.mastery.toStringAsFixed(3)},'
        '${surah.mistakeRate.toStringAsFixed(3)},'
        '${surah.revisionCount},'
        '${surah.lastReviewed?.toIso8601String() ?? ''}',
      );
    }

    if (!context.mounted) return;
    await exportFileAndDownload(
      context,
      buffer.toString(),
      'tilawa_progress.csv',
      'text/csv',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(strings.exportSuccess)));
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final strings = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.isArabic ? 'تسجيل الخروج' : 'Sign Out'),
        content: Text(
          strings.isArabic
              ? 'هل أنت متأكد أنك تريد تسجيل الخروج؟'
              : 'Are you sure you want to sign out?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            child: Text(strings.isArabic ? 'خروج' : 'Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(authProvider.notifier).signOut();
  }
}
