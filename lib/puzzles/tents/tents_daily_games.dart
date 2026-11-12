import 'package:klura/play/daily_games.dart';
import 'package:klura/play/play_timer.dart';
import 'package:klura/puzzles/tents/logic/tents_game.dart';
import 'package:klura/puzzles/tents/logic/tents_generator.dart';
import 'package:klura/puzzles/tents/logic/tents_save.dart';
import 'package:klura/puzzles/tents/logic/tents_storage.dart';
import 'package:klura/puzzles/tents/tents_controller.dart';

/// The Tents games of one day, one per level, saved as they are played.
final class TentsDailyGames
    extends DailyGames<TentsLevel, TentsSave, TentsController> {
  TentsDailyGames(super.date, TentsStorage super.storage, {this._clock});

  final MonotonicClock? _clock;

  @override
  TentsController restore(TentsSave save) => TentsController(
    level: save.level,
    seedKey: save.seedKey,
    game: TentsGame(save.puzzle, save.marks),
    playedTime: save.playedTime,
    wasSolved: save.wasSolved,
    clock: _clock,
  );

  @override
  TentsController generate(
    TentsLevel level, {
    required Duration playedTime,
    required bool wasSolved,
  }) {
    final generated = generateDailyTents(level, date);
    return TentsController(
      level: level,
      seedKey: generated.seedKey,
      game: TentsGame(generated.puzzle),
      playedTime: playedTime,
      wasSolved: wasSolved,
      clock: _clock,
    );
  }

  @override
  TentsSave saveOf(TentsController game) => TentsSave(
    level: game.level,
    date: date,
    seedKey: game.seedKey,
    puzzle: game.game.puzzle,
    marks: game.game.marks,
    playedTime: game.timer.elapsed,
    wasSolved: game.wasSolved,
  );
}
