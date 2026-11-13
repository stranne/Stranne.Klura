import 'package:flutter_test/flutter_test.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/puzzles/logjam/logic/logjam_board.dart';
import 'package:klura/puzzles/logjam/logic/logjam_game.dart';
import 'package:klura/puzzles/logjam/logic/logjam_generator.dart';
import 'package:klura/puzzles/logjam/logic/logjam_storage.dart';
import 'package:klura/puzzles/logjam/logic/logjam_text.dart';
import 'package:klura/puzzles/logjam/logjam_controller.dart';
import 'package:klura/puzzles/logjam/logjam_daily_games.dart';

void main() {
  final today = DateTime(2026, 11, 12);
  // Solved in two moves: B down 1, then the marked log right 1.
  final small = parseLogjam('''
A...
A**B>
...B
CC..
''');
  const solution = [LogjamMove(piece: 2, to: 2), LogjamMove(piece: 0, to: 2)];

  var now = Duration.zero;
  setUp(() => now = const Duration(hours: 1));

  LogjamController controllerOf(LogjamGame game, {int? bestMoves}) {
    final controller = LogjamController(
      level: LogjamLevel.normal,
      seedKey: 'test',
      game: game,
      fewestMoves: 2,
      bestMoves: bestMoves,
      clock: () => now,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test('makes moves and tells listeners', () {
    final controller = controllerOf(LogjamGame(small));
    var notified = 0;
    controller.addListener(() => notified++);

    controller
      ..slide(const LogjamMove(piece: 3, to: 1))
      ..slide(const LogjamMove(piece: 3, to: 2))
      ..slide(const LogjamMove(piece: 1, to: 1));

    expect(notified, 3);
    expect(controller.game.moves, const [
      LogjamMove(piece: 3, to: 2),
      LogjamMove(piece: 1, to: 1),
    ]);
    expect(controller.isStarted, isTrue);

    controller.undo();
    expect(controller.game.moves, const [LogjamMove(piece: 3, to: 2)]);

    controller.reset();
    expect(controller.game.board, small);
    expect(controller.isStarted, isFalse);
    expect(controller.bestMoves, isNull);
  });

  test('stops the timer for good at the first solve', () {
    final controller = controllerOf(LogjamGame(small))..resumeTiming();
    now += const Duration(seconds: 40);

    solution.forEach(controller.slide);
    now += const Duration(seconds: 30);
    controller
      ..reset()
      ..resumeTiming();
    now += const Duration(seconds: 30);

    expect(controller.wasSolved, isTrue);
    expect(controller.isStarted, isTrue);
    expect(controller.timer.elapsed, const Duration(seconds: 40));
  });

  test('keeps the fewest moves of any solve', () {
    final controller = controllerOf(LogjamGame(small))
      ..slide(const LogjamMove(piece: 3, to: 1));
    solution.forEach(controller.slide);

    expect(controller.bestMoves, 3);

    controller.reset();
    solution.forEach(controller.slide);

    expect(controller.bestMoves, 2);

    controller
      ..reset()
      ..slide(const LogjamMove(piece: 1, to: 1));
    solution.forEach(controller.slide);

    expect(controller.bestMoves, 2);
  });

  test('a game restored solved counts its moves as a solve', () {
    expect(controllerOf(LogjamGame(small, solution)).bestMoves, 2);
    expect(
      controllerOf(LogjamGame(small, solution), bestMoves: 3).bestMoves,
      2,
    );
    expect(controllerOf(LogjamGame(small), bestMoves: 3).bestMoves, 3);
  });

  group('LogjamDailyGames', () {
    test('saves each move and picks the game up again, undo and all', () {
      final store = MemoryLocalStore();
      final first = LogjamDailyGames(today, LogjamStorage(store));
      final game = first.open(LogjamLevel.hard);
      final moves = generateDailyLogjam(LogjamLevel.hard, today).solution;
      game
        ..slide(moves[0])
        ..slide(moves[1]);
      first.dispose();

      final second = LogjamDailyGames(today, LogjamStorage(store));
      addTearDown(second.dispose);
      final restored = second.started(LogjamLevel.hard)!;

      expect(restored.seedKey, logjamDailySeedKey(LogjamLevel.hard, today));
      expect(restored.game.board, game.game.board);
      expect(restored.game.moves, [moves[0], moves[1]]);
      expect(restored.fewestMoves, game.fewestMoves);
      expect(restored.game.undo().moves, [moves[0]]);
      expect(second.started(LogjamLevel.normal), isNull);
    });

    test('records the first solve and keeps its moves', () {
      final store = MemoryLocalStore();
      final first = LogjamDailyGames(today, LogjamStorage(store));
      final game = first.open(LogjamLevel.normal);
      generateDailyLogjam(
        LogjamLevel.normal,
        today,
      ).solution.forEach(game.slide);
      game.reset();

      expect(first.solveTime(LogjamLevel.normal), Duration.zero);
      expect(
        LogjamStorage(
          store,
        ).loadHistory().solveTime(LogjamLevel.normal, today),
        Duration.zero,
      );
      first.dispose();

      final second = LogjamDailyGames(today, LogjamStorage(store));
      addTearDown(second.dispose);
      final restored = second.started(LogjamLevel.normal)!;

      expect(restored.wasSolved, isTrue);
      expect(restored.game.isBlank, isTrue);
      expect(restored.bestMoves, restored.fewestMoves);
    });
  });
}
