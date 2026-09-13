import 'package:flutter/material.dart';

/// Retains reading order on phones while using the available width on tablets.
class ResponsivePair extends StatelessWidget {
  const ResponsivePair({required this.first, required this.second, super.key});
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth >= 640) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ]);
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              const SizedBox(height: 16),
              second,
            ]);
      });
}
