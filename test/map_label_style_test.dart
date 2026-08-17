import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:subterrat_app/map_label_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('map label style waits for the Traditional Chinese font', () async {
    final releaseFont = Completer<void>();
    TextStyle? requestedStyle;
    var completed = false;

    final future = loadMapLabelTextStyle(
      fontSize: 33,
      color: Colors.brown,
      waitForFont: (style) async {
        requestedStyle = style;
        await releaseFont.future;
      },
    )..then((_) => completed = true);

    await Future<void>.delayed(Duration.zero);

    expect(requestedStyle, isNotNull);
    expect(
      requestedStyle!.fontFamily!.replaceAll(' ', '').toLowerCase(),
      contains('notosanstc'),
    );
    expect(completed, isFalse);

    releaseFont.complete();
    final style = await future;

    expect(completed, isTrue);
    expect(style.fontWeight, FontWeight.w700);
  });
}
