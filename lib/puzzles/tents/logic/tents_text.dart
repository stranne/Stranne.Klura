import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/tents/logic/tents_marks.dart';
import 'package:klura/puzzles/tents/logic/tents_puzzle.dart';

// A small text notation for Tents boards, used for test fixtures and
// readable failure messages. The first line holds the number of tents in
// each column after two spaces. Each further line is a row: its number of
// tents, a space and one character per cell:
//
//   T  a tree
//   ^  a tent
//   -  grass
//   .  an empty cell
//
// For example, a board of three columns and two rows with two trees, one
// tent and grass on two cells:
//
//     101
//   1 T^.
//   1 --T

const String _tree = 'T';
const String _tent = '^';
const String _grass = '-';
const String _empty = '.';

/// Draws [puzzle] with [marks] as text, one line for the column numbers and
/// one for each row, with a line break after each.
///
/// Throws an [ArgumentError] if a number has more than one digit or a mark
/// lies on a tree or outside the board.
String formatTents(
  TentsPuzzle puzzle, [
  TentsMarks marks = const TentsMarks.empty(),
]) {
  for (final position in marks.marks.keys) {
    if (!puzzle.contains(position) || puzzle.hasTree(position)) {
      throw ArgumentError.value(
        position,
        'marks',
        'Must be a free cell of the puzzle',
      );
    }
  }

  final buffer = StringBuffer('  ');
  for (final count in puzzle.columnTents) {
    buffer.write(_digit(count));
  }
  buffer.writeln();
  for (var y = 0; y < puzzle.height; y++) {
    buffer.write('${_digit(puzzle.rowTents[y])} ');
    for (var x = 0; x < puzzle.width; x++) {
      final position = Position(x, y);
      buffer.write(
        puzzle.hasTree(position)
            ? _tree
            : switch (marks[position]) {
                TentsMark.tent => _tent,
                TentsMark.grass => _grass,
                null => _empty,
              },
      );
    }
    buffer.writeln();
  }
  return buffer.toString();
}

/// Reads a board written by [formatTents]: the puzzle and the player's
/// marks on it.
///
/// Leading and trailing blank lines are ignored. Throws a [FormatException]
/// if the text is not in that form, and an [ArgumentError] if the board
/// breaks a rule of [TentsPuzzle].
(TentsPuzzle, TentsMarks) parseTents(String text) {
  final lines = text.split('\n').map((line) => line.trimRight()).toList();
  while (lines.isNotEmpty && lines.first.isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  if (lines.length < 2 || !lines.first.startsWith('  ')) {
    throw const FormatException(
      'Expected a line of column numbers after two spaces, then the rows',
    );
  }

  final columnTents = [
    for (final character in lines.first.substring(2).split(''))
      _parseDigit(character, lines.first),
  ];
  final width = columnTents.length;
  final rowTents = <int>[];
  final trees = <Position>[];
  final marks = <Position, TentsMark>{};
  for (final (y, line) in lines.skip(1).indexed) {
    if (line.length != width + 2 || line[1] != ' ') {
      throw FormatException(
        'Expected a number, a space and $width cells',
        line,
      );
    }
    rowTents.add(_parseDigit(line[0], line));
    for (var x = 0; x < width; x++) {
      final position = Position(x, y);
      switch (line[x + 2]) {
        case _tree:
          trees.add(position);
        case _tent:
          marks[position] = TentsMark.tent;
        case _grass:
          marks[position] = TentsMark.grass;
        case _empty:
          break;
        case final character:
          throw FormatException('Unknown cell "$character"', line, x + 2);
      }
    }
  }

  final puzzle = TentsPuzzle(
    width: width,
    height: rowTents.length,
    trees: trees,
    rowTents: rowTents,
    columnTents: columnTents,
  );
  return (puzzle, TentsMarks(marks));
}

String _digit(int count) {
  if (count > 9) {
    throw ArgumentError.value(count, 'puzzle', 'Has a number above 9');
  }
  return '$count';
}

int _parseDigit(String character, String line) {
  final digit = int.tryParse(character);
  if (digit == null || character.length != 1) {
    throw FormatException('Expected a digit, not "$character"', line);
  }
  return digit;
}
