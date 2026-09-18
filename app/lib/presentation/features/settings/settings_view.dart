import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/core/utils/file_exporter.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/widgets/settings_tile.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/presentation/providers/revision_plan_provider.dart';
import 'package:tilawa/presentation/features/utilities/utilities_view.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final strings = ref.watch(appStringsProvider);
    final apiHealth = ref.watch(apiHealthProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            strings.settingsTab,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          Card(
              child: ListTile(
            leading: const Icon(Icons.widgets_outlined),
            title: Text(strings.isArabic ? 'الأدوات' : 'Utilities'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const UtilitiesView(),
            )),
          )),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.cloud_done_rounded,
            title: strings.apiStatus,
            subtitle: apiHealth.when(
              data: (online) => online ? strings.online : strings.offline,
              loading: () => strings.checking,
              error: (_, __) => strings.offline,
            ),
            trailing: IconButton(
              onPressed: () => ref.invalidate(apiHealthProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.dns_rounded,
            title: strings.isArabic ? 'رابط خادم API' : 'API Server URL',
            subtitle: settings.serverUrl,
            trailing: IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () =>
                  _showServerUrlDialog(context, ref, settings.serverUrl),
            ),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.notifications_active_outlined,
            title: strings.lifecycleAlerts,
            subtitle: strings.lifecycleAlertsDesc,
            trailing: Switch.adaptive(
              value: settings.lifecycleAlertsEnabled,
              onChanged: (_) => ref
                  .read(appSettingsProvider.notifier)
                  .toggleLifecycleAlerts(),
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
            icon: Icons.timer_rounded,
            title: strings.dailyGoalSetting,
            subtitle: strings.goalMinutes(settings.dailyGoalMinutes),
            trailing: DropdownButton<int>(
              value: settings.dailyGoalMinutes,
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(appSettingsProvider.notifier)
                      .updateDailyGoalMinutes(val);
                }
              },
              items: [10, 15, 20, 30, 45, 60, 90].map((m) {
                return DropdownMenuItem(
                  value: m,
                  child: Text(strings.goalMinutes(m)),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.text_fields_rounded,
            title: strings.quranFontSizeSetting,
            subtitle: '${settings.quranFontSize.round()} px',
            trailing: SizedBox(
              width: 110,
              child: Slider(
                min: 16,
                max: 36,
                divisions: 10,
                value: settings.quranFontSize,
                onChanged: (val) =>
                    ref.read(appSettingsProvider.notifier).updateFontSize(val),
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _showExportOptions(context, ref),
            icon: const Icon(Icons.download_rounded),
            label: Text(strings.exportDataSetting),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: strings.quranDataSafety,
            subtitle: strings.privacySafe,
            trailing: const Icon(Icons.verified_user_outlined),
          ),
          const SizedBox(height: 20),
          SettingsTile(
            icon: Icons.color_lens_rounded,
            title: strings.theme,
            subtitle: AppTheme.palettes[settings.themeIndex].name,
            trailing: DropdownButton<int>(
              value: settings.themeIndex,
              onChanged: (val) {
                if (val != null) {
                  ref.read(appSettingsProvider.notifier).updateThemeIndex(val);
                }
              },
              items: List.generate(AppTheme.palettes.length, (index) {
                return DropdownMenuItem(
                  value: index,
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppTheme.palettes[index].primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(AppTheme.palettes[index].name,
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.language_rounded,
            title: strings.languageLabel,
            subtitle: settings.language == AppLanguage.arabic
                ? strings.arabic
                : 'English',
            trailing: FilledButton.tonal(
              onPressed: () =>
                  ref.read(appSettingsProvider.notifier).toggleLanguage(),
              child: Text(settings.language == AppLanguage.arabic
                  ? 'English'
                  : strings.arabic),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            strings.quranDataNotice,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  void _showServerUrlDialog(
      BuildContext context, WidgetRef ref, String currentUrl) {
    final controller = TextEditingController(text: currentUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Server URL'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.15:5188',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                ref.read(appSettingsProvider.notifier).updateServerUrl(newUrl);
                ref.invalidate(apiHealthProvider);
                ref.invalidate(revisionOverviewProvider);
                ref.invalidate(weakestSurahProvider);
                ref.invalidate(progressSummaryProvider);
                ref.invalidate(revisionPlansProvider);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showExportOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.data_object_rounded),
              title: const Text('Export as JSON'),
              onTap: () {
                Navigator.pop(ctx);
                _exportData(context, ref, 'json');
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_rounded),
              title: const Text('Export as CSV'),
              onTap: () {
                Navigator.pop(ctx);
                _exportData(context, ref, 'csv');
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_rounded),
              title: const Text('Export as TXT'),
              onTap: () {
                Navigator.pop(ctx);
                _exportData(context, ref, 'txt');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exportData(BuildContext context, WidgetRef ref, String format) {
    final overviewAsync = ref.read(revisionOverviewProvider);

    overviewAsync.whenData((surahs) {
      String outputStr = '';
      String filename = 'hifdh_export';
      String mimeType = 'text/plain';

      if (format == 'json') {
        final data = {
          'exportDate': DateTime.now().toIso8601String(),
          'surahs': surahs
              .map((s) => {
                    'number': s.number,
                    'englishName': s.englishName,
                    'arabicName': s.arabicName,
                    'mastery': s.mastery,
                    'mistakeRate': s.mistakeRate,
                    'revisionCount': s.revisionCount,
                    'lastReviewed': s.lastReviewed?.toIso8601String(),
                  })
              .toList(),
        };
        outputStr = const JsonEncoder.withIndent('  ').convert(data);
        filename += '.json';
        mimeType = 'application/json';
      } else if (format == 'csv') {
        outputStr =
            "Number,English Name,Arabic Name,Mastery,Mistake Rate,Revision Count,Last Reviewed\n";
        for (final s in surahs) {
          outputStr +=
              "${s.number},${s.englishName},${s.arabicName},${s.mastery.toStringAsFixed(3)},${s.mistakeRate.toStringAsFixed(3)},${s.revisionCount},${s.lastReviewed?.toIso8601String() ?? 'Never'}\n";
        }
        filename += '.csv';
        mimeType = 'text/csv';
      } else if (format == 'txt') {
        outputStr = "Tilawa Export - ${DateTime.now().toString()}\n";
        outputStr += "=================================================\n\n";
        for (final s in surahs) {
          outputStr +=
              "Surah ${s.number} - ${s.englishName} (${s.arabicName})\n";
          outputStr += "Mastery: ${(s.mastery * 100).toStringAsFixed(1)}%\n";
          outputStr += "Revisions: ${s.revisionCount}\n";
          outputStr +=
              "Last Reviewed: ${s.lastReviewed?.toString() ?? 'Never'}\n";
          outputStr += "-------------------------------------------------\n";
        }
        filename += '.txt';
        mimeType = 'text/plain';
      }

      exportFileAndDownload(context, outputStr, filename, mimeType);
    });
  }
}
