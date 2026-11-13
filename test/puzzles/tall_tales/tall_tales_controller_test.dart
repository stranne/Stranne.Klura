import 'package:flutter_test/flutter_test.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_game.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_generator.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_marks.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_storage.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_text.dart';
import 'package:klura/puzzles/tall_tales/tall_tales_controller.dart';
import 'package:klura/puzzles/tall_tales/tall_tales_daily_games.dart';

void main() {
  final today = DateTime(2026, 11, 13);
  // Solved by Alva telling the truth, and Bo and Cajsa tall tales.
  final (small, _) = parseTallTales('''
Alva: Bo and I are not alike.
Bo: Cajsa tells the truth.
Cajsa: Alva tells tall tales.
''');

  var now = Duration.zero;
  setUp(() => now = const Duration(hours: 1));

  TallTalesController controllerOf(TallTalesGame game) {
    final controller = TallTalesController(
      level: TallTalesLevel.normal,
      seedKey: 'test',
      game: game,
      clock: () => now,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  /// Marks every fisher of [game], the daily puzzle of today, as the
  /// solution has them.
  void solveDaily(TallTalesController game) {
    final solution = generateDailyTallTales(game.level, today).solution;
    for (var fisher = 0; fisher < solution.length; fisher++) {
      game.cycleMark(fisher);
      if (solution[fisher] == TallTalesMark.tallTales) {
        game.cycleMark(fisher);
      }
    }
  }

  test('makes moves and tells listeners', () {
    final controller = controllerOf(TallTalesGame(small));
    var notified = 0;
    controller.addListener(() => notified++);

    controller
      ..cycleMark(0)
      ..cycleMark(1)
      ..cycleMark(1);

    expect(notified, 3);
    expect(controller.game.marks[0], TallTalesMark.truth);
    expect(controller.game.marks[1], TallTalesMark.tallTales);
    expect(controller.isStarted, isTrue);

    controller.undo();
    expect(controller.game.marks[1], TallTalesMark.truth);

    controller.reset();
    expect(controller.game.isBlank, isTrue);
    expect(controller.isStarted, isFalse);
  });

  test('stops the timer for good at the first solve', () {
    final controller = controllerOf(TallTalesGame(small))..resumeTiming();
    now += const Duration(seconds: 40);

    controller
      ..cycleMark(0)
      ..cycleMark(1)
      ..cycleMark(1)
      ..cycleMark(2)
      ..cycleMark(2);
    now += const Duration(seconds: 30);
    controller
      ..reset()
      ..resumeTiming();
    now += const Duration(seconds: 30);

    expect(controller.wasSolved, isTrue);
    expect(controller.isStarted, isTrue);
    expect(controller.timer.elapsed, const Duration(seconds: 40));
  });

  group('TallTalesDailyGames', () {
    test('saves each move and picks the game up again', () {
      final store = MemoryLocalStore();
      final first = TallTalesDailyGames(today, TallTalesStorage(store));
      final game = first.open(TallTalesLevel.hard)..cycleMark(3);
      first.dispose();

      final second = TallTalesDailyGames(today, TallTalesStorage(store));
      addTearDown(second.dispose);
      final restored = second.started(TallTalesLevel.hard)!;

      expect(
        restored.seedKey,
        tallTalesDailySeedKey(TallTalesLevel.hard, today),
      );
      expect(restored.game.puzzle, game.game.puzzle);
      expect(restored.game.marks, game.game.marks);
      expect(second.started(TallTalesLevel.normal), isNull);
    });

    test('records the first solve in the history', () {
      final store = MemoryLocalStore();
      final games = TallTalesDailyGames(today, TallTalesStorage(store));
      addTearDown(games.dispose);

      solveDaily(games.open(TallTalesLevel.normal));

      expect(games.solveTime(TallTalesLevel.normal), Duration.zero);
      expect(
        TallTalesStorage(
          store,
        ).loadHistory().solveTime(TallTalesLevel.normal, today),
        Duration.zero,
      );
    });
  });
}
