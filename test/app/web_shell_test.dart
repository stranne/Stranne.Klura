import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klura/app/klura_theme.dart';
import 'package:material_ui/material_ui.dart';

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

  // The policy names no other site, so anything Flutter would fetch from
  // Google by default has to come from this site instead.
  test('index.html lets the page load files from this site only', () {
    final policy = _contentSecurityPolicy();

    expect(policy['default-src'], ["'self'"]);
    for (final MapEntry(key: directive, value: sources) in policy.entries) {
      for (final source in sources) {
        // Only keywords and hashes, which are quoted; no hosts or schemes.
        expect(source, matches(r"^'[^']+'$"), reason: directive);
      }
    }
  });

  test('flutter_bootstrap.js loads CanvasKit from this site', () {
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();

    expect(bootstrap, contains("canvasKitBaseUrl: 'canvaskit/'"));
  });

  // The web engine downloads Roboto unless the app has a family of that name.
  test('the app bundles the Roboto font', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('- family: Roboto'));
    expect(File('fonts/roboto/Roboto-Regular.woff2').existsSync(), isTrue);
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

/// The content security policy of web/index.html, as the sources of each
/// directive.
Map<String, List<String>> _contentSecurityPolicy() {
  final html = File('web/index.html').readAsStringSync();
  final policy = RegExp(
    '<meta http-equiv="Content-Security-Policy" content="([^"]*)">',
  ).firstMatch(html)![1]!;
  return {
    for (final directive in policy.split(';'))
      if (directive.trim().split(' ') case [final name, ...final sources])
        name: sources,
  };
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
