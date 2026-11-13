import 'package:flutter_test/flutter_test.dart';
import 'package:klura/app/klura_app.dart';
import 'package:klura/core/grid.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/puzzles/bridges/bridges_screen.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_storage.dart';
import 'package:klura/puzzles/logjam/logic/logjam_generator.dart';
import 'package:klura/puzzles/logjam/logic/logjam_storage.dart';
import 'package:klura/puzzles/logjam/logjam_screen.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_generator.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_marks.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_storage.dart';
import 'package:klura/puzzles/tall_tales/tall_tales_screen.dart';
import 'package:klura/puzzles/tents/logic/tents_generator.dart';
import 'package:klura/puzzles/tents/logic/tents_storage.dart';
import 'package:klura/puzzles/tents/tents_screen.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final today = DateTime(2026, 11, 11);
  final tomorrow = DateTime(2026, 11, 12, 7, 30);

  BridgesScreen screen(WidgetTester tester) =>
      tester.widget<BridgesScreen>(find.byType(BridgesScreen));

  /// The level [title] in the card of [puzzle] on the home screen.
  Finder level(String title, {String puzzle = 'Bridges'}) => find.descendant(
    of: find.ancestor(of: find.text(puzzle), matching: find.byType(Card)),
    matching: find.text(title),
  );

  /// Starts the app afresh on [store], as a reload of the page does.
  Future<void> launch(WidgetTester tester, LocalStore store) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(KluraApp(store: store, clock: () => today));
  }

  /// Hides the app and brings it back to the front, as a switch to another
  /// app and back does.
  void leaveAndReturn(WidgetTester tester) {
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  testWidgets('opens a daily puzzle from home and keeps it on return', (
    tester,
  ) async {
    await tester.pumpWidget(
      KluraApp(store: MemoryLocalStore(), clock: () => today),
    );

    await tester.tap(level('Hard'));
    await tester.pumpAndSettle();

    expect(find.text('Bridges · Hard'), findsOneWidget);
    final controller = screen(tester).controller;
    expect(controller.seedKey, 'bridges-hard:v2:2026-11-11');

    controller.cycleBridges(controller.game.puzzle.connections.first);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('In progress'), findsOneWidget);

    await tester.tap(level('Hard'));
    await tester.pumpAndSettle();

    expect(screen(tester).controller, same(controller));
    expect(controller.game.arrangement.isEmpty, isFalse);
  });

  testWidgets('moves on to a new day when the app comes back to the front', (
    tester,
  ) async {
    var now = today;
    final store = MemoryLocalStore();
    await tester.pumpWidget(KluraApp(store: store, clock: () => now));
    await tester.tap(level('Normal'));
    await tester.pumpAndSettle();
    final yesterday = screen(tester).controller;
    yesterday.cycleBridges(yesterday.game.puzzle.connections.first);
    await tester.pageBack();
    await tester.pumpAndSettle();

    now = tomorrow;
    leaveAndReturn(tester);
    await tester.pump();

    expect(find.text('Thu, Nov 12'), findsOneWidget);
    expect(find.text('In progress'), findsNothing);
    expect(BridgesStorage(store).loadGame(BridgesLevel.normal, today), isNull);

    await tester.tap(level('Normal'));
    await tester.pumpAndSettle();

    expect(
      screen(tester).controller.seedKey,
      bridgesDailySeedKey(BridgesLevel.normal, tomorrow),
    );
  });

  testWidgets('keeps a started puzzle on screen until it closes', (
    tester,
  ) async {
    var now = today;
    final store = MemoryLocalStore();
    await tester.pumpWidget(KluraApp(store: store, clock: () => now));
    await tester.tap(level('Hard'));
    await tester.pumpAndSettle();
    final started = screen(tester).controller;
    started.cycleBridges(started.game.puzzle.connections.first);

    now = tomorrow;
    leaveAndReturn(tester);
    await tester.pumpAndSettle();

    expect(screen(tester).controller, same(started));
    expect(started.game.arrangement.isEmpty, isFalse);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Thu, Nov 12'), findsOneWidget);
    expect(find.text('In progress'), findsNothing);
    expect(BridgesStorage(store).loadGame(BridgesLevel.hard, today), isNull);
  });

  testWidgets("replaces an untouched puzzle on screen with the new day's", (
    tester,
  ) async {
    var now = today;
    final store = MemoryLocalStore();
    await tester.pumpWidget(KluraApp(store: store, clock: () => now));
    await tester.tap(level('Normal'));
    await tester.pumpAndSettle();

    now = tomorrow;
    leaveAndReturn(tester);
    await tester.pump();

    expect(find.text('Bridges · Normal'), findsOneWidget);
    expect(
      screen(tester).controller.seedKey,
      bridgesDailySeedKey(BridgesLevel.normal, tomorrow),
    );
    expect(BridgesStorage(store).loadGame(BridgesLevel.normal, today), isNull);
    expect(
      BridgesStorage(store).loadGame(BridgesLevel.normal, tomorrow),
      isNotNull,
    );
  });

  testWidgets('moves on at midnight while the app stays in front', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 11, 23, 59, 30);
    await tester.pumpWidget(
      KluraApp(store: MemoryLocalStore(), clock: () => now),
    );

    expect(find.text('Wed, Nov 11'), findsOneWidget);

    now = DateTime(2026, 11, 12, 0, 0, 1);
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();

    expect(find.text('Thu, Nov 12'), findsOneWidget);
  });

  testWidgets('restores a game after a reload', (tester) async {
    final store = MemoryLocalStore();
    await launch(tester, store);
    await tester.tap(level('Normal'));
    await tester.pumpAndSettle();
    final before = screen(tester).controller;
    before.cycleBridges(before.game.puzzle.connections.first);

    await launch(tester, store);

    expect(find.text('In progress'), findsOneWidget);

    await tester.tap(level('Normal'));
    await tester.pumpAndSettle();
    final after = screen(tester).controller;

    expect(after, isNot(same(before)));
    expect(after.game.arrangement, before.game.arrangement);
    expect(after.game.canUndo, isFalse);
  });

  testWidgets('starts a fresh puzzle when the save is damaged', (
    tester,
  ) async {
    final store = MemoryLocalStore({
      BridgesStorage.gameKey(BridgesLevel.normal, today): '{"format": 1, "le',
      BridgesStorage.historyKey: '{"format": 1, "solved": 42}',
    });

    await launch(tester, store);

    expect(find.text('In progress'), findsNothing);

    await tester.tap(level('Normal'));
    await tester.pumpAndSettle();

    expect(find.text('Bridges · Normal'), findsOneWidget);
    expect(screen(tester).controller.game.arrangement.isEmpty, isTrue);
    expect(
      BridgesStorage(store).loadGame(BridgesLevel.normal, today),
      isNotNull,
    );
  });

  testWidgets('opens Tents and keeps a started game until it closes', (
    tester,
  ) async {
    var now = today;
    final store = MemoryLocalStore();
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(KluraApp(store: store, clock: () => now));
    await tester.tap(level('Hard', puzzle: 'Tents'));
    await tester.pumpAndSettle();

    expect(find.text('Tents · Hard'), findsOneWidget);
    final started = tester
        .widget<TentsScreen>(find.byType(TentsScreen))
        .controller;
    expect(started.seedKey, 'tents-hard:v1:2026-11-11');
    started.fillGrass([started.game.puzzle.trees.first.step(Direction.down)]);

    now = tomorrow;
    leaveAndReturn(tester);
    await tester.pumpAndSettle();

    expect(
      tester.widget<TentsScreen>(find.byType(TentsScreen)).controller,
      same(started),
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Thu, Nov 12'), findsOneWidget);
    expect(find.text('In progress'), findsNothing);
    expect(TentsStorage(store).loadGame(TentsLevel.hard, today), isNull);
  });

  testWidgets('opens Logjam and picks up its moves after a reload', (
    tester,
  ) async {
    final store = MemoryLocalStore();
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await launch(tester, store);
    await tester.tap(level('Hard', puzzle: 'Logjam'));
    await tester.pumpAndSettle();

    expect(find.text('Logjam · Hard'), findsOneWidget);
    final before = tester
        .widget<LogjamScreen>(find.byType(LogjamScreen))
        .controller;
    expect(before.seedKey, 'logjam-hard:v2:2026-11-11');
    final solution = generateDailyLogjam(LogjamLevel.hard, today).solution;
    before
      ..slide(solution[0])
      ..slide(solution[1]);

    await launch(tester, store);

    expect(find.text('In progress'), findsOneWidget);

    await tester.tap(level('Hard', puzzle: 'Logjam'));
    await tester.pumpAndSettle();
    final after = tester
        .widget<LogjamScreen>(find.byType(LogjamScreen))
        .controller;

    expect(after, isNot(same(before)));
    expect(after.game.board, before.game.board);
    expect(find.text('2 moves'), findsOneWidget);
    expect(after.game.canUndo, isTrue);
    expect(LogjamStorage(store).loadGame(LogjamLevel.hard, today), isNotNull);
  });

  testWidgets('opens Tall Tales and picks up its marks after a reload', (
    tester,
  ) async {
    final store = MemoryLocalStore();
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await launch(tester, store);
    await tester.tap(level('Normal', puzzle: 'Tall Tales'));
    await tester.pumpAndSettle();

    expect(find.text('Tall Tales · Normal'), findsOneWidget);
    final before = tester
        .widget<TallTalesScreen>(find.byType(TallTalesScreen))
        .controller;
    expect(before.seedKey, 'tall-tales-normal:v1:2026-11-11');
    before
      ..cycleMark(0)
      ..cycleMark(2)
      ..cycleMark(2);

    await launch(tester, store);

    expect(find.text('In progress'), findsOneWidget);

    await tester.tap(level('Normal', puzzle: 'Tall Tales'));
    await tester.pumpAndSettle();
    final after = tester
        .widget<TallTalesScreen>(find.byType(TallTalesScreen))
        .controller;

    expect(after, isNot(same(before)));
    expect(after.game.puzzle, before.game.puzzle);
    expect(after.game.marks[0], TallTalesMark.truth);
    expect(after.game.marks[2], TallTalesMark.tallTales);
    expect(after.game.canUndo, isFalse);
    expect(
      TallTalesStorage(store).loadGame(TallTalesLevel.normal, today),
      isNotNull,
    );
  });
}
