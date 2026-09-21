import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recitation lives under the feature root', () {
    expect(
      Directory('lib/features/recitation').existsSync(),
      isTrue,
      reason: 'Recitation is a feature and must live under lib/features.',
    );
    expect(
      Directory('lib/recitation').existsSync(),
      isFalse,
      reason: 'The legacy top-level recitation folder must not return.',
    );
  });
}
