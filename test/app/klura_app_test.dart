import 'package:flutter_test/flutter_test.dart';
import 'package:klura/app/klura_app.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/puzzles/bridges/bridges_screen.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_storage.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final today = DateTime(2026, 11, 11);
  final tomorrow = DateTime(2026, 11, 12, 7, 30);

  BridgesScreen screen(WidgetTester tester) =>
      tester.widget<BridgesScreen>(find.byType(BridgesScreen));

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

    await tester.tap(find.text('Hard'));
    await tester.pumpAndSettle();

    expect(find.text('Bridges · Hard'), findsOneWidget);
    final controller = screen(tester).controller;
    expect(controller.seedKey, 'bridges-hard:v2:2026-11-11');

    controller.cycleBridges(controller.game.puzzle.connections.first);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('In progress'), findsOneWidget);

    await tester.tap(find.text('Hard'));
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
    await tester.tap(find.text('Normal'));
    await tester.pumpAndSettle();
    final yesterday = screen(tester).controller;
    yesterday.cycleBridges(yesterday.game.puzzle.connections.first);
    await tester.pageBack();
    await tester.pumpAndSettle();

    now = tomorrow;
    leaveAndReturn(tester);
    await tester.pump();

    expect(find.text('Thursday, November 12, 2026'), findsOneWidget);
    expect(find.text('In progress'), findsNothing);
    expect(BridgesStorage(store).loadGame(BridgesLevel.normal, today), isNull);

    await tester.tap(find.text('Normal'));
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
    await tester.tap(find.text('Hard'));
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

    expect(find.text('Thursday, November 12, 2026'), findsOneWidget);
    expect(find.text('In progress'), findsNothing);
    expect(BridgesStorage(store).loadGame(BridgesLevel.hard, today), isNull);
  });

  testWidgets("replaces an untouched puzzle on screen with the new day's", (
    tester,
  ) async {
    var now = today;
    final store = MemoryLocalStore();
    await tester.pumpWidget(KluraApp(store: store, clock: () => now));
    await tester.tap(find.text('Normal'));
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

    expect(find.text('Wednesday, November 11, 2026'), findsOneWidget);

    now = DateTime(2026, 11, 12, 0, 0, 1);
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();

    expect(find.text('Thursday, November 12, 2026'), findsOneWidget);
  });

  testWidgets('restores a game after a reload', (tester) async {
    final store = MemoryLocalStore();
    await launch(tester, store);
    await tester.tap(find.text('Normal'));
    await tester.pumpAndSettle();
    final before = screen(tester).controller;
    before.cycleBridges(before.game.puzzle.connections.first);

    await launch(tester, store);

    expect(find.text('In progress'), findsOneWidget);

    await tester.tap(find.text('Normal'));
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

    await tester.tap(find.text('Normal'));
    await tester.pumpAndSettle();

    expect(find.text('Bridges · Normal'), findsOneWidget);
    expect(screen(tester).controller.game.arrangement.isEmpty, isTrue);
    expect(
      BridgesStorage(store).loadGame(BridgesLevel.normal, today),
      isNotNull,
    );
  });
}
