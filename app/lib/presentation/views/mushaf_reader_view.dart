import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/data/quran/quran_text_index.dart';
import 'package:tilawa/domain/entities/ayah_annotation.dart';
import 'package:tilawa/domain/entities/quran_page_mapper.dart';
import 'package:tilawa/presentation/providers/quran_providers.dart';
import 'package:tilawa/presentation/providers/ayah_annotation_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/widgets/mushaf_annotation_overlay.dart';
import 'package:tilawa/presentation/widgets/mushaf_page_image.dart';

class MushafReaderView extends ConsumerStatefulWidget {
  const MushafReaderView({
    super.key,
    this.initialPage = 1,
  });

  final int initialPage;

  @override
  ConsumerState<MushafReaderView> createState() => _MushafReaderViewState();
}

class _MushafReaderViewState extends ConsumerState<MushafReaderView> {
  late final PageController _pageController;
  int _currentPage = 1;
  bool _isElectronicMode = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<QuranAyah> _searchResults = [];
  bool _searchLoading = false;

  static const int _totalPages = 603;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precachePages(_currentPage);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _precachePages(int currentPage) {
    if (!mounted) return;
    try {
      final baseUrl = ref.read(apiClientProvider).baseUrl;
      for (int offset = -2; offset <= 2; offset++) {
        final pageToCache = currentPage + offset;
        if (pageToCache >= 1 && pageToCache <= _totalPages) {
          final actualPageToCache = pageToCache + 1;
          // Warm the same URL the reader will render, so a swipe is instant.
          precacheImage(
            NetworkImage(MushafPageImage.proxyUrl(baseUrl, actualPageToCache)),
            context,
          ).catchError((_) {
            // Pre-caching is best effort; a miss just means a slower swipe.
          });

          // Pre-fetch electronic page text
          ref.read(quranPageProvider(actualPageToCache).future).catchError((_) {
            return <QuranAyah>[];
          });
        }
      }
    } catch (_) {
      // Fail silently if context or provider is not ready
    }
  }

  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      _pageController.jumpToPage(page - 1);
      setState(() {
        _currentPage = page;
        _isSearching = false;
      });
      _precachePages(page);
    }
  }

  void _showPagePicker(BuildContext context) {
    final strings = ref.read(appStringsProvider);
    final controller = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          strings.goToPage,
          textDirection: strings.isArabic ? TextDirection.rtl : TextDirection.ltr,
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '1 - $_totalPages',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            final page = int.tryParse(val);
            if (page != null && page >= 1 && page <= _totalPages) {
              _goToPage(page);
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= _totalPages) {
                _goToPage(page);
                Navigator.pop(context);
              }
            },
            child: Text(strings.goToPage),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingPageIndicator(BuildContext context, AppStrings strings) {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () => _showPagePicker(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? Colors.black
                          : Colors.white)
                      .withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      strings.isArabic
                          ? 'صفحة $_currentPage من $_totalPages'
                          : 'Page $_currentPage of $_totalPages',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _searchLoading = true);
    try {
      final index = await ref.read(quranTextIndexProvider.future);
      if (!mounted) return;
      final results = index.search(query);
      setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
    } catch (_) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFFDFBF7),
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                textDirection: strings.isArabic ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: strings.searchQuranHint,
                  hintTextDirection: strings.isArabic ? TextDirection.rtl : TextDirection.ltr,
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey[400]),
                ),
                onSubmitted: _performSearch,
              )
            : Text(strings.readFromMushaf),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search_rounded),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchResults = [];
                }
              });
            },
          ),
          IconButton(
            icon: Icon(_isElectronicMode
                ? Icons.image_rounded
                : Icons.text_fields_rounded),
            onPressed: () {
              setState(() => _isElectronicMode = !_isElectronicMode);
            },
            tooltip: _isElectronicMode
                ? strings.manuscriptMode
                : strings.electronicMode,
          ),
        ],
      ),
      body: Stack(
        children: [
          _isSearching && _searchResults.isNotEmpty
              ? _SearchResultsList(
                  results: _searchResults,
                  loading: _searchLoading,
                  onAyahTap: (ayah) {
                    _goToPage(ayah.page);
                    setState(() => _isElectronicMode = true);
                  },
                )
              : _isSearching && _searchLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _isElectronicMode
                      ? _ElectronicPageView(
                          pageNumber: _currentPage,
                          onPageChanged: (p) {
                            setState(() => _currentPage = p);
                            _precachePages(p);
                          },
                        )
                      : _ManuscriptPageView(
                          pageController: _pageController,
                          isDark: isDark,
                          onPageChanged: (index) {
                            final page = index + 1;
                            setState(() => _currentPage = page);
                            _precachePages(page);
                          },
                        ),
          if (!_isSearching)
            _buildFloatingPageIndicator(context, strings),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────

class _ManuscriptPageView extends ConsumerWidget {
  const _ManuscriptPageView({
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

// ──────────────────────────────────────────────────────────────────────────

class _ElectronicPageView extends ConsumerStatefulWidget {
  const _ElectronicPageView({
    required this.pageNumber,
    required this.onPageChanged,
  });

  final int pageNumber;
  final ValueChanged<int> onPageChanged;

  @override
  ConsumerState<_ElectronicPageView> createState() =>
      _ElectronicPageViewState();
}

class _ElectronicPageViewState extends ConsumerState<_ElectronicPageView> {
  late PageController _ePageController;

  @override
  void initState() {
    super.initState();
    _ePageController = PageController(initialPage: widget.pageNumber - 1);
  }

  @override
  void didUpdateWidget(_ElectronicPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageNumber != oldWidget.pageNumber) {
      final pageIndex = widget.pageNumber - 1;
      if (_ePageController.hasClients && _ePageController.page?.round() != pageIndex) {
        _ePageController.jumpToPage(pageIndex);
      }
    }
  }

  @override
  void dispose() {
    _ePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _ePageController,
      reverse: true,
      itemCount: 603,
      onPageChanged: (index) => widget.onPageChanged(index + 1),
      itemBuilder: (context, index) {
        final pageNum = index + 1;
        return _ElectronicSinglePage(pageNumber: pageNum);
      },
    );
  }
}

class _ElectronicSinglePage extends ConsumerWidget {
  const _ElectronicSinglePage({required this.pageNumber});
  final int pageNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageData = ref.watch(quranPageProvider(pageNumber + 1));
    final revisionData = ref.watch(revisionOverviewProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = ref.watch(appStringsProvider);

    return pageData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('${strings.loadPageError}: $e',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(quranPageProvider(pageNumber + 1)),
                icon: const Icon(Icons.refresh),
                label: Text(strings.retry),
              ),
            ],
          ),
        ),
      ),
      data: (ayahs) {
        // Get mastery data for highlighting
        final masteryMap = <int, double>{};
        revisionData.whenData((surahs) {
          for (final s in surahs) {
            masteryMap[s.number] = s.mastery;
          }
        });

        // Group ayahs by surah
        final groupedBySurah = <int, List<QuranAyah>>{};
        for (final ayah in ayahs) {
          groupedBySurah.putIfAbsent(ayah.surah, () => []).add(ayah);
        }

        final juz = ayahs.isNotEmpty ? ayahs.first.juz : 1;

        final pageColor = isDark ? const Color(0xFF1A1612) : const Color(0xFFFFF8EE);
        final borderColor = isDark
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)
            : const Color(0xFFD4A574);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80), // leaves space for floating page indicator
          child: Column(
            children: [
              // Juz header
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${strings.juzLabel} $juz  •  ${strings.pageLabel} $pageNumber',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),

              // Page frame filling remaining height
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: pageColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                        blurRadius: 16,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Inner border frame
                      Positioned.fill(
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: borderColor.withValues(alpha: 0.5), width: 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      
                      // Content inside a scrollable view within the frame boundaries
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Render each surah group
                                for (final entry in groupedBySurah.entries) ...[
                                  // Surah header (only if the first ayah is ayah 1, meaning a new surah starts)
                                  if (entry.value.first.ayah == 1) ...[
                                    _SurahHeader(
                                      surahName: entry.value.first.surahName,
                                      surahEnglishName: entry.value.first.surahNameEn,
                                      surahNumber: entry.key,
                                    ),
                                    // Bismillah (not for Surah At-Tawbah #9, and not for Al-Fatiha since it's part of the surah)
                                    if (entry.key != 9 && entry.key != 1)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Text(
                                          'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: AppTheme.quranFontFamily,
                                            fontSize: 24,
                                            color: Theme.of(context).colorScheme.primary,
                                            height: 2.0,
                                          ),
                                        ),
                                      ),
                                  ],

                                  // Render ayahs in a justified paragraph
                                  RichText(
                                    textAlign: TextAlign.justify,
                                    textDirection: TextDirection.rtl,
                                    text: TextSpan(
                                      children: entry.value.map((ayah) {
                                        final mastery = masteryMap[ayah.surah] ?? 0.05;
                                        final highlightColor = _getMasteryHighlight(mastery, isDark);

                                        return TextSpan(
                                          text: '${ayah.textUthmani} ﴿${_convertToArabicNumber(ayah.ayah)}﴾ ',
                                          style: TextStyle(
                                            fontFamily: AppTheme.quranFontFamily,
                                            fontSize: 26,
                                            height: 2.2,
                                            color: isDark
                                                ? AppColors.textPrimary
                                                : AppColors.lightTextPrimary,
                                            backgroundColor: highlightColor,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 12), // Space between surahs on same page
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _convertToArabicNumber(int number) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String result = number.toString();
    for (int i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], arabic[i]);
    }
    return result;
  }

  Color _getMasteryHighlight(double mastery, bool isDark) {
    if (mastery < 0.3) {
      return AppColors.rose.withValues(alpha: isDark ? 0.15 : 0.1);
    } else if (mastery < 0.7) {
      return AppColors.amber.withValues(alpha: isDark ? 0.12 : 0.08);
    } else {
      return AppColors.emerald.withValues(alpha: isDark ? 0.12 : 0.08);
    }
  }

}

// ──────────────────────────────────────────────────────────────────────────

class _SurahHeader extends StatelessWidget {
  const _SurahHeader({
    required this.surahName,
    required this.surahEnglishName,
    required this.surahNumber,
  });

  final String surahName;
  final String surahEnglishName;
  final int surahNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Surah number badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Center(
              child: Text(
                '$surahNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  surahEnglishName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          Text(
            surahName,
            style: AppTheme.arabicText(
              size: 28,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────

class _SearchResultsList extends ConsumerWidget {
  const _SearchResultsList({
    required this.results,
    required this.loading,
    required this.onAyahTap,
  });

  final List<QuranAyah> results;
  final bool loading;
  final ValueChanged<QuranAyah> onAyahTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final ayah = results[index];
        return Card(
          child: InkWell(
            onTap: () => onAyahTap(ayah),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Surah info
                  Row(
                    children: [
                      Icon(Icons.menu_book_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${strings.isArabic ? ayah.surahName : ayah.surahNameEn} - ${strings.ayahLabel} ${ayah.ayah}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        '${strings.pageLabel} ${ayah.page}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Ayah text
                  Text(
                    ayah.textUthmani,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: AppTheme.quranFontFamily,
                      fontSize: 20,
                      height: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}


