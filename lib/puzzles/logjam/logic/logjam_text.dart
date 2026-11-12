import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/logjam/logic/logjam_board.dart';

// A small text notation for Logjam boards, used for test fixtures and
// readable failure messages. Each line is a row, one character per cell,
// and the row with the exit ends in `>`:
//
//   *      the marked piece, which leaves through the exit
//   A to Z the other pieces, in the order of the board's pieces
//   .      an empty cell
//
// The cells of a piece form a straight run of two or three, which also shows
// which way it slides. For example, a board of four columns and three rows
// with the marked piece and two others:
//
//   A...
//   A**.>
//   BB..

const String _marked = '*';
const String _empty = '.';
const String _exit = '>';
const int _firstLetter = 0x41;
const int _letterCount = 26;

/// Draws [board] as text, one line for each row with a line break after
/// each.
///
/// Throws an [ArgumentError] if the board has more pieces than letters.
String formatLogjam(LogjamBoard board) {
  if (board.pieces.length > _letterCount + 1) {
    throw ArgumentError.value(
      board,
      'board',
      'Has more than ${_letterCount + 1} pieces',
    );
  }
  final buffer = StringBuffer();
  for (var y = 0; y < board.height; y++) {
    for (var x = 0; x < board.width; x++) {
      buffer.write(switch (board.pieceAt(Position(x, y))) {
        null => _empty,
        0 => _marked,
        final piece => String.fromCharCode(_firstLetter + piece - 1),
      });
    }
    if (y == board.exitRow) {
      buffer.write(_exit);
    }
    buffer.writeln();
  }
  return buffer.toString();
}

/// Reads a board written by [formatLogjam].
///
/// Leading and trailing blank lines are ignored, and so are spaces at the
/// start and end of each line. Throws a [FormatException] if the text is not
/// in that form: rows of one length, pieces as straight runs of two or three
/// cells, letters from A without a gap, and one exit, on the marked piece's
/// row. Throws an [ArgumentError] if the board breaks a rule of
/// [LogjamBoard].
LogjamBoard parseLogjam(String text) {
  final lines = text.split('\n').map((line) => line.trim()).toList();
  while (lines.isNotEmpty && lines.first.isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  if (lines.isEmpty) {
    throw const FormatException('Expected a row of cells on each line');
  }

  final rows = <String>[];
  int? exitRow;
  for (final (y, line) in lines.indexed) {
    if (line.endsWith(_exit)) {
      if (exitRow != null) {
        throw FormatException('Expected one exit', line);
      }
      exitRow = y;
      rows.add(line.substring(0, line.length - 1));
    } else {
      rows.add(line);
    }
  }
  final width = rows.first.length;
  for (final row in rows) {
    if (row.length != width) {
      throw FormatException('Expected $width cells', row);
    }
  }
  if (exitRow == null) {
    throw const FormatException('Expected an exit, ">", after its row');
  }

  final cellsOf = <String, List<Position>>{};
  for (final (y, row) in rows.indexed) {
    for (var x = 0; x < width; x++) {
      final character = row[x];
      if (character == _empty) {
        continue;
      }
      if (character != _marked && _letterIndex(character) == null) {
        throw FormatException('Unknown cell "$character"', row, x);
      }
      (cellsOf[character] ??= []).add(Position(x, y));
    }
  }

  final marked = cellsOf.remove(_marked);
  if (marked == null) {
    throw const FormatException('Expected the marked piece, "*"');
  }
  final letters = cellsOf.keys.map((letter) => _letterIndex(letter)!).toList()
    ..sort();
  for (final (index, letter) in letters.indexed) {
    if (letter != index) {
      throw FormatException(
        'Expected letters from A without a gap',
        String.fromCharCode(_firstLetter + index),
      );
    }
  }

  final pieces = [
    _pieceOf(_marked, marked),
    for (final letter in letters)
      _pieceOf(
        String.fromCharCode(_firstLetter + letter),
        cellsOf[String.fromCharCode(_firstLetter + letter)]!,
      ),
  ];
  if (pieces.first.isHorizontal && pieces.first.y != exitRow) {
    throw FormatException(
      'Expected the exit on the row of the marked piece',
      lines[exitRow],
    );
  }
  return LogjamBoard(width: width, height: rows.length, pieces: pieces);
}

/// The letter's place from A, or `null` if [character] is not a capital
/// letter.
int? _letterIndex(String character) {
  final index = character.codeUnitAt(0) - _firstLetter;
  return character.length == 1 && index >= 0 && index < _letterCount
      ? index
      : null;
}

/// The piece covering [cells], which are in reading order.
LogjamPiece _pieceOf(String name, List<Position> cells) {
  final first = cells.first;
  final length = cells.length;
  final isHorizontal = cells.indexed.every(
    (cell) => cell.$2 == Position(first.x + cell.$1, first.y),
  );
  final isVertical = cells.indexed.every(
    (cell) => cell.$2 == Position(first.x, first.y + cell.$1),
  );
  if (length < LogjamPiece.minLength ||
      length > LogjamPiece.maxLength ||
      !(isHorizontal || isVertical)) {
    throw FormatException(
      'Expected piece "$name" to be a straight run of 2 or 3 cells',
    );
  }
  return isHorizontal
      ? LogjamPiece.horizontal(first.x, first.y, length)
      : LogjamPiece.vertical(first.x, first.y, length);
}
