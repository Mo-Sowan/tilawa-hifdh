import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// A scanned Mushaf page from the Libyan Qaloon edition.
///
/// Pages are requested from the API, which caches them on disk after the first
/// fetch and — importantly for the web build — serves them same-origin. On a
/// native build the downloaded scan is retained on disk, so each page pays the
/// network cost once and remains available after an app restart.
class MushafPageImage extends StatefulWidget {
  const MushafPageImage({
    required this.pageNumber,
    required this.apiBaseUrl,
    this.fit = BoxFit.contain,
    this.errorLabel,
    super.key,
  });

  /// Mushaf page, 1-604.
  final int pageNumber;
  final String apiBaseUrl;
  final BoxFit fit;
  final String? errorLabel;

  static const String _archiveRoot = 'https://archive.org/download/qalooon-jam';

  /// The Mushaf has a fixed 604-page catalogue. Keeping that entire catalogue
  /// prevents an older page from being evicted merely because the reciter has
  /// read through a long section.
  static final CacheManager cacheManager = CacheManager(
    Config(
      'tilawa_mushaf_pages_v1',
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 604,
    ),
  );

  /// The API endpoint that proxies and caches the page.
  static String proxyUrl(String apiBaseUrl, int pageNumber) {
    final base = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;
    return '$base/api/v1/mushaf/page/$pageNumber';
  }

  /// Upstream archive URL. Files run 000.jpg (page 1) to 603.jpg (page 604).
  static String archiveUrl(int pageNumber) =>
      '$_archiveRoot/${(pageNumber - 1).toString().padLeft(3, '0')}.jpg';

  /// Whether to skip the API and fetch straight from the archive.
  ///
  /// Development hosts only exist on the machine running Flutter, so anything
  /// else asking for them waits for a connection that will never be answered
  /// and only then falls back. That wait was the whole reason a Mushaf page
  /// took "ages" to appear: the scan is only ~340 KB, but nothing started
  /// downloading it until localhost had finished timing out.
  ///
  /// This used to exempt the web build, on the assumption that a browser could
  /// not fetch the archive directly. It can — archive.org serves
  /// `Access-Control-Allow-Origin: *` — so the exemption only ever bought a
  /// guaranteed delay.
  static bool shouldUseArchiveFirst(String apiBaseUrl) {
    final host = Uri.tryParse(apiBaseUrl)?.host.toLowerCase();
    return host == null ||
        host.isEmpty ||
        host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '10.0.2.2';
  }

  static String preferredUrl(String apiBaseUrl, int pageNumber) =>
      shouldUseArchiveFirst(apiBaseUrl)
          ? archiveUrl(pageNumber)
          : proxyUrl(apiBaseUrl, pageNumber);

  @override
  State<MushafPageImage> createState() => _MushafPageImageState();
}

class _MushafPageImageState extends State<MushafPageImage> {
  /// Set once the proxy has failed for this page, so the archive is used
  /// directly instead of re-attempting a server that is not there.
  late bool _useArchive;

  @override
  void initState() {
    super.initState();
    _useArchive = MushafPageImage.shouldUseArchiveFirst(widget.apiBaseUrl);
  }

  @override
  void didUpdateWidget(MushafPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiBaseUrl != widget.apiBaseUrl) {
      _useArchive = MushafPageImage.shouldUseArchiveFirst(widget.apiBaseUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _useArchive
        ? MushafPageImage.archiveUrl(widget.pageNumber)
        : MushafPageImage.proxyUrl(widget.apiBaseUrl, widget.pageNumber);

    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: MushafPageImage.cacheManager,
      key: ValueKey(url),
      fit: widget.fit,
      fadeInDuration: const Duration(milliseconds: 160),
      placeholder: (_, __) => const _PageLoading(),
      errorWidget: (context, failedUrl, error) {
        if (!_useArchive) {
          // Fall through to the archive on the next frame; setState during
          // build is not allowed.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _useArchive = true);
          });
          return const _PageLoading();
        }
        return _PageError(label: widget.errorLabel, page: widget.pageNumber);
      },
    );
  }
}

class _PageLoading extends StatelessWidget {
  const _PageLoading();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _PageError extends StatelessWidget {
  const _PageError({required this.label, required this.page});

  final String? label;
  final int page;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 10),
            Text(
              label ?? 'Page $page could not be loaded',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
