import 'package:klura/play/daily_games.dart';
import 'package:klura/play/play_timer.dart';
import 'package:klura/puzzles/bridges/bridges_controller.dart';
import 'package:klura/puzzles/bridges/logic/bridges_game.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_save.dart';
import 'package:klura/puzzles/bridges/logic/bridges_storage.dart';

/// The Bridges games of one day, one per level, saved as they are played.
final class BridgesDailyGames
    extends DailyGames<BridgesLevel, BridgesSave, BridgesController> {
  BridgesDailyGames(super.date, BridgesStorage super.storage, {this._clock});

  final MonotonicClock? _clock;

  @override
  BridgesController restore(BridgesSave save) => BridgesController(
    level: save.level,
    seedKey: save.seedKey,
    game: BridgesGame(save.puzzle, save.arrangement),
    playedTime: save.playedTime,
    wasSolved: save.wasSolved,
    clock: _clock,
  );

  @override
  BridgesController generate(
    BridgesLevel level, {
    required Duration playedTime,
    required bool wasSolved,
  }) {
    final generated = generateDailyBridges(level, date);
    return BridgesController(
      level: level,
      seedKey: generated.seedKey,
      game: BridgesGame(generated.puzzle),
      playedTime: playedTime,
      wasSolved: wasSolved,
      clock: _clock,
    );
  }

  @override
  BridgesSave saveOf(BridgesController game) => BridgesSave(
    level: game.level,
    date: date,
    seedKey: game.seedKey,
    puzzle: game.game.puzzle,
    arrangement: game.game.arrangement,
    playedTime: game.timer.elapsed,
    wasSolved: game.wasSolved,
  );
}
