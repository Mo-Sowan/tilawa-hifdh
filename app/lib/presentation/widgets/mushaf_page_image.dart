import 'package:flutter/material.dart';

/// A scanned Mushaf page from the Libyan Qaloon edition.
///
/// Pages are requested from the API, which caches them on disk after the first
/// fetch and — importantly for the web build — serves them same-origin. When
/// the API is unreachable the widget falls back to the public archive so the
/// reader still works offline of the backend.
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

  @override
  State<MushafPageImage> createState() => _MushafPageImageState();
}

class _MushafPageImageState extends State<MushafPageImage> {
  /// Set once the proxy has failed for this page, so the archive is used
  /// directly instead of re-attempting a server that is not there.
  bool _useArchive = false;

  @override
  void didUpdateWidget(MushafPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiBaseUrl != widget.apiBaseUrl) _useArchive = false;
  }

  @override
  Widget build(BuildContext context) {
    final url = _useArchive
        ? MushafPageImage.archiveUrl(widget.pageNumber)
        : MushafPageImage.proxyUrl(widget.apiBaseUrl, widget.pageNumber);

    return Image.network(
      url,
      key: ValueKey(url),
      fit: widget.fit,
      // On the web an XHR fetch is blocked by the archive's missing CORS
      // headers; retrying through a plain <img> element renders it anyway.
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const _PageLoading(),
      errorBuilder: (context, error, stackTrace) {
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
