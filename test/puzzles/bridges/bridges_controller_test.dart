import 'package:flutter_test/flutter_test.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/puzzles/bridges/bridges_controller.dart';
import 'package:klura/puzzles/bridges/bridges_daily_games.dart';
import 'package:klura/puzzles/bridges/logic/bridge_arrangement.dart';
import 'package:klura/puzzles/bridges/logic/bridges_game.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_save.dart';
import 'package:klura/puzzles/bridges/logic/bridges_storage.dart';
import 'package:klura/puzzles/bridges/logic/bridges_text.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';

void main() {
  final today = DateTime(2026, 11, 11);

  // A row and a column whose bridges would cross in the middle.
  final crossing = parseBridges('''
..1..
.....
1...1
.....
..1..
''').puzzle;
  final across = Connection(const Position(0, 2), const Position(4, 2));
  final down = Connection(const Position(2, 0), const Position(2, 4));

  // Solved by a double bridge along the top and a single one down the left.
  final small = parseBridges('3.2\n...\n1..').puzzle;
  final top = Connection(const Position(0, 0), const Position(2, 0));
  final left = Connection(const Position(0, 0), const Position(0, 2));

  var now = Duration.zero;
  setUp(() => now = const Duration(hours: 1));

  BridgesController controllerOf(BridgesGame game) {
    final controller = BridgesController(
      level: BridgesLevel.normal,
      seedKey: 'test',
      game: game,
      clock: () => now,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  /// Makes the moves that solve [game], the daily puzzle of [date], from an
  /// empty board.
  void solveDaily(BridgesController game, [DateTime? date]) {
    final solution = generateDailyBridges(game.level, date ?? today).solution;
    for (final MapEntry(key: connection, value: count)
        in solution.bridges.entries) {
      for (var bridge = 0; bridge < count; bridge++) {
        game.cycleBridges(connection);
      }
    }
  }

  test('cycles bridges and tells listeners', () {
    final controller = controllerOf(BridgesGame(crossing));
    var notifications = 0;
    controller.addListener(() => notifications++);

    expect(controller.cycleBridges(across), isEmpty);
    expect(controller.cycleBridges(across), isEmpty);
    expect(controller.cycleBridges(across), isEmpty);

    expect(notifications, 3);
    expect(controller.game.arrangement[across], 0);
  });

  test('reports a blocked bridge without changing the game', () {
    final controller = controllerOf(BridgesGame(crossing));
    controller.cycleBridges(across);
    final before = controller.game;
    var notifications = 0;
    controller.addListener(() => notifications++);

    final blockers = controller.cycleBridges(down);

    expect(blockers, [across]);
    expect(controller.game, same(before));
    expect(notifications, 0);
  });

  test('undoes moves and resets the board', () {
    final controller = controllerOf(BridgesGame(crossing));
    controller
      ..cycleBridges(across)
      ..cycleBridges(across);

    controller.undo();

    expect(controller.game.arrangement[across], 1);

    controller.reset();

    expect(controller.game.arrangement, const BridgeArrangement.empty());

    controller.undo();

    expect(controller.game.arrangement[across], 1);
  });

  test('takes no moves once solved, but resets', () {
    final solved = parseBridges('3=2\n|..\n1..');
    final controller = controllerOf(
      BridgesGame(solved.puzzle, solved.arrangement),
    );

    expect(controller.game.isSolved, isTrue);
    expect(controller.cycleBridges(top), isEmpty);
    expect(controller.game.arrangement, solved.arrangement);

    controller.reset();

    expect(controller.game.isSolved, isFalse);
    expect(controller.game.arrangement.isEmpty, isTrue);
  });

  group('timing', () {
    test('counts the time between resume and pause', () {
      final controller = controllerOf(BridgesGame(small))..resumeTiming();
      now += const Duration(seconds: 20);
      controller.pauseTiming();
      now += const Duration(minutes: 5);

      expect(controller.timer.elapsed, const Duration(seconds: 20));
    });

    test('stops for good at the first solve', () {
      final controller = controllerOf(BridgesGame(small))..resumeTiming();
      now += const Duration(seconds: 40);

      controller
        ..cycleBridges(top)
        ..cycleBridges(top)
        ..cycleBridges(left);
      now += const Duration(seconds: 10);

      expect(controller.wasSolved, isTrue);
      expect(controller.timer.isRunning, isFalse);
      expect(controller.timer.elapsed, const Duration(seconds: 40));

      controller
        ..reset()
        ..resumeTiming();
      now += const Duration(seconds: 10);

      expect(controller.game.isSolved, isFalse);
      expect(controller.wasSolved, isTrue);
      expect(controller.timer.elapsed, const Duration(seconds: 40));
    });

    test('pauses before telling listeners about the solving move', () {
      final controller = controllerOf(BridgesGame(small))
        ..cycleBridges(top)
        ..cycleBridges(top)
        ..resumeTiming();
      final heard = <bool>[];
      controller.addListener(() => heard.add(controller.timer.isRunning));

      controller.cycleBridges(left);

      expect(heard, [false]);
    });

    test('restores the time and the solve of a saved game', () {
      final controller = BridgesController(
        level: BridgesLevel.hard,
        seedKey: 'test',
        game: BridgesGame(small),
        playedTime: const Duration(minutes: 3),
        wasSolved: true,
        clock: () => now,
      );
      addTearDown(controller.dispose);

      controller.resumeTiming();
      now += const Duration(minutes: 1);

      expect(controller.wasSolved, isTrue);
      expect(controller.timer.elapsed, const Duration(minutes: 3));
    });
  });

  group('BridgesDailyGames', () {
    BridgesDailyGames gamesOf(LocalStore store, {DateTime? date}) {
      final games = BridgesDailyGames(
        date ?? today,
        BridgesStorage(store),
        clock: () => now,
      );
      addTearDown(games.dispose);
      return games;
    }

    test('generates each level once and keeps it', () {
      final games = gamesOf(MemoryLocalStore());

      expect(games.started(BridgesLevel.normal), isNull);

      final normal = games.open(BridgesLevel.normal);

      expect(games.open(BridgesLevel.normal), same(normal));
      expect(games.started(BridgesLevel.normal), same(normal));
      expect(games.started(BridgesLevel.hard), isNull);
      expect(normal.seedKey, 'bridges-normal:v2:2026-11-11');
      expect(
        normal.game.puzzle,
        generateDailyBridges(BridgesLevel.normal, today).puzzle,
      );
      expect(normal.game.arrangement.isEmpty, isTrue);
    });

    test('tells listeners about moves in any game', () {
      final games = gamesOf(MemoryLocalStore());
      var notifications = 0;
      games.addListener(() => notifications++);

      final hard = games.open(BridgesLevel.hard);
      hard.cycleBridges(hard.game.puzzle.connections.first);

      expect(notifications, 1);
    });

    test('saves every move and restores the game in a new session', () {
      final store = MemoryLocalStore();
      final first = gamesOf(store).open(BridgesLevel.normal)..resumeTiming();
      now += const Duration(seconds: 75);
      final connection = first.game.puzzle.connections.first;
      first.cycleBridges(connection);

      final restored = gamesOf(store).started(BridgesLevel.normal)!;

      expect(restored.seedKey, first.seedKey);
      expect(restored.game.puzzle, first.game.puzzle);
      expect(restored.game.arrangement, first.game.arrangement);
      expect(restored.timer.elapsed, const Duration(seconds: 75));
      expect(restored.wasSolved, isFalse);
    });

    test('saves the time when the timer pauses', () {
      final store = MemoryLocalStore();
      final first = gamesOf(store).open(BridgesLevel.hard)..resumeTiming();
      now += const Duration(seconds: 42);
      first.pauseTiming();

      final restored = gamesOf(store).started(BridgesLevel.hard)!;

      expect(restored.timer.elapsed, const Duration(seconds: 42));
    });

    test('keeps a saved puzzle the generator would no longer make', () {
      final store = MemoryLocalStore();
      final storage = BridgesStorage(store)
        ..saveGame(
          BridgesSave(
            level: BridgesLevel.normal,
            date: today,
            seedKey: 'bridges-normal:v1:2026-11-11',
            puzzle: small,
            arrangement: BridgeArrangement({top: 1}),
          ),
        );

      final restored = gamesOf(store).open(BridgesLevel.normal);

      expect(restored.seedKey, 'bridges-normal:v1:2026-11-11');
      expect(restored.game.puzzle, small);
      expect(storage.loadGame(BridgesLevel.normal, today), isNotNull);
    });

    test('records the first solve, which outlasts a start over', () {
      final store = MemoryLocalStore();
      final games = gamesOf(store);
      final normal = games.open(BridgesLevel.normal)..resumeTiming();
      now += const Duration(minutes: 6);

      expect(games.solveTime(BridgesLevel.normal), isNull);

      solveDaily(normal);
      normal.reset();

      expect(games.solveTime(BridgesLevel.normal), const Duration(minutes: 6));

      final restored = gamesOf(store);

      expect(
        restored.solveTime(BridgesLevel.normal),
        const Duration(minutes: 6),
      );
      expect(restored.started(BridgesLevel.normal)!.wasSolved, isTrue);
      expect(restored.started(BridgesLevel.normal)!.game.isSolved, isFalse);
    });

    test('keeps earlier solves and clears earlier games', () {
      final store = MemoryLocalStore();
      final yesterday = DateTime(2026, 11, 10);
      final first = gamesOf(store, date: yesterday);
      solveDaily(first.open(BridgesLevel.hard), yesterday);
      first
          .open(BridgesLevel.normal)
          .cycleBridges(
            first.open(BridgesLevel.normal).game.puzzle.connections.first,
          );

      final games = gamesOf(store);

      expect(games.started(BridgesLevel.normal), isNull);
      expect(games.started(BridgesLevel.hard), isNull);
      expect(games.solveTime(BridgesLevel.hard), isNull);
      expect(
        store.keys.where((key) => key.contains('2026-11-10')),
        isEmpty,
      );
      expect(
        BridgesStorage(store).loadHistory().solveTime(
          BridgesLevel.hard,
          yesterday,
        ),
        isNotNull,
      );
    });

    test('starts afresh when the save is damaged', () {
      final store = MemoryLocalStore({
        BridgesStorage.gameKey(BridgesLevel.normal, today): '{"format": 1,',
        BridgesStorage.gameKey(BridgesLevel.hard, today): '{"format": 99}',
        BridgesStorage.historyKey: 'damaged',
      });

      final games = gamesOf(store);

      expect(games.started(BridgesLevel.normal), isNull);
      expect(games.solveTime(BridgesLevel.normal), isNull);

      final normal = games.open(BridgesLevel.normal);
      normal.cycleBridges(normal.game.puzzle.connections.first);

      expect(
        gamesOf(store).started(BridgesLevel.normal)!.game.arrangement,
        normal.game.arrangement,
      );
    });

    test('keeps a recorded solve when the game itself was lost', () {
      final store = MemoryLocalStore();
      BridgesStorage(
        store,
      ).recordSolve(BridgesLevel.normal, today, const Duration(minutes: 2));

      final normal = gamesOf(store).open(BridgesLevel.normal)..resumeTiming();
      now += const Duration(minutes: 1);

      expect(normal.wasSolved, isTrue);
      expect(normal.timer.elapsed, const Duration(minutes: 2));
    });
  });
}
