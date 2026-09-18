import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/domain/entities/ayah_annotation.dart';
import 'package:tilawa/domain/entities/quran_page_mapper.dart';
import 'package:tilawa/presentation/providers/ayah_annotation_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/widgets/mushaf_annotation_overlay.dart';
import 'package:tilawa/presentation/widgets/mushaf_page_image.dart';

class ManuscriptPageView extends ConsumerWidget {
  const ManuscriptPageView({super.key, 
    required this.pageController,
    required this.isDark,
    required this.onPageChanged,
  });

  final PageController pageController;
  final bool isDark;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final baseUrl = ref.watch(apiClientProvider).baseUrl;

    return PageView.builder(
      controller: pageController,
      reverse: true,
      itemCount: 603,
      onPageChanged: onPageChanged,
      itemBuilder: (context, index) {
        final pageNumber = index + 1;
        final actualPageNumber = pageNumber + 1;
        final mapping = ref.watch(mushafPageMappingProvider(actualPageNumber));
        final annotations =
            ref.watch(ayahAnnotationsForPageProvider(actualPageNumber));

        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: ColorFiltered(
                  colorFilter: isDark
                      ? const ColorFilter.matrix([
                          -1,
                          0,
                          0,
                          0,
                          255,
                          0,
                          -1,
                          0,
                          0,
                          255,
                          0,
                          0,
                          -1,
                          0,
                          255,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ])
                      : const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.multiply,
                        ),
                  child: MushafPageImage(
                    pageNumber: actualPageNumber,
                    apiBaseUrl: baseUrl,
                    errorLabel: '${strings.loadPageError} $pageNumber',
                  ),
                ),
              ),
              mapping.when(
                data: (pageMapping) => annotations.when(
                  data: (pageAnnotations) => MushafAnnotationOverlay(
                    mapping: pageMapping,
                    annotations: pageAnnotations,
                    onAyahSelected: (region) =>
                        _showAyahActionSheet(context, ref, region),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAyahActionSheet(
    BuildContext context,
    WidgetRef ref,
    AyahRegion region,
  ) {
    final strings = ref.read(appStringsProvider);
    final noteController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${strings.ayahLabel} ${region.reference.surahNumber}:${region.reference.ayahNumber}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: strings.noteLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _saveAnnotation(
                        context,
                        ref,
                        region,
                        AyahAnnotationType.highlight,
                        AppColors.emerald,
                        noteController.text,
                      ),
                      icon: const Icon(Icons.highlight_rounded),
                      label: Text(strings.highlight),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _saveAnnotation(
                        context,
                        ref,
                        region,
                        AyahAnnotationType.bookmark,
                        AppColors.amber,
                        noteController.text,
                      ),
                      icon: const Icon(Icons.bookmark_add_rounded),
                      label: Text(strings.bookmark),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _saveAnnotation(
                        context,
                        ref,
                        region,
                        AyahAnnotationType.revisionMarker,
                        AppColors.rose,
                        noteController.text,
                      ),
                      icon: const Icon(Icons.flag_rounded),
                      label: Text(strings.revisionMarker),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(noteController.dispose);
  }

  Future<void> _saveAnnotation(
    BuildContext context,
    WidgetRef ref,
    AyahRegion region,
    AyahAnnotationType type,
    Color color,
    String note,
  ) async {
    await ref.read(ayahAnnotationControllerProvider.notifier).saveHighlight(
          reference: region.reference,
          pageNumber: region.pageNumber,
          color: color,
          type: type,
          note: note.trim().isEmpty ? null : note.trim(),
        );
    ref.invalidate(ayahAnnotationsForPageProvider(region.pageNumber));
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
