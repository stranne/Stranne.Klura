import 'package:klura/core/grid.dart';
import 'package:klura/core/puzzle_game.dart';
import 'package:klura/puzzles/tents/logic/tents_marks.dart';
import 'package:klura/puzzles/tents/logic/tents_puzzle.dart';
import 'package:klura/puzzles/tents/logic/tents_rules.dart';
import 'package:meta/meta.dart';

/// A game of Tents in progress: a puzzle, the player's tents and grass and
/// every earlier board to undo to.
///
/// A game is a value. Each move returns a new game that remembers the one
/// before it, so undo reaches back to the first move. A move that changes
/// nothing returns the same game.
///
/// Once solved it takes no more moves and cannot be undone; [reset] starts
/// it over.
@immutable
final class TentsGame implements PuzzleGame {
  /// Starts a game of [puzzle] with [marks], none by default, and nothing to
  /// undo.
  ///
  /// Throws an [ArgumentError] if a mark lies outside the board or on a
  /// tree.
  TentsGame(TentsPuzzle puzzle, [TentsMarks marks = const TentsMarks.empty()])
    : this._(puzzle, marks, null);

  TentsGame._(this.puzzle, this.marks, this._previous)
    : check = checkTents(puzzle, marks);

  final TentsPuzzle puzzle;

  /// The player's tents and grass.
  final TentsMarks marks;

  /// How [marks] fare against the rules.
  final TentsCheck check;

  /// The game before the last move, or `null` before the first.
  final TentsGame? _previous;

  @override
  bool get isSolved => check.isSolved;

  @override
  bool get isBlank => marks.isEmpty;

  @override
  bool get canUndo => _previous != null && !isSolved;

  @override
  bool get canReset => !marks.isEmpty;

  /// The mark [cycleMark] would leave on [position], in the cycle empty,
  /// grass, tent, empty.
  ///
  /// Grass comes before the tent, so a cell on its way to a tent passes a
  /// harmless note rather than a tent that may break a rule for a moment.
  TentsMark? nextMark(Position position) => switch (marks[position]) {
    null => TentsMark.grass,
    TentsMark.grass => TentsMark.tent,
    TentsMark.tent => null,
  };

  /// Returns the game with the next mark on [position], in the cycle empty,
  /// grass, tent, empty.
  ///
  /// Returns this game unchanged if it is solved. Throws an [ArgumentError]
  /// if [position] lies outside the board or holds a tree.
  TentsGame cycleMark(Position position) {
    _checkFreeCell(position);
    if (isSolved) {
      return this;
    }
    return TentsGame._(
      puzzle,
      marks.withMark([position], nextMark(position)),
      this,
    );
  }

  /// The cells of [positions] that [fillGrass] would cover: the empty ones,
  /// in the order given.
  List<Position> fillableCells(Iterable<Position> positions) => [
    for (final position in positions)
      if (!puzzle.hasTree(position) && marks[position] == null) position,
  ];

  /// The cells of [positions] that [clearGrass] would empty: those with
  /// grass, in the order given.
  List<Position> grassCells(Iterable<Position> positions) => [
    for (final position in positions)
      if (marks[position] == TentsMark.grass) position,
  ];

  /// Returns the game with grass on every empty cell of [positions], as one
  /// move. Trees, tents and grass stay as they are.
  ///
  /// Returns this game unchanged if it is solved or no cell changes. Throws
  /// an [ArgumentError] if a cell lies outside the board.
  TentsGame fillGrass(Iterable<Position> positions) =>
      _markAll(positions, fillableCells, TentsMark.grass);

  /// Returns the game with the grass cleared from every cell of [positions],
  /// as one move. Trees and tents stay as they are.
  ///
  /// Returns this game unchanged if it is solved or no cell changes. Throws
  /// an [ArgumentError] if a cell lies outside the board.
  TentsGame clearGrass(Iterable<Position> positions) =>
      _markAll(positions, grassCells, null);

  /// Returns the game as it was before the last move, or this game if there
  /// was none or it is solved.
  TentsGame undo() => canUndo ? _previous! : this;

  /// Returns the game with every tent and all grass cleared, or this game if
  /// it has none.
  ///
  /// The reset is a move like any other, so [undo] brings the marks back.
  TentsGame reset() =>
      canReset ? TentsGame._(puzzle, const TentsMarks.empty(), this) : this;

  TentsGame _markAll(
    Iterable<Position> positions,
    List<Position> Function(Iterable<Position>) cellsToChange,
    TentsMark? mark,
  ) {
    final cells = positions.toList();
    for (final position in cells) {
      if (!puzzle.contains(position)) {
        throw ArgumentError.value(position, 'positions', 'Lies off the board');
      }
    }
    final changed = cellsToChange(cells);
    if (isSolved || changed.isEmpty) {
      return this;
    }
    return TentsGame._(puzzle, marks.withMark(changed, mark), this);
  }

  void _checkFreeCell(Position position) {
    if (!puzzle.contains(position) || puzzle.hasTree(position)) {
      throw ArgumentError.value(
        position,
        'position',
        'Must be a free cell of the puzzle',
      );
    }
  }
}
