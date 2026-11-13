import 'package:klura/play/daily_games.dart';
import 'package:klura/play/play_timer.dart';
import 'package:klura/puzzles/logjam/logic/logjam_game.dart';
import 'package:klura/puzzles/logjam/logic/logjam_generator.dart';
import 'package:klura/puzzles/logjam/logic/logjam_save.dart';
import 'package:klura/puzzles/logjam/logic/logjam_storage.dart';
import 'package:klura/puzzles/logjam/logjam_controller.dart';

/// The Logjam games of one day, one per level, saved as they are played.
final class LogjamDailyGames
    extends DailyGames<LogjamLevel, LogjamSave, LogjamController> {
  LogjamDailyGames(super.date, LogjamStorage super.storage, {this._clock});

  final MonotonicClock? _clock;

  @override
  LogjamController restore(LogjamSave save) => LogjamController(
    level: save.level,
    seedKey: save.seedKey,
    game: LogjamGame(save.puzzle, save.moves),
    fewestMoves: save.fewestMoves,
    bestMoves: save.bestMoves,
    playedTime: save.playedTime,
    wasSolved: save.wasSolved,
    clock: _clock,
  );

  @override
  LogjamController generate(
    LogjamLevel level, {
    required Duration playedTime,
    required bool wasSolved,
  }) {
    final generated = generateDailyLogjam(level, date);
    return LogjamController(
      level: level,
      seedKey: generated.seedKey,
      game: LogjamGame(generated.puzzle),
      fewestMoves: generated.fewestMoves,
      playedTime: playedTime,
      wasSolved: wasSolved,
      clock: _clock,
    );
  }

  @override
  LogjamSave saveOf(LogjamController game) => LogjamSave(
    level: game.level,
    date: date,
    seedKey: game.seedKey,
    puzzle: game.game.puzzle,
    fewestMoves: game.fewestMoves,
    moves: game.game.moves,
    bestMoves: game.bestMoves,
    playedTime: game.timer.elapsed,
    wasSolved: game.wasSolved,
  );
}
