import 'package:klura/core/puzzle_game.dart';
import 'package:klura/puzzles/logjam/logic/logjam_board.dart';
import 'package:meta/meta.dart';

/// A game of Logjam in progress: a puzzle, the board as the player's moves
/// have left it, those moves and every earlier game to undo to.
///
/// A move slides one log any distance. Slides of the same log one after
/// another count as one move, as the solver counts them: a slide joins the
/// move before it when that move slid the same log, and a log slid back to
/// where that move began takes the move back. So [moves] never holds two
/// moves of one log in a row, and a solved game never has fewer moves than
/// the puzzle needs.
///
/// A game is a value. Each move returns a new game that remembers the one
/// before it, so undo reaches back to the first move, and an undo after
/// joined slides takes them all back. A move that changes nothing returns
/// the same game.
///
/// Once solved it takes no more moves and cannot be undone; [reset] starts
/// it over.
@immutable
final class LogjamGame implements PuzzleGame {
  /// Starts a game of [puzzle] and plays [moves] on it, so [undo] can take
  /// each of them back.
  ///
  /// Throws an [ArgumentError] if a move is not legal where it is played or
  /// comes after the puzzle is solved.
  factory LogjamGame(
    LogjamBoard puzzle, [
    Iterable<LogjamMove> moves = const [],
  ]) {
    var game = LogjamGame._(puzzle, puzzle, const [], null);
    for (final move in moves) {
      if (game.isSolved) {
        throw ArgumentError.value(move, 'moves', 'Comes after the solve');
      }
      game = game.slide(move);
    }
    return game;
  }

  const LogjamGame._(this.puzzle, this.board, this.moves, this._previous);

  /// The board the puzzle starts from.
  final LogjamBoard puzzle;

  /// The board as the moves have left it.
  final LogjamBoard board;

  /// The moves since the start or the last start over, slides of the same
  /// log one after another joined into one.
  final List<LogjamMove> moves;

  /// The game before the last move, or `null` before the first.
  ///
  /// While [moves] is not empty, it is the game with every move but the
  /// last, which [slide] relies on to join slides of the same log.
  final LogjamGame? _previous;

  @override
  bool get isSolved => board.isSolved;

  @override
  bool get isBlank => moves.isEmpty;

  @override
  bool get canUndo => _previous != null && !isSolved;

  @override
  bool get canReset => moves.isNotEmpty;

  /// Returns the game with [move] played, joined to the last move if that
  /// slid the same log.
  ///
  /// Returns this game unchanged if it is solved or the log already lies at
  /// [LogjamMove.to]. Throws an [ArgumentError] if the move is otherwise not
  /// legal.
  LogjamGame slide(LogjamMove move) {
    if (isSolved || _isWhereItLies(move)) {
      return this;
    }
    final next = board.apply(move);
    final last = moves.isEmpty ? null : moves.last;
    if (last == null || last.piece != move.piece) {
      return LogjamGame._(
        puzzle,
        next,
        List.unmodifiable([...moves, move]),
        this,
      );
    }

    // The same log again: the slide joins the move before, from where the
    // log lay before that move.
    final before = _previous!;
    if (before.board.pieces[move.piece].offset == move.to) {
      return before;
    }
    return LogjamGame._(
      puzzle,
      next,
      List.unmodifiable([...before.moves, move]),
      before,
    );
  }

  /// Returns the game as it was before the last move, or this game if there
  /// was none or it is solved.
  LogjamGame undo() => canUndo ? _previous! : this;

  /// Returns the game with every log back where the puzzle starts and no
  /// moves, or this game if it has none.
  ///
  /// The reset is a move like any other, so [undo] brings the moves back.
  LogjamGame reset() =>
      canReset ? LogjamGame._(puzzle, puzzle, const [], this) : this;

  bool _isWhereItLies(LogjamMove move) =>
      move.piece >= 0 &&
      move.piece < board.pieces.length &&
      board.pieces[move.piece].offset == move.to;
}
