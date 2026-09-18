import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/widgets/responsive_pair.dart';
import 'package:tilawa/presentation/features/utilities/tasbeeh_view.dart';
import 'package:tilawa/presentation/features/utilities/qibla_view.dart';
import 'package:tilawa/presentation/features/utilities/widgets/utility_card.dart';

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
                      first: UtilityCard(
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
                      second: UtilityCard(
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
