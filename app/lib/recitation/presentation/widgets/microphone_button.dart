import 'package:flutter/material.dart';

class MicrophoneButton extends StatelessWidget {
  const MicrophoneButton({super.key, 
    required this.isListening,
    required this.enabled,
    required this.onPressed,
  });

  final bool isListening;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 56,
      height: 56,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          backgroundColor: isListening ? scheme.error : scheme.primary,
        ),
        child: Icon(
          isListening ? Icons.stop_rounded : Icons.mic_rounded,
          size: 26,
        ),
      ),
    );
  }
}
