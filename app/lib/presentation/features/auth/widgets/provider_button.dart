import 'package:flutter/material.dart';

class ProviderButton extends StatelessWidget {
  const ProviderButton({super.key, 
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
    this.dark = false,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final bool dark;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = dark ? scheme.onSurface : scheme.surface;
    final foreground = dark ? scheme.surface : scheme.onSurface;

    return FilledButton.icon(
      onPressed: busy ? null : () => onPressed(),
      icon: busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
            )
          : Icon(icon, size: 26),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        minimumSize: const Size.fromHeight(54),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
