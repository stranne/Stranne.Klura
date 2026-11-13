import 'package:klura/play/daily_games.dart';
import 'package:klura/play/play_timer.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_game.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_generator.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_save.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_storage.dart';
import 'package:klura/puzzles/tall_tales/tall_tales_controller.dart';

/// The Tall Tales games of one day, one per level, saved as they are
/// played.
final class TallTalesDailyGames
    extends DailyGames<TallTalesLevel, TallTalesSave, TallTalesController> {
  TallTalesDailyGames(
    super.date,
    TallTalesStorage super.storage, {
    this._clock,
  });

  final MonotonicClock? _clock;

  @override
  TallTalesController restore(TallTalesSave save) => TallTalesController(
    level: save.level,
    seedKey: save.seedKey,
    game: TallTalesGame(save.puzzle, save.marks),
    playedTime: save.playedTime,
    wasSolved: save.wasSolved,
    clock: _clock,
  );

  @override
  TallTalesController generate(
    TallTalesLevel level, {
    required Duration playedTime,
    required bool wasSolved,
  }) {
    final generated = generateDailyTallTales(level, date);
    return TallTalesController(
      level: level,
      seedKey: generated.seedKey,
      game: TallTalesGame(generated.puzzle),
      playedTime: playedTime,
      wasSolved: wasSolved,
      clock: _clock,
    );
  }

  @override
  TallTalesSave saveOf(TallTalesController game) => TallTalesSave(
    level: game.level,
    date: date,
    seedKey: game.seedKey,
    puzzle: game.game.puzzle,
    marks: game.game.marks,
    playedTime: game.timer.elapsed,
    wasSolved: game.wasSolved,
  );
}
