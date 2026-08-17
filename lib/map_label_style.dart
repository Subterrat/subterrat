import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

typedef MapLabelFontWaiter = Future<void> Function(TextStyle style);

Future<void> _waitForGoogleFont(TextStyle style) async {
  await GoogleFonts.pendingFonts([style]);
}

/// Returns a Traditional Chinese text style only after its font is ready.
///
/// Map labels are rasterized into PNG markers, so they cannot repaint when a
/// fallback font arrives later like normal Flutter text widgets can.
Future<TextStyle> loadMapLabelTextStyle({
  required double fontSize,
  required Color color,
  MapLabelFontWaiter? waitForFont,
}) async {
  final style = GoogleFonts.notoSansTc(
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    color: color,
  );
  await (waitForFont ?? _waitForGoogleFont)(style);
  return style;
}
