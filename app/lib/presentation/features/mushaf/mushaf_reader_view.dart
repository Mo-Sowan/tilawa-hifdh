import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/data/quran/quran_text_index.dart';
import 'package:tilawa/presentation/providers/quran_providers.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/widgets/mushaf_page_image.dart';
import 'package:tilawa/presentation/features/mushaf/widgets/manuscript_page_view.dart';
import 'package:tilawa/presentation/features/mushaf/widgets/search_results_list.dart';

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
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<QuranAyah> _searchResults = [];
  bool _searchLoading = false;

  static const int _totalPages = 603;
  int _precacheGeneration = 0;

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

  Future<void> _precachePages(int currentPage) async {
    if (!mounted) return;
    final generation = ++_precacheGeneration;
    try {
      final baseUrl = ref.read(apiClientProvider).baseUrl;
      // Let the visible page get the connection first. Loading five scans at
      // once made a cold page slower on ordinary mobile connections.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      for (final offset in const [1, -1]) {
        if (!mounted || generation != _precacheGeneration) return;
        final pageToCache = currentPage + offset;
        if (pageToCache >= 1 && pageToCache <= _totalPages) {
          final actualPageToCache = pageToCache + 1;
          await precacheImage(
            CachedNetworkImageProvider(
              MushafPageImage.preferredUrl(baseUrl, actualPageToCache),
              cacheManager: MushafPageImage.cacheManager,
            ),
            context,
          ).catchError((_) {});
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
          textDirection:
              strings.isArabic ? TextDirection.rtl : TextDirection.ltr,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? Colors.black
                          : Colors.white)
                      .withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.2),
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
                textDirection:
                    strings.isArabic ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: strings.searchQuranHint,
                  hintTextDirection:
                      strings.isArabic ? TextDirection.rtl : TextDirection.ltr,
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
        ],
      ),
      body: Stack(
        children: [
          _isSearching && _searchResults.isNotEmpty
              ? SearchResultsList(
                  results: _searchResults,
                  loading: _searchLoading,
                  onAyahTap: (ayah) {
                    _goToPage(ayah.page);
                  },
                )
              : _isSearching && _searchLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ManuscriptPageView(
                      pageController: _pageController,
                      isDark: isDark,
                      onPageChanged: (index) {
                        final page = index + 1;
                        setState(() => _currentPage = page);
                        _precachePages(page);
                      },
                    ),
          if (!_isSearching) _buildFloatingPageIndicator(context, strings),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────

// ──────────────────────────────────────────────────────────────────────────

// ──────────────────────────────────────────────────────────────────────────

// ──────────────────────────────────────────────────────────────────────────
