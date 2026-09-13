import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/auth_provider.dart';
import 'package:tilawa/presentation/providers/reciter_profile_provider.dart';
import 'package:tilawa/presentation/views/auth_view.dart';
import 'package:tilawa/presentation/views/main_view.dart';
import 'package:tilawa/presentation/views/onboarding_view.dart';
import 'package:tilawa/presentation/views/profiling_view.dart';

/// Decides what a reciter sees when the app opens.
///
/// The order is deliberate: the tour, then the account, then the four
/// questions. Asking who someone is before they have agreed to be here reads
/// as an interrogation, and the answers personalise a plan they can only reach
/// once they are in.
class RootNavigator extends ConsumerWidget {
  const RootNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final authState = ref.watch(authProvider);

    if (authState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!settings.hasSeenOnboarding) {
      return const OnboardingView();
    }

    if (!authState.isAuthenticated) {
      return const AuthView();
    }

    final profile = ref.watch(reciterProfileProvider);

    // Wait for the stored answers before deciding. Guessing "not answered"
    // while they load would ask a returning reciter the same four questions
    // every single launch.
    return profile.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      // Unreadable answers are not worth blocking on: go in, and the
      // questionnaire can be offered again another time.
      error: (_, __) => const MainView(),
      data: (value) => value.isComplete
          ? const MainView()
          : ProfilingView(
              // Completing writes the flag the questionnaire is gated on, so
              // rebuilding here lands on the dashboard.
              onFinished: () => ref.invalidate(reciterProfileProvider),
            ),
    );
  }
}
