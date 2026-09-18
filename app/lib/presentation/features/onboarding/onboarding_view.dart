import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/features/onboarding/widgets/onboarding_page_data.dart';
import 'package:tilawa/presentation/features/onboarding/widgets/onboarding_page.dart';

class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _completeOnboarding() {
    ref.read(appSettingsProvider.notifier).completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = ref.watch(appStringsProvider);
    final accentColor = Theme.of(context).colorScheme.primary;

    final List<OnboardingPageData> pages = [
      OnboardingPageData(
        title: strings.isArabic ? 'تتبع حفظك' : 'Track Your Hifdh',
        description: strings.isArabic 
            ? 'سجل مراجعتك اليومية وراقب تقدمك بسهولة تامة.'
            : 'Record your daily revision and monitor your progress with ease.',
        icon: Icons.auto_graph_rounded,
      ),
      OnboardingPageData(
        title: strings.isArabic ? 'حافظ على سلسلتك' : 'Keep Your Streak',
        description: strings.isArabic 
            ? 'حقق أهدافك اليومية واستمر في المراجعة دون انقطاع.'
            : 'Achieve your daily goals and keep your revision uninterrupted.',
        icon: Icons.local_fire_department_rounded,
      ),
      OnboardingPageData(
        title: strings.isArabic ? 'اكتشف نقاط ضعفك' : 'Identify Weaknesses',
        description: strings.isArabic 
            ? 'احصل على تحليل ذكي للسور التي تحتاج إلى مراجعة إضافية.'
            : 'Get smart analysis on which Surahs need more focused revision.',
        icon: Icons.insights_rounded,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  return OnboardingPage(
                    data: pages[index],
                    isDark: isDark,
                    accentColor: accentColor,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        height: 8.0,
                        width: _currentPage == index ? 24.0 : 8.0,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? accentColor
                              : (isDark ? Colors.white30 : Colors.black26),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _currentPage == pages.length - 1
                          ? _completeOnboarding
                          : () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentPage == pages.length - 1
                            ? (strings.isArabic ? 'ابدأ الآن' : 'Get Started')
                            : (strings.isArabic ? 'التالي' : 'Next'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
