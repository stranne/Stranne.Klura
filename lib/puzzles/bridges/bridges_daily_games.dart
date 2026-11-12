import 'package:flutter/foundation.dart';
import 'package:klura/puzzles/bridges/bridges_controller.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';

/// The Bridges games of one day, one per level.
///
/// A game is generated when first opened and kept for the rest of the
/// session, so leaving a puzzle and coming back resumes it. The date never
/// changes: a new day's puzzles wait for the next launch, so an open game is
/// never replaced. Listeners hear about every move in any of the games.
final class BridgesDailyGames extends ChangeNotifier {
  BridgesDailyGames(this.date);

  /// The day whose puzzles these are.
  final DateTime date;

  final Map<BridgesLevel, BridgesController> _games = {};

  /// The game at [level], or `null` if it has not been opened yet.
  BridgesController? started(BridgesLevel level) => _games[level];

  /// The game at [level], generating its puzzle on first use.
  BridgesController open(BridgesLevel level) => _games.putIfAbsent(
    level,
    () => BridgesController.daily(level, date)..addListener(notifyListeners),
  );

  @override
  void dispose() {
    for (final game in _games.values) {
      game.dispose();
    }
    super.dispose();
  }
}
