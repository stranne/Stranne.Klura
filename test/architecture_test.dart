@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

// Puzzle rules, generators and solvers stay free of Flutter so they are fast
// to test and compile to JavaScript and WebAssembly unchanged. They draw
// randomness only from SeededRandom so every platform generates the same
// puzzles. See AGENTS.md.
void main() {
  final files = _flutterFreeFiles();

  test('finds the Flutter-free libraries', () {
    expect(files, isNotEmpty);
  });

  test('Flutter-free libraries import only Flutter-free code', () {
    final violations = [
      for (final file in files)
        for (final (line, uri) in _directiveUris(file))
          if (!_isAllowedImport(uri)) '${_path(file)}:$line imports $uri',
    ];

    expect(
      violations,
      isEmpty,
      reason:
          'Code under lib/core/ and lib/puzzles/*/logic/ may import only '
          '${_allowedDartLibraries.join(', ')}, '
          '${_allowedPackageLibraries.join(', ')} and other Flutter-free Klura '
          'code. Allow another package here only if it is pure Dart and runs '
          'on the web.',
    );
  });

  test('Flutter-free libraries draw randomness only from SeededRandom', () {
    final violations = [
      for (final file in files)
        for (final (line, code) in _codeLines(file))
          for (final MapEntry(key: pattern, value: name)
              in _forbiddenRandomness.entries)
            if (pattern.hasMatch(code)) '${_path(file)}:$line uses $name',
    ];

    expect(
      violations,
      isEmpty,
      reason:
          'Use SeededRandom: dart:math Random and List.shuffle do not promise '
          'the same sequence on every platform and SDK release.',
    );
  });
}

const Set<String> _allowedDartLibraries = {
  'dart:async',
  'dart:collection',
  'dart:convert',
  'dart:core',
  'dart:math',
  'dart:typed_data',
};

/// Pure Dart package libraries that run on every web target.
const Set<String> _allowedPackageLibraries = {'package:meta/meta.dart'};

final RegExp _puzzleLogicUri = RegExp('^package:klura/puzzles/[^/]+/logic/');

final RegExp _directive = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
);

final RegExp _blockComment = RegExp(r'/\*.*?\*/', dotAll: true);

final RegExp _lineComment = RegExp('//.*');

final Map<RegExp, String> _forbiddenRandomness = {
  RegExp(r'\bRandom\b'): 'dart:math Random',
  RegExp(r'\.shuffle\(\s*\)'): 'List.shuffle',
};

/// Returns the Dart files under `lib/core/` and `lib/puzzles/*/logic/`.
List<File> _flutterFreeFiles() {
  final puzzles = Directory('lib/puzzles');
  final directories = [
    Directory('lib/core'),
    if (puzzles.existsSync())
      for (final puzzle in puzzles.listSync().whereType<Directory>())
        Directory('${puzzle.path}/logic'),
  ];

  return [
    for (final directory in directories)
      if (directory.existsSync())
        for (final entity in directory.listSync(recursive: true))
          if (entity is File && entity.path.endsWith('.dart')) entity,
  ]..sort((a, b) => a.path.compareTo(b.path));
}

bool _isAllowedImport(String uri) =>
    _allowedDartLibraries.contains(uri) ||
    _allowedPackageLibraries.contains(uri) ||
    uri.startsWith('package:klura/core/') ||
    _puzzleLogicUri.hasMatch(uri);

/// Returns the URI of each import and export in [file] with its line number.
Iterable<(int, String)> _directiveUris(File file) sync* {
  for (final (line, code) in _codeLines(file)) {
    final match = _directive.firstMatch(code);
    if (match != null) {
      yield (line, match[1]!);
    }
  }
}

/// Returns each line of [file] with comments removed, so documentation that
/// mentions a forbidden API does not count as using it.
Iterable<(int, String)> _codeLines(File file) sync* {
  final source = file.readAsStringSync().replaceAllMapped(
    _blockComment,
    (match) => '\n' * '\n'.allMatches(match[0]!).length,
  );
  final lines = source.split('\n');
  for (var index = 0; index < lines.length; index++) {
    yield (index + 1, lines[index].replaceFirst(_lineComment, ''));
  }
}

String _path(File file) => file.path.replaceAll(r'\', '/');
