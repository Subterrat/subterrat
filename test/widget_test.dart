import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:subterrat_app/theme.dart';

void main() {
  testWidgets('buildTheme() produces a usable MaterialApp theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const SizedBox()),
    );
    await tester.pump();

    final exception = tester.takeException();
    expect(exception, isNull, reason: exception.toString());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
