import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Triggers a browser download by clicking a temporary object URL.
Future<void> exportFile(
  BuildContext context,
  String content,
  String filename,
  String mimeType,
) async {
  final messenger = ScaffoldMessenger.of(context);
  String? url;
  try {
    final blob = web.Blob(
      [utf8.encode(content).toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    url = web.URL.createObjectURL(blob);

    (web.document.createElement('a') as web.HTMLAnchorElement)
      ..href = url
      ..download = filename
      ..click();

    messenger.showSnackBar(SnackBar(content: Text('Downloaded $filename')));
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not download $filename: $error')),
    );
  } finally {
    if (url != null) web.URL.revokeObjectURL(url);
  }
}
