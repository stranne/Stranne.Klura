import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klura/app/klura_theme.dart';

// The web shell paints before Flutter has loaded. Its colors must match the
// theme, otherwise the hand-over from the loading screen to the app flashes.
void main() {
  final light = buildKluraTheme(Brightness.light).colorScheme;
  final dark = buildKluraTheme(Brightness.dark).colorScheme;

  test('index.html uses the theme surface and primary colors', () {
    final html = File('web/index.html').readAsStringSync();

    final colors = {
      for (final match in RegExp('#[0-9A-Fa-f]{6}').allMatches(html))
        match[0]!.toUpperCase(),
    };

    expect(colors, {
      _hex(light.surface),
      _hex(light.primary),
      _hex(dark.surface),
      _hex(dark.primary),
    });
  });

  test('manifest.json uses the light surface color', () {
    final manifest = jsonDecode(
      File('web/manifest.json').readAsStringSync(),
    ) as Map<String, Object?>;

    expect(manifest['background_color'], _hex(light.surface));
    expect(manifest['theme_color'], _hex(light.surface));
  });

  // The mark is drawn by hand in each file, so a change to one must be copied
  // to the others.
  test('the icons and the loading screen draw the same mark', () {
    final icon = _markShapes('design/icon/icon.svg');

    expect(icon, isNotEmpty);
    expect(_markShapes('design/icon/icon-full-bleed.svg'), icon);
    expect(_markShapes('web/index.html'), icon);
  });
}

/// Returns the geometry of the mark's paths and circles in [path], in order.
List<String> _markShapes(String path) => [
  for (final match in RegExp(
    r'\b(?:d|cx|cy|r)="[^"]*"',
  ).allMatches(File(path).readAsStringSync()))
    match[0]!,
];

String _hex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
