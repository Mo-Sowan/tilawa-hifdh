import 'package:flutter/material.dart';

/// Fades and lifts its child in after [delay].
class AnimatedIn extends StatefulWidget {
  const AnimatedIn({super.key, required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<AnimatedIn> createState() => AnimatedInState();
}

class AnimatedInState extends State<AnimatedIn> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      offset: _shown ? Offset.zero : const Offset(0, 0.18),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 360),
        opacity: _shown ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}
