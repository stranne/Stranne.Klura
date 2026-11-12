import 'package:klura/play/puzzle_controller.dart';
import 'package:klura/puzzles/bridges/logic/bridges_game.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';

/// Holds one game of Bridges, tells listeners about every move and times
/// the play up to the first solve.
final class BridgesController
    extends PuzzleController<BridgesLevel, BridgesGame> {
  /// Holds [game], which has taken [playedTime] so far.
  ///
  /// A game that is solved, or [wasSolved] before, keeps its time: the timer
  /// does not run again.
  BridgesController({
    required super.level,
    required super.seedKey,
    required super.game,
    super.playedTime,
    super.wasSolved,
    super.clock,
  });

  /// Moves [connection] on to its next number of bridges, unless a first
  /// bridge there would cross others.
  ///
  /// Returns the bridges in the way, which is empty when the move was made.
  /// A solved game takes no moves.
  List<Connection> cycleBridges(Connection connection) {
    final blockers = value.blockersOf(connection);
    if (blockers.isEmpty) {
      value = value.cycleBridges(connection);
    }
    return blockers;
  }

  @override
  void undo() => value = value.undo();

  /// Clears every bridge, as a move that [undo] takes back.
  @override
  void reset() => value = value.reset();
}
