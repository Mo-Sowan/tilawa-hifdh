import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Writes the export into the documents directory, where a file manager can
/// reach it, and tells the user where it landed.
Future<void> exportFile(
  BuildContext context,
  String content,
  String filename,
  String mimeType,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$filename');
    await file.writeAsString(content, flush: true);

    messenger.showSnackBar(
      SnackBar(
        content: Text('Saved to ${file.path}'),
        duration: const Duration(seconds: 6),
      ),
    );
  } on Exception catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not save $filename: $error')),
    );
  }
}
