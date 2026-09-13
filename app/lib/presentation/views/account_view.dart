import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/core/utils/file_exporter.dart';
import 'package:tilawa/data/datasources/auth_api_client.dart';
import 'package:tilawa/recitation/presentation/recitation_providers.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/auth_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/presentation/widgets/settings_tile.dart';

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
          _ProfileHeader(user: user, isGuest: authState.isGuest),

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
          const _SyncTile(),

          SettingsSectionHeader(strings.statisticsSection),
          const _StatisticsGrid(),

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
            trailing: _ThemeDropdown(themeIndex: settings.themeIndex),
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

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.user, required this.isGuest});

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
        _ProfileAvatar(
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

/// The profile picture, with the tap that lets it be changed.
///
/// The picture is the reciter's own and never leaves the device: it is stored
/// with their settings, not uploaded.
class _ProfileAvatar extends ConsumerStatefulWidget {
  const _ProfileAvatar({required this.initial});

  final String initial;

  @override
  ConsumerState<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends ConsumerState<_ProfileAvatar> {
  bool _busy = false;

  Future<void> _pick() async {
    final strings = ref.read(appStringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // Downsized here rather than after the fact: a full-resolution photo
        // is megabytes, and this is drawn at 92 logical pixels.
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      await ref
          .read(appSettingsProvider.notifier)
          .setProfileImage(base64Encode(bytes));
    } catch (error) {
      debugPrint('Could not read the chosen photo: $error');
      messenger.showSnackBar(SnackBar(content: Text(strings.photoFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _offerChoices() async {
    final strings = ref.read(appStringsProvider);
    final hasPhoto = ref.read(appSettingsProvider).profileImage != null;

    final remove = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(strings.choosePhoto),
              onTap: () => Navigator.pop(sheetContext, false),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(strings.removePhoto),
                onTap: () => Navigator.pop(sheetContext, true),
              ),
          ],
        ),
      ),
    );

    if (remove == null || !mounted) return;
    if (remove) {
      await ref.read(appSettingsProvider.notifier).setProfileImage(null);
    } else {
      await _pick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = ref.watch(appStringsProvider);
    final encoded = ref.watch(appSettingsProvider).profileImage;

    Uint8List? bytes;
    if (encoded != null) {
      try {
        bytes = base64Decode(encoded);
      } catch (error) {
        // A value written by an older build, or truncated storage.
        debugPrint('Discarding an unreadable profile picture: $error');
      }
    }

    return Semantics(
      button: true,
      label: strings.changePhoto,
      child: InkWell(
        onTap: _busy ? null : _offerChoices,
        customBorder: const CircleBorder(),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 46,
              backgroundColor: scheme.primary.withValues(alpha: 0.18),
              backgroundImage: bytes == null ? null : MemoryImage(bytes),
              child: bytes != null
                  ? null
                  : Text(
                      widget.initial,
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: scheme.primary,
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.photo_camera_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Server reachability plus a manual push of anything still queued locally.
class _SyncTile extends ConsumerStatefulWidget {
  const _SyncTile();

  @override
  ConsumerState<_SyncTile> createState() => _SyncTileState();
}

class _SyncTileState extends ConsumerState<_SyncTile> {
  bool _syncing = false;

  Future<void> _sync() async {
    final strings = ref.read(appStringsProvider);
    final messenger = ScaffoldMessenger.of(context);

    if (ref.read(authProvider).isGuest) {
      messenger.showSnackBar(
        SnackBar(content: Text(strings.syncUnavailableOffline)),
      );
      return;
    }

    setState(() => _syncing = true);
    try {
      final uploaded =
          await ref.read(recitationSessionRepositoryProvider).syncPending();
      ref.invalidate(apiHealthProvider);
      ref.invalidate(revisionOverviewProvider);
      ref.invalidate(progressSummaryProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(strings.syncUploaded(uploaded))),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(strings.syncFailed)));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final health = ref.watch(apiHealthProvider);

    return SettingsTile(
      icon: Icons.cloud_sync_outlined,
      title: strings.apiStatus,
      subtitle: health.when(
        data: (online) => online ? strings.online : strings.offline,
        loading: () => strings.checking,
        error: (_, __) => strings.offline,
      ),
      trailing: _syncing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: _sync,
              child: Text(strings.syncNow),
            ),
    );
  }
}

/// The four numbers a reciter actually tracks.
class _StatisticsGrid extends ConsumerWidget {
  const _StatisticsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final summary = ref.watch(progressSummaryProvider).valueOrNull;
    final surahs = ref.watch(revisionOverviewProvider).valueOrNull ?? const [];

    final started = surahs.where((s) => s.revisionCount > 0).length;
    final revisions =
        surahs.fold<int>(0, (sum, surah) => sum + surah.revisionCount);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _StatCard(
          icon: Icons.bolt_rounded,
          label: strings.totalXpLabel,
          value: '${summary?.totalXp ?? 0}',
        ),
        _StatCard(
          icon: Icons.local_fire_department_rounded,
          label: strings.currentStreakLabel,
          value: strings.dayCount(summary?.streak ?? 0),
        ),
        _StatCard(
          icon: Icons.menu_book_rounded,
          label: strings.surahsStartedLabel,
          value: '$started',
        ),
        _StatCard(
          icon: Icons.repeat_rounded,
          label: strings.revisionsLabel,
          value: '$revisions',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.lightTextMuted,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeDropdown extends ConsumerWidget {
  const _ThemeDropdown({required this.themeIndex});

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
