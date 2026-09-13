import 'package:flutter/material.dart';

import 'package:tilawa/core/utils/file_exporter_io.dart'
    if (dart.library.js_interop) 'package:tilawa/core/utils/file_exporter_web.dart' as impl;

/// Hands an export to the user in whatever way the platform allows.
///
/// Native builds write the file into the documents directory and report the
/// path; the web build triggers a browser download.
Future<void> exportFileAndDownload(
  BuildContext context,
  String content,
  String filename,
  String mimeType,
) {
  return impl.exportFile(context, content, filename, mimeType);
}
