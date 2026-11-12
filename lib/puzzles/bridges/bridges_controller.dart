import 'package:flutter/foundation.dart';
import 'package:klura/puzzles/bridges/logic/bridges_game.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';

/// Holds one game of Bridges and tells listeners about every move.
///
/// The game itself, with its undo history, is the immutable [value]; this
/// class only names the puzzle and replaces the game on each move.
final class BridgesController extends ValueNotifier<BridgesGame> {
  BridgesController({
    required this.level,
    required this.seedKey,
    required BridgesGame game,
  }) : super(game);

  /// Generates the puzzle of the day at [level] for the calendar date of
  /// [date] and starts a game of it.
  factory BridgesController.daily(BridgesLevel level, DateTime date) {
    final generated = generateDailyBridges(level, date);
    return BridgesController(
      level: level,
      seedKey: generated.seedKey,
      game: BridgesGame(generated.puzzle),
    );
  }

  final BridgesLevel level;

  /// The key the puzzle was generated from.
  final String seedKey;

  BridgesGame get game => value;

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

  /// Takes back the last move.
  void undo() => value = value.undo();

  /// Clears every bridge, as a move that [undo] takes back.
  void reset() => value = value.reset();
}
