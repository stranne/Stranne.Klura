import 'package:flutter_test/flutter_test.dart';
import 'package:klura/core/grid.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/puzzles/tents/logic/tents_game.dart';
import 'package:klura/puzzles/tents/logic/tents_generator.dart';
import 'package:klura/puzzles/tents/logic/tents_marks.dart';
import 'package:klura/puzzles/tents/logic/tents_storage.dart';
import 'package:klura/puzzles/tents/logic/tents_text.dart';
import 'package:klura/puzzles/tents/tents_controller.dart';
import 'package:klura/puzzles/tents/tents_daily_games.dart';

void main() {
  final today = DateTime(2026, 11, 12);
  final (small, _) = parseTents('''
  0002
1 ..T.
0 ....
1 ..T.
''');

  var now = Duration.zero;
  setUp(() => now = const Duration(hours: 1));

  TentsController controllerOf(TentsGame game) {
    final controller = TentsController(
      level: TentsLevel.normal,
      seedKey: 'test',
      game: game,
      clock: () => now,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  /// Places the tents that solve [game], the daily puzzle of today.
  void solveDaily(TentsController game) {
    final solution = generateDailyTents(game.level, today).solution;
    for (final tent in solution.tents) {
      game
        ..cycleMark(tent)
        ..cycleMark(tent);
    }
  }

  test('makes moves and tells listeners', () {
    final controller = controllerOf(TentsGame(small));
    var notified = 0;
    controller.addListener(() => notified++);

    controller
      ..cycleMark(const Position(3, 0))
      ..fillGrass(const [Position(0, 1), Position(1, 1)])
      ..clearGrass(const [Position(1, 1)]);

    expect(notified, 3);
    expect(controller.game.marks[const Position(3, 0)], TentsMark.grass);
    expect(controller.game.marks.grass, const [
      Position(3, 0),
      Position(0, 1),
    ]);
    expect(controller.isStarted, isTrue);

    controller.undo();
    expect(controller.game.marks[const Position(1, 1)], TentsMark.grass);

    controller.reset();
    expect(controller.game.isBlank, isTrue);
    expect(controller.isStarted, isFalse);
  });

  test('stops the timer for good at the first solve', () {
    final controller = controllerOf(TentsGame(small))..resumeTiming();
    now += const Duration(seconds: 40);

    for (final tent in const [Position(3, 0), Position(3, 2)]) {
      controller
        ..cycleMark(tent)
        ..cycleMark(tent);
    }
    now += const Duration(seconds: 30);
    controller
      ..reset()
      ..resumeTiming();
    now += const Duration(seconds: 30);

    expect(controller.wasSolved, isTrue);
    expect(controller.isStarted, isTrue);
    expect(controller.timer.elapsed, const Duration(seconds: 40));
  });

  group('TentsDailyGames', () {
    test('saves each move and picks the game up again', () {
      final store = MemoryLocalStore();
      final first = TentsDailyGames(today, TentsStorage(store));
      final game = first.open(TentsLevel.hard);
      final cell = game.game.puzzle.trees.first.step(Direction.down);
      game.fillGrass([cell]);
      first.dispose();

      final second = TentsDailyGames(today, TentsStorage(store));
      addTearDown(second.dispose);
      final restored = second.started(TentsLevel.hard)!;

      expect(restored.seedKey, tentsDailySeedKey(TentsLevel.hard, today));
      expect(restored.game.marks, game.game.marks);
      expect(second.started(TentsLevel.normal), isNull);
    });

    test('records the first solve in the history', () {
      final store = MemoryLocalStore();
      final games = TentsDailyGames(today, TentsStorage(store));
      addTearDown(games.dispose);

      solveDaily(games.open(TentsLevel.normal));

      expect(games.solveTime(TentsLevel.normal), Duration.zero);
      expect(
        TentsStorage(
          store,
        ).loadHistory().solveTime(TentsLevel.normal, today),
        Duration.zero,
      );
    });
  });
}
