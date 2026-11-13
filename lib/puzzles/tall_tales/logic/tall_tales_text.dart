import 'package:klura/puzzles/tall_tales/logic/tall_tales_marks.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_puzzle.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_wording.dart';

// A small text notation for Tall Tales puzzles, used for test fixtures and
// readable failure messages. Each line is a fisher, in the order they sit:
// a mark, the fisher's name, a colon and their statement as the player
// reads it. The marks are:
//
//   +  tells the truth
//   -  tells tall tales
//   .  unmarked
//
// A puzzle without marks may leave them out. For example, three fishers
// with Alva marked as telling the truth:
//
//   + Alva: Bo tells the truth.
//   . Bo: Cajsa and I are not alike.
//   . Cajsa: At least one of Alva and me tells tall tales.

const String _truth = '+';
const String _tallTales = '-';
const String _unmarked = '.';

/// Writes [puzzle] as text, one line for each fisher with a line break
/// after each, and with [marks] if given.
///
/// Throws an [ArgumentError] if [marks] is not for as many fishers as
/// [puzzle] has.
String formatTallTales(TallTalesPuzzle puzzle, [TallTalesMarks? marks]) {
  if (marks != null && marks.length != puzzle.fisherCount) {
    throw ArgumentError.value(
      marks,
      'marks',
      'Must mark the ${puzzle.fisherCount} fishers of the puzzle',
    );
  }
  final buffer = StringBuffer();
  for (var fisher = 0; fisher < puzzle.fisherCount; fisher++) {
    if (marks != null) {
      final mark = switch (marks[fisher]) {
        TallTalesMark.truth => _truth,
        TallTalesMark.tallTales => _tallTales,
        null => _unmarked,
      };
      buffer.write('$mark ');
    }
    buffer.writeln(
      '${tallTalesNames[fisher]}: '
      '${statementText(puzzle.statements[fisher])}',
    );
  }
  return buffer.toString();
}

/// Reads a puzzle and its marks written by [formatTallTales]. Blank lines
/// and spaces around a line are ignored.
///
/// Throws a [FormatException] if a line is not a fisher's statement, the
/// fishers are not named in the order they sit, or a statement is not one
/// their speaker can make. Throws an [ArgumentError] if the number of
/// fishers is out of range.
(TallTalesPuzzle, TallTalesMarks) parseTallTales(String text) {
  final lines = [
    for (final line in text.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];
  final fishers = lines.length;
  if (fishers < TallTalesPuzzle.minFishers ||
      fishers > TallTalesPuzzle.maxFishers) {
    throw ArgumentError.value(
      fishers,
      'text',
      'Needs ${TallTalesPuzzle.minFishers} to ${TallTalesPuzzle.maxFishers} '
          'fishers',
    );
  }

  final statements = <TallTalesStatement>[];
  final marks = <TallTalesMark?>[];
  for (var fisher = 0; fisher < fishers; fisher++) {
    final line = lines[fisher];
    final match = _line.firstMatch(line);
    if (match == null) {
      throw FormatException('Not a fisher and their statement', line);
    }
    if (match[2] != tallTalesNames[fisher]) {
      throw FormatException(
        'Expected ${tallTalesNames[fisher]} in place ${fisher + 1}',
        line,
      );
    }
    final sentence = match[3]!;
    final statement = possibleStatements(
      fisher,
      fishers,
    ).where((statement) => statementText(statement) == sentence).firstOrNull;
    if (statement == null) {
      throw FormatException('Not a statement ${match[2]} can make', line);
    }
    statements.add(statement);
    marks.add(switch (match[1]) {
      _truth => TallTalesMark.truth,
      _tallTales => TallTalesMark.tallTales,
      _ => null,
    });
  }
  return (TallTalesPuzzle(statements), TallTalesMarks(marks));
}

final RegExp _line = RegExp(r'^(?:([+.-])\s+)?([A-Za-z]+):\s+(.+)$');
