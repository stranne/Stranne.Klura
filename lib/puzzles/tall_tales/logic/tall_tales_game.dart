import 'package:klura/core/puzzle_game.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_marks.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_puzzle.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_rules.dart';
import 'package:meta/meta.dart';

/// A game of Tall Tales in progress: a puzzle, the player's marks and every
/// earlier set of marks to undo to.
///
/// A game is a value. Each move returns a new game that remembers the one
/// before it, so undo reaches back to the first move.
///
/// Once solved it takes no more moves and cannot be undone; [reset] starts
/// it over.
@immutable
final class TallTalesGame implements PuzzleGame {
  /// Starts a game of [puzzle] with [marks], none by default, and nothing to
  /// undo.
  ///
  /// Throws an [ArgumentError] if [marks] is not for as many fishers as
  /// [puzzle] has.
  TallTalesGame(TallTalesPuzzle puzzle, [TallTalesMarks? marks])
    : this._(puzzle, marks ?? TallTalesMarks.empty(puzzle.fisherCount), null);

  TallTalesGame._(this.puzzle, this.marks, this._previous)
    : check = checkTallTales(puzzle, marks);

  final TallTalesPuzzle puzzle;

  /// The player's marks.
  final TallTalesMarks marks;

  /// How [marks] fare against the statements.
  final TallTalesCheck check;

  /// The game before the last move, or `null` before the first.
  final TallTalesGame? _previous;

  @override
  bool get isSolved => check.isSolved;

  @override
  bool get isBlank => marks.isEmpty;

  @override
  bool get canUndo => _previous != null && !isSolved;

  @override
  bool get canReset => !marks.isEmpty;

  /// The mark [cycleMark] would leave on [fisher], in the cycle unmarked,
  /// the truth, tall tales, unmarked.
  TallTalesMark? nextMark(int fisher) => switch (marks[fisher]) {
    null => TallTalesMark.truth,
    TallTalesMark.truth => TallTalesMark.tallTales,
    TallTalesMark.tallTales => null,
  };

  /// Returns the game with the next mark on [fisher], in the cycle
  /// unmarked, the truth, tall tales, unmarked.
  ///
  /// Returns this game unchanged if it is solved. Throws a [RangeError] if
  /// [fisher] is not on the jetty.
  TallTalesGame cycleMark(int fisher) {
    RangeError.checkValidIndex(fisher, marks.marks, 'fisher');
    if (isSolved) {
      return this;
    }
    return TallTalesGame._(
      puzzle,
      marks.withMark(fisher, nextMark(fisher)),
      this,
    );
  }

  /// Returns the game as it was before the last move, or this game if there
  /// was none or it is solved.
  TallTalesGame undo() => canUndo ? _previous! : this;

  /// Returns the game with every mark cleared, or this game if it has none.
  ///
  /// The reset is a move like any other, so [undo] brings the marks back.
  TallTalesGame reset() => canReset
      ? TallTalesGame._(
          puzzle,
          TallTalesMarks.empty(puzzle.fisherCount),
          this,
        )
      : this;
}
