import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/widgets/responsive_pair.dart';
import 'package:tilawa/presentation/views/tasbeeh_view.dart';
import 'package:tilawa/presentation/views/qibla_view.dart';

class UtilitiesView extends ConsumerWidget {
  const UtilitiesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = ref.watch(appStringsProvider).isArabic;
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'الأدوات' : 'Utilities')),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(ar ? 'مساحة للتركيز' : 'A moment to focus',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                      ar
                          ? 'أدوات بسيطة ترافق يومك'
                          : 'Simple tools for your daily practice',
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 24),
                  ResponsivePair(
                      first: _UtilityCard(
                        icon: Icons.touch_app_outlined,
                        title: ar ? 'عداد التسبيح' : 'Digital tasbeeh',
                        subtitle: ar
                            ? 'عدّاد مع هدف تختاره'
                            : 'Set a target, tap at your pace, and track each round.',
                        onTap: () =>
                            Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => const TasbeehView(),
                        )),
                      ),
                      second: _UtilityCard(
                        icon: Icons.explore_outlined,
                        title: ar ? 'اتجاه القبلة' : 'Qibla compass',
                        subtitle: ar
                            ? 'اعرف الاتجاه من موقعك'
                            : 'Find the direction from your location with a guided compass.',
                        onTap: () =>
                            Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => const QiblaView(),
                        )),
                      )),
                ],
              ))),
    );
  }
}

class _UtilityCard extends StatelessWidget {
  const _UtilityCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(18)),
                        child: Icon(icon, color: scheme.primary, size: 30)),
                    const SizedBox(height: 24),
                    Row(children: [
                      Expanded(
                          child: Text(title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700))),
                      Icon(Icons.arrow_forward,
                          textDirection: Directionality.of(context),
                          color: scheme.primary)
                    ]),
                    const SizedBox(height: 8),
                    Text(subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.6)),
                  ]),
            )));
  }
}
