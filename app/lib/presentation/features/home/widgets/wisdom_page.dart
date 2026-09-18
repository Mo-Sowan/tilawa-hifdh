import 'package:flutter/material.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/presentation/widgets/octagram_pattern_painter.dart';
import 'package:tilawa/presentation/features/home/widgets/wisdom.dart';
import 'package:tilawa/presentation/features/home/widgets/wisdom_badge.dart';

/// One card in the wisdom carousel.
/// One card in the wisdom carousel.
///
/// A single deep emerald identity rather than a different gradient per saying:
/// the words are the subject, and rotating the colour made the card read as
/// decoration that happened to contain text.
class WisdomPage extends StatelessWidget {
  const WisdomPage({super.key, 
    required this.wisdom,
    required this.isArabic,
    required this.badge,
    required this.controller,
    required this.pageIndex,
    required this.onTap,
  });

  final Wisdom wisdom;
  final bool isArabic;
  final String badge;
  final PageController controller;
  final int pageIndex;
  final VoidCallback onTap;

  /// Asymmetric stops: the dark end holds most of the card and the lighter one
  /// lifts a corner, which gives the flat rectangle some direction.
  static const Color _deep = Color(0xFF0F3935);
  static const Color _light = Color(0xFF1E6B5C);

  @override
  Widget build(BuildContext context) {
    // Cards behind the current one sit back slightly, which reads as depth
    // while swiping and makes the wrap feel continuous.
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        var distance = 0.0;
        if (controller.position.haveDimensions) {
          distance = ((controller.page ?? pageIndex.toDouble()) - pageIndex)
              .abs()
              .clamp(0.0, 1.0);
        }
        return Transform.scale(
          scale: 1 - (distance * 0.06),
          child: Opacity(opacity: 1 - (distance * 0.35), child: child),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_deep, _light],
              stops: [0.35, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: _deep.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: OctagramPatternPainter(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
              // Oversized quote mark, anchored to the reading side.
              PositionedDirectional(
                top: 4,
                start: 12,
                child: Text(
                  '\u201C',
                  style: TextStyle(
                    fontSize: 76,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: AppColors.amber.withValues(alpha: 0.28),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: WisdomBadge(label: badge),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            isArabic ? wisdom.arabic : wisdom.english,
                            textAlign: TextAlign.center,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: isArabic
                                ? AppTheme.arabicText(
                                    size: 21,
                                    color: Colors.white,
                                  ).copyWith(fontWeight: FontWeight.w700)
                                : const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.45,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // The source sits where an attribution belongs: last, to
                      // the trailing side, and set apart by being italic.
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          wisdom.reference,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
