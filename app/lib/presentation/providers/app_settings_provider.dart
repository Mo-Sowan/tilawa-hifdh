import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/config/app_config.dart';
import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/services/notification_service.dart';
import 'package:tilawa/services/database_service.dart';

class AppSettings {
  const AppSettings({
    this.language = AppLanguage.arabic,
    this.themeIndex = 1,
    this.dailyGoalMinutes = 30,
    this.quranFontSize = 24.0,
    this.lifecycleAlertsEnabled = true,
    this.showSurahListExpandedDefault = true,
    this.serverUrl = AppConfig.apiBaseUrl,
    this.hasSeenOnboarding = false,
    this.dailyWisdomAutoRotate = true,
    this.wisdomSeed = 0,
    this.profileImage,
    this.streakCelebratedOn,
  });

  final AppLanguage language;
  final int themeIndex;
  final int dailyGoalMinutes;
  final double quranFontSize;
  final bool lifecycleAlertsEnabled;
  final bool showSurahListExpandedDefault;
  final String serverUrl;
  final bool hasSeenOnboarding;

  /// Whether the daily wisdom card advances on its own. Off leaves it entirely
  /// under the reader's control.
  final bool dailyWisdomAutoRotate;

  /// Which saying the wisdom card opens on. Advanced once per launch and kept
  /// on the device, so opening the app shows something new rather than the
  /// same words every time until the date rolls over.
  final int wisdomSeed;

  /// The reciter's profile picture, base64-encoded.
  ///
  /// Held as bytes rather than a file path because the web build has no
  /// path to hold, and because a path handed over by the photo picker is
  /// temporary on both Android and iOS — it would be gone by the next
  /// launch. The picker downsizes before this is stored.
  final String? profileImage;

  /// The day the streak celebration was last shown, as `yyyy-mm-dd`.
  /// Kept so hitting the target fires once, not on every review after it.
  final String? streakCelebratedOn;

  AppSettings copyWith({
    AppLanguage? language,
    int? themeIndex,
    int? dailyGoalMinutes,
    double? quranFontSize,
    bool? lifecycleAlertsEnabled,
    bool? showSurahListExpandedDefault,
    String? serverUrl,
    bool? hasSeenOnboarding,
    bool? dailyWisdomAutoRotate,
    int? wisdomSeed,
    String? profileImage,
    bool clearProfileImage = false,
    String? streakCelebratedOn,
  }) {
    return AppSettings(
      language: language ?? this.language,
      themeIndex: themeIndex ?? this.themeIndex,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      quranFontSize: quranFontSize ?? this.quranFontSize,
      lifecycleAlertsEnabled: lifecycleAlertsEnabled ?? this.lifecycleAlertsEnabled,
      showSurahListExpandedDefault: showSurahListExpandedDefault ?? this.showSurahListExpandedDefault,
      serverUrl: serverUrl ?? this.serverUrl,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      dailyWisdomAutoRotate:
          dailyWisdomAutoRotate ?? this.dailyWisdomAutoRotate,
      wisdomSeed: wisdomSeed ?? this.wisdomSeed,
      profileImage:
          clearProfileImage ? null : (profileImage ?? this.profileImage),
      streakCelebratedOn: streakCelebratedOn ?? this.streakCelebratedOn,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    NotificationService().alertsEnabled = state.lifecycleAlertsEnabled;
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    try {
      final db = DatabaseService();
      final langStr = await db.getSetting('language');
      final themeStr = await db.getSetting('themeIndex');
      final goalStr = await db.getSetting('dailyGoalMinutes');
      final fontStr = await db.getSetting('quranFontSize');
      final alertsStr = await db.getSetting('lifecycleAlerts');
      final expandStr = await db.getSetting('showSurahListExpanded');
      final urlStr = await db.getSetting('serverUrl');
      final onboardingStr = await db.getSetting('hasSeenOnboarding');
      final wisdomStr = await db.getSetting('dailyWisdomAutoRotate');
      final seedStr = await db.getSetting('wisdomSeed');
      final imageStr = await db.getSetting('profileImage');
      final celebratedStr = await db.getSetting('streakCelebratedOn');
      // Move on now, so the next launch opens somewhere else again.
      final seed = (int.tryParse(seedStr ?? '') ?? 0) + 1;
      await db.saveSetting('wisdomSeed', seed.toString());

      state = AppSettings(
        language: langStr == 'english' ? AppLanguage.english : AppLanguage.arabic,
        themeIndex: themeStr != null ? int.parse(themeStr) : 1,
        dailyGoalMinutes: goalStr != null ? int.parse(goalStr) : 30,
        quranFontSize: fontStr != null ? double.parse(fontStr) : 24.0,
        lifecycleAlertsEnabled: alertsStr != 'false',
        // Expanded unless the user has explicitly collapsed it.
        showSurahListExpandedDefault: expandStr != 'false',
        serverUrl: urlStr ?? AppConfig.apiBaseUrl,
        hasSeenOnboarding: onboardingStr == 'true',
        dailyWisdomAutoRotate: wisdomStr != 'false',
        wisdomSeed: seed,
        profileImage: (imageStr?.isEmpty ?? true) ? null : imageStr,
        streakCelebratedOn: celebratedStr,
      );
      NotificationService().alertsEnabled = state.lifecycleAlertsEnabled;
    } catch (e) {
      debugPrint('Error loading settings from DB: $e');
    }
  }

  void toggleLanguage() async {
    final nextLang = state.language == AppLanguage.english
        ? AppLanguage.arabic
        : AppLanguage.english;
    state = state.copyWith(language: nextLang);
    await DatabaseService().saveSetting('language', nextLang == AppLanguage.english ? 'english' : 'arabic');
  }

  void updateThemeIndex(int newIndex) async {
    state = state.copyWith(themeIndex: newIndex);
    await DatabaseService().saveSetting('themeIndex', newIndex.toString());
  }

  void updateDailyGoalMinutes(int newGoal) async {
    state = state.copyWith(dailyGoalMinutes: newGoal);
    await DatabaseService().saveSetting('dailyGoalMinutes', newGoal.toString());
  }

  void updateFontSize(double newSize) async {
    state = state.copyWith(quranFontSize: newSize);
    await DatabaseService().saveSetting('quranFontSize', newSize.toString());
  }

  void toggleLifecycleAlerts() async {
    final next = !state.lifecycleAlertsEnabled;
    state = state.copyWith(lifecycleAlertsEnabled: next);
    NotificationService().alertsEnabled = next;
    await DatabaseService().saveSetting('lifecycleAlerts', next.toString());
  }

  void toggleSurahListDefault() async {
    final next = !state.showSurahListExpandedDefault;
    state = state.copyWith(showSurahListExpandedDefault: next);
    await DatabaseService().saveSetting('showSurahListExpanded', next.toString());
  }

  void updateServerUrl(String newUrl) async {
    state = state.copyWith(serverUrl: newUrl.trim());
    await DatabaseService().saveSetting('serverUrl', newUrl.trim());
  }

  void toggleDailyWisdomAutoRotate() async {
    final next = !state.dailyWisdomAutoRotate;
    state = state.copyWith(dailyWisdomAutoRotate: next);
    await DatabaseService()
        .saveSetting('dailyWisdomAutoRotate', next.toString());
  }

  /// Stores a chosen profile picture, or clears it when [encoded] is null.
  Future<void> setProfileImage(String? encoded) async {
    state = encoded == null
        ? state.copyWith(clearProfileImage: true)
        : state.copyWith(profileImage: encoded);
    if (encoded == null) {
      await DatabaseService().deleteSetting('profileImage');
    } else {
      await DatabaseService().saveSetting('profileImage', encoded);
    }
  }

  /// Records that today's target celebration has been shown.
  Future<void> markStreakCelebrated(DateTime day) async {
    final key = _dayKey(day);
    if (state.streakCelebratedOn == key) return;
    state = state.copyWith(streakCelebratedOn: key);
    await DatabaseService().saveSetting('streakCelebratedOn', key);
  }

  /// Whether the celebration has already run for [day].
  bool hasCelebrated(DateTime day) => state.streakCelebratedOn == _dayKey(day);

  static String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  void completeOnboarding() async {
    state = state.copyWith(hasSeenOnboarding: true);
    await DatabaseService().saveSetting('hasSeenOnboarding', 'true');
  }

}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});

final appStringsProvider = Provider<AppStrings>((ref) {
  return AppStrings(ref.watch(appSettingsProvider).language);
});
