import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const background = Color(0xFF12161A);
  static const surface = Color(0xFF1A2026);
  static const elevated = Color(0xFF222A31);
  static const outline = Color(0xFF2F3943);
  static const mint = Color(0xFF79D9BC);
  static const emerald = Color(0xFF16765F);
  static const amber = Color(0xFFFFB300);
  static const blue = Color(0xFF2196F3);
  static const rose = Color(0xFFFF5C7A);
  static const purple = Color(0xFFB388FF);
  static const cyan = Color(0xFF18FFFF);
  static const orange = Color(0xFFFF8A65);
  static const textPrimary = Color(0xFFF6F9FB);
  static const textMuted = Color(0xFF9BA8B4);

  static const lightBackground = Color(0xFFF5F6F2);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightElevated = Color(0xFFEFF5F2);
  static const lightOutline = Color(0xFFD7E3DD);
  static const lightTextPrimary = Color(0xFF17211D);
  static const lightTextMuted = Color(0xFF64746D);
}

class AppThemePalette {
  final String name;
  final Color primary;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textMuted;
  final Brightness brightness;

  const AppThemePalette({
    required this.name,
    required this.primary,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textMuted,
    required this.brightness,
  });
}

class AppTheme {
  const AppTheme._();

  static const List<AppThemePalette> palettes = [
    AppThemePalette(
      name: 'Mint Night',
      primary: AppColors.mint,
      background: AppColors.background,
      surface: AppColors.surface,
      textPrimary: AppColors.textPrimary,
      textMuted: AppColors.textMuted,
      brightness: Brightness.dark,
    ),
    AppThemePalette(
      name: 'Emerald Day',
      primary: AppColors.emerald,
      background: AppColors.lightBackground,
      surface: AppColors.lightSurface,
      textPrimary: AppColors.lightTextPrimary,
      textMuted: AppColors.lightTextMuted,
      brightness: Brightness.light,
    ),
    AppThemePalette(
      name: 'Sapphire Deep',
      primary: Color(0xFF2196F3),
      background: Color(0xFF0D1B2A),
      surface: Color(0xFF1B263B),
      textPrimary: Color(0xFFE0E1DD),
      textMuted: Color(0xFF778DA9),
      brightness: Brightness.dark,
    ),
    AppThemePalette(
      name: 'Amethyst Dusk',
      primary: Color(0xFFB388FF),
      background: Color(0xFF120B1A),
      surface: Color(0xFF221533),
      textPrimary: Color(0xFFF2E6FF),
      textMuted: Color(0xFFA18BAD),
      brightness: Brightness.dark,
    ),
    AppThemePalette(
      name: 'Ruby Heart',
      primary: Color(0xFFFF4D6D),
      background: Color(0xFF1A0A0D),
      surface: Color(0xFF2E151A),
      textPrimary: Color(0xFFFFE3E8),
      textMuted: Color(0xFFB58A93),
      brightness: Brightness.dark,
    ),
    AppThemePalette(
      name: 'Ocean Breeze',
      primary: Color(0xFF00B4D8),
      background: Color(0xFFF0F8FF),
      surface: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF03045E),
      textMuted: Color(0xFF0077B6),
      brightness: Brightness.light,
    ),
    AppThemePalette(
      name: 'Sunset Glow',
      primary: Color(0xFFFF8FA3),
      background: Color(0xFF2D0A14),
      surface: Color(0xFF4A1523),
      textPrimary: Color(0xFFFFE6EB),
      textMuted: Color(0xFFC78F9B),
      brightness: Brightness.dark,
    ),
    AppThemePalette(
      name: 'Forest Canopy',
      primary: Color(0xFF52B788),
      background: Color(0xFF081C15),
      surface: Color(0xFF1B4332),
      textPrimary: Color(0xFFD8F3DC),
      textMuted: Color(0xFF74A58A),
      brightness: Brightness.dark,
    ),
    AppThemePalette(
      name: 'Obsidian',
      primary: Color(0xFFEAEAEA),
      background: Color(0xFF000000),
      surface: Color(0xFF111111),
      textPrimary: Color(0xFFFFFFFF),
      textMuted: Color(0xFF888888),
      brightness: Brightness.dark,
    ),
    AppThemePalette(
      name: 'Royal Gold',
      primary: Color(0xFFD2AF26),
      background: Color(0xFF121212),
      surface: Color(0xFF1E1E1E),
      textPrimary: Color(0xFFFFFFFF),
      textMuted: Color(0xFFB3B3B3),
      brightness: Brightness.dark,
    ),
    AppThemePalette(
      name: 'Desert Sand',
      primary: Color(0xFFD4A373),
      background: Color(0xFFFAEDCD),
      surface: Color(0xFFFEFAE0),
      textPrimary: Color(0xFF5A3A22),
      textMuted: Color(0xFF8A6A52),
      brightness: Brightness.light,
    ),
    AppThemePalette(
      name: 'Pearl White',
      primary: Color(0xFF5E5E5E),
      background: Color(0xFFFFFFFF),
      surface: Color(0xFFF5F5F5),
      textPrimary: Color(0xFF212121),
      textMuted: Color(0xFF9E9E9E),
      brightness: Brightness.light,
    ),
    AppThemePalette(
      name: 'Soft Lavender',
      primary: Color(0xFF9575CD),
      background: Color(0xFFF3E5F5),
      surface: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF4A148C),
      textMuted: Color(0xFF7B1FA2),
      brightness: Brightness.light,
    ),
  ];

  static ThemeData buildTheme(AppThemePalette palette) {
    final isDark = palette.brightness == Brightness.dark;
    // Palette brightness alone does not determine whether a button needs white or dark text.
    final onPrimaryColor =
        palette.primary.computeLuminance() > .179 ? Colors.black : Colors.white;

    final base = ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      scaffoldBackgroundColor: palette.background,
      colorScheme: ColorScheme(
        brightness: palette.brightness,
        primary: palette.primary,
        onPrimary: onPrimaryColor,
        secondary: palette.primary,
        onSecondary: onPrimaryColor,
        error: AppColors.rose,
        onError: Colors.white,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        surfaceContainerHighest: palette.surface,
        outline: isDark ? const Color(0xFF2F3943) : const Color(0xFFD7E3DD),
      ),
    );

    return base.copyWith(
      dividerTheme: DividerThemeData(
          color: palette.textMuted.withValues(alpha: .16),
          thickness: 1,
          space: 24),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: palette.textMuted.withValues(alpha: .24))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: palette.primary, width: 2)),
      ),
      textTheme: base.textTheme.apply(
        fontFamily: uiFontFamily,
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: uiFontFamily,
          color: palette.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: palette.textMuted.withValues(alpha: .14))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: onPrimaryColor,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle:
              TextStyle(fontFamily: uiFontFamily, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.primary,
          side: BorderSide(color: palette.primary),
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle:
              TextStyle(fontFamily: uiFontFamily, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          textStyle:
              TextStyle(fontFamily: uiFontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return onPrimaryColor;
          }
          return palette.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.primary;
          }
          return palette.surface;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.primary,
        thumbColor: palette.primary,
        inactiveTrackColor: palette.surface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.primary.withValues(alpha: .25),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: palette.primary, size: 28);
          }
          return IconThemeData(color: palette.textMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: uiFontFamily,
              color: palette.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            );
          }
          return TextStyle(
            fontFamily: uiFontFamily,
            color: palette.textMuted,
            fontSize: 12,
          );
        }),
      ),
      splashColor: palette.primary.withValues(alpha: .12),
      highlightColor: palette.primary.withValues(alpha: .08),
    );
  }

  /// Quranic verse text. Amiri Quran carries the full set of Quranic marks
  /// and positions them correctly; the default system Arabic face does not,
  /// which is why verse text must never fall back to it.
  static const String quranFontFamily = 'QuranText';

  /// Interface face, bundled so nothing is fetched at launch.
  static const String uiFontFamily = 'Outfit';

  /// Surah titles and other Arabic display text.
  static const String arabicDisplayFontFamily = 'ScheherazadeNew';

  /// Style for Quranic verse text.
  ///
  /// The generous line height is not decoration: Quranic marks sit well above
  /// and below the baseline and collide at tighter spacing.
  static TextStyle quranText({
    double size = 24,
    Color? color,
    double height = 2.0,
    FontWeight weight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: quranFontFamily,
      fontSize: size,
      height: height,
      color: color,
      fontWeight: weight,
      letterSpacing: 0,
    );
  }

  /// Style for Arabic display text such as surah names.
  static TextStyle arabicText({
    double size = 32,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.textPrimary,
  }) {
    return TextStyle(
      fontFamily: arabicDisplayFontFamily,
      fontSize: size,
      fontWeight: weight,
      height: 1.6,
      color: color,
      letterSpacing: 0,
    );
  }
}
