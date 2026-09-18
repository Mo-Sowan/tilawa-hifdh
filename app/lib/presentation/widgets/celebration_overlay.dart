import 'package:flutter/material.dart';

import 'package:tilawa/presentation/widgets/celebration/celebration_type.dart';
import 'package:tilawa/presentation/widgets/celebration/celebration_widget.dart';

// Re-exported so a caller needs one import to both name a celebration and
// show it.
export 'package:tilawa/presentation/widgets/celebration/celebration_type.dart';

class CelebrationOverlay {
  static void show(
    BuildContext context, {
    required CelebrationType type,
    required String title,
    required String subtitle,
    OverlayState? overlayState,
    VoidCallback? onComplete,
  }) {
    final overlay = overlayState ?? Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => CelebrationWidget(
        type: type,
        title: title,
        subtitle: subtitle,
        onDismiss: () {
          entry.remove();
          onComplete?.call();
        },
      ),
    );

    overlay.insert(entry);
  }
}
