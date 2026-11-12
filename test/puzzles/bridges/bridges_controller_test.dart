import 'package:flutter_test/flutter_test.dart';
import 'package:klura/puzzles/bridges/bridges_controller.dart';
import 'package:klura/puzzles/bridges/bridges_daily_games.dart';
import 'package:klura/puzzles/bridges/logic/bridge_arrangement.dart';
import 'package:klura/puzzles/bridges/logic/bridges_game.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
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

  BridgesController controllerOf(BridgesGame game) {
    final controller = BridgesController(
      level: BridgesLevel.normal,
      seedKey: 'test',
      game: game,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test('starts the daily puzzle of a level with no bridges', () {
    final controller = BridgesController.daily(BridgesLevel.hard, today);
    addTearDown(controller.dispose);

    expect(controller.level, BridgesLevel.hard);
    expect(controller.seedKey, 'bridges-hard:v2:2026-11-11');
    expect(
      controller.game.puzzle,
      generateDailyBridges(BridgesLevel.hard, today).puzzle,
    );
    expect(controller.game.arrangement, const BridgeArrangement.empty());
  });

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
    final small = parseBridges('3=2\n|..\n1..');
    final controller = controllerOf(
      BridgesGame(small.puzzle, small.arrangement),
    );
    final top = Connection(const Position(0, 0), const Position(2, 0));

    expect(controller.game.isSolved, isTrue);
    expect(controller.cycleBridges(top), isEmpty);
    expect(controller.game.arrangement, small.arrangement);

    controller.reset();

    expect(controller.game.isSolved, isFalse);
    expect(controller.game.arrangement.isEmpty, isTrue);
  });

  group('BridgesDailyGames', () {
    test('generates each level once and keeps it', () {
      final games = BridgesDailyGames(today);
      addTearDown(games.dispose);

      expect(games.started(BridgesLevel.normal), isNull);

      final normal = games.open(BridgesLevel.normal);

      expect(games.open(BridgesLevel.normal), same(normal));
      expect(games.started(BridgesLevel.normal), same(normal));
      expect(games.started(BridgesLevel.hard), isNull);
      expect(normal.seedKey, 'bridges-normal:v2:2026-11-11');
    });

    test('tells listeners about moves in any game', () {
      final games = BridgesDailyGames(today);
      addTearDown(games.dispose);
      var notifications = 0;
      games.addListener(() => notifications++);

      final hard = games.open(BridgesLevel.hard);
      hard.cycleBridges(hard.game.puzzle.connections.first);

      expect(notifications, 1);
    });
  });
}
