import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa/main.dart';

void main() {
  testWidgets('app boots and renders a MaterialApp', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TilawaApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
