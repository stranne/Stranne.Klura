import 'package:klura/core/puzzle_game.dart';
import 'package:klura/puzzles/bridges/logic/bridge_arrangement.dart';
import 'package:klura/puzzles/bridges/logic/bridges_puzzle.dart';
import 'package:klura/puzzles/bridges/logic/bridges_rules.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';
import 'package:meta/meta.dart';

/// A game of Bridges in progress: a puzzle, the player's bridges and every
/// earlier arrangement to undo to.
///
/// A game is a value. Each move returns a new game that remembers the one
/// before it, so undo reaches back to the first move. A move that changes
/// nothing returns the same game.
///
/// The game never places a bridge that would cross another. Once solved it
/// takes no more moves and cannot be undone; [reset] starts it over.
@immutable
final class BridgesGame implements PuzzleGame {
  /// Starts a game of [puzzle] with the bridges of [arrangement], none by
  /// default, and nothing to undo.
  ///
  /// Throws an [ArgumentError] if [arrangement] has bridges on a connection
  /// the puzzle does not offer.
  BridgesGame(
    BridgesPuzzle puzzle, [
    BridgeArrangement arrangement = const BridgeArrangement.empty(),
  ]) : this._(puzzle, arrangement, null);

  BridgesGame._(this.puzzle, this.arrangement, this._previous)
    : check = checkBridges(puzzle, arrangement);

  final BridgesPuzzle puzzle;

  /// The player's bridges.
  final BridgeArrangement arrangement;

  /// How [arrangement] fares against the rules.
  final BridgesCheck check;

  /// The game before the last move, or `null` before the first.
  final BridgesGame? _previous;

  @override
  bool get isSolved => check.isSolved;

  @override
  bool get isBlank => arrangement.isEmpty;

  /// Whether [undo] would take back a move.
  @override
  bool get canUndo => _previous != null && !isSolved;

  /// Whether [reset] would clear any bridges.
  @override
  bool get canReset => !arrangement.isEmpty;

  /// The number of bridges [cycleBridges] would leave on [connection]: one
  /// more, or none after two.
  int nextBridgeCount(Connection connection) =>
      (arrangement[connection] + 1) % (BridgeArrangement.maxBridges + 1);

  /// The bridges in the way of a first bridge on [connection]: those it would
  /// cross. Empty if [connection] already has bridges or crosses none.
  ///
  /// Throws an [ArgumentError] if the puzzle does not offer [connection].
  List<Connection> blockersOf(Connection connection) {
    if (!puzzle.hasConnection(connection)) {
      throw ArgumentError.value(
        connection,
        'connection',
        'Is not a connection of the puzzle',
      );
    }
    return arrangement[connection] == 0
        ? arrangement.bridgesCrossing(connection)
        : const [];
  }

  /// Returns the game with the next number of bridges on [connection], in the
  /// cycle none, one, two, none.
  ///
  /// Returns this game unchanged if it is solved or the first bridge would
  /// cross another; [blockersOf] tells which. Throws an [ArgumentError] if
  /// the puzzle does not offer [connection].
  BridgesGame cycleBridges(Connection connection) {
    if (blockersOf(connection).isNotEmpty || isSolved) {
      return this;
    }
    return BridgesGame._(
      puzzle,
      arrangement.withBridges(connection, nextBridgeCount(connection)),
      this,
    );
  }

  /// Returns the game as it was before the last move, or this game if there
  /// was none or it is solved.
  BridgesGame undo() => canUndo ? _previous! : this;

  /// Returns the game with every bridge cleared, or this game if it has none.
  ///
  /// The reset is a move like any other, so [undo] brings the bridges back.
  BridgesGame reset() => canReset
      ? BridgesGame._(puzzle, const BridgeArrangement.empty(), this)
      : this;
}
