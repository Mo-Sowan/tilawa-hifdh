import 'package:flutter/material.dart';

class UtilityCard extends StatelessWidget {
  const UtilityCard(
      {super.key, required this.icon,
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
