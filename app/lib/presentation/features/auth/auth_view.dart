import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/auth_provider.dart';
import 'package:tilawa/presentation/features/auth/widgets/provider_button.dart';
import 'package:tilawa/presentation/features/auth/widgets/auth_error_banner.dart';

/// Sign-in screen.
///
/// Identity is federated to Google and Apple only — the app holds no
/// passwords, so there is nothing to register, reset or leak.
class AuthView extends ConsumerWidget {
  const AuthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = ref.watch(appStringsProvider);
    final accentColor = Theme.of(context).colorScheme.primary;
    final authState = ref.watch(authProvider);
    final notifier = ref.watch(authProvider.notifier);
    final mutedColor =
        isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.menu_book_rounded, size: 80, color: accentColor),
                const SizedBox(height: 32),
                Text(
                  strings.isArabic
                      ? 'مرحباً بك في تلاوة'
                      : 'Welcome to Tilawa',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.isArabic
                      ? 'سجّل الدخول لحفظ تقدمك ومزامنته'
                      : 'Sign in to save and sync your progress',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: mutedColor),
                ),
                const SizedBox(height: 48),

                if (authState.error != null) ...[
                  AuthErrorBanner(
                    message: authState.error!,
                    onDismiss: notifier.clearError,
                  ),
                  const SizedBox(height: 20),
                ],

                ProviderButton(
                  icon: Icons.g_mobiledata_rounded,
                  label: strings.isArabic
                      ? 'المتابعة باستخدام Google'
                      : 'Continue with Google',
                  busy: authState.isSigningIn,
                  onPressed: notifier.signInWithGoogle,
                ),
                if (notifier.isAppleAvailable) ...[
                  const SizedBox(height: 12),
                  ProviderButton(
                    icon: Icons.apple_rounded,
                    label: strings.isArabic
                        ? 'المتابعة باستخدام Apple'
                        : 'Continue with Apple',
                    busy: authState.isSigningIn,
                    dark: true,
                    onPressed: notifier.signInWithApple,
                  ),
                ],

                if (notifier.allowsGuest) ...[
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: authState.isSigningIn
                        ? null
                        : notifier.continueAsGuest,
                    child: Text(
                      strings.isArabic
                          ? 'المتابعة بدون حساب'
                          : 'Continue without an account',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    strings.isArabic
                        ? 'يبقى تقدمك على هذا الجهاز فقط.'
                        : 'Your progress stays on this device only.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: mutedColor),
                  ),
                ],

                const SizedBox(height: 32),
                Text(
                  strings.isArabic
                      ? 'يعمل التعرّف على التلاوة على جهازك بالكامل — لا يُرسل أي صوت.'
                      : 'Recitation recognition runs entirely on your device. '
                          'No audio ever leaves it.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: mutedColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
