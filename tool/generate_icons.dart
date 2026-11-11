import 'dart:io';

/// Renders the web icons in `web/` from the SVG sources in `design/icon/`.
///
/// Run from the repository root after editing a source:
///
/// ```sh
/// dart run tool/generate_icons.dart
/// ```
///
/// Requires ImageMagick 7 with SVG support (`magick` on `PATH`).
Future<void> main() async {
  File('$_sourceDirectory/icon.svg').copySync('web/favicon.svg');
  stdout.writeln('Copied web/favicon.svg');

  for (final icon in _icons) {
    await _render(icon);
  }
}

const String _sourceDirectory = 'design/icon';

/// A square PNG of `size` pixels rendered from `source` into `output`.
typedef _Icon = ({String source, String output, int size});

const List<_Icon> _icons = [
  (source: 'icon.svg', output: 'web/favicon.png', size: 32),
  (source: 'icon.svg', output: 'web/icons/Icon-192.png', size: 192),
  (source: 'icon.svg', output: 'web/icons/Icon-512.png', size: 512),
  (
    source: 'icon-full-bleed.svg',
    output: 'web/icons/Icon-maskable-192.png',
    size: 192,
  ),
  (
    source: 'icon-full-bleed.svg',
    output: 'web/icons/Icon-maskable-512.png',
    size: 512,
  ),
  (
    source: 'icon-full-bleed.svg',
    output: 'web/icons/apple-touch-icon.png',
    size: 180,
  ),
];

Future<void> _render(_Icon icon) async {
  final result = await Process.run('magick', [
    '-background',
    'none',
    '-size',
    '${icon.size}x${icon.size}',
    '$_sourceDirectory/${icon.source}',
    // Leave out metadata and timestamps so unchanged icons render to
    // identical files and do not show up as changes.
    '-strip',
    '-define',
    'png:exclude-chunks=date,time',
    'png32:${icon.output}',
  ]);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    exit(result.exitCode);
  }
  stdout.writeln('Rendered ${icon.output}');
}
