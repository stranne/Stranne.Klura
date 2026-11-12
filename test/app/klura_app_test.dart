import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klura/app/klura_app.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/puzzles/bridges/bridges_screen.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_storage.dart';

void main() {
  final today = DateTime(2026, 11, 11);

  BridgesScreen screen(WidgetTester tester) =>
      tester.widget<BridgesScreen>(find.byType(BridgesScreen));

  /// Starts the app afresh on [store], as a reload of the page does.
  Future<void> launch(WidgetTester tester, LocalStore store) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(KluraApp(today: today, store: store));
  }

  testWidgets('opens a daily puzzle from home and keeps it on return', (
    tester,
  ) async {
    await tester.pumpWidget(KluraApp(today: today, store: MemoryLocalStore()));

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

  testWidgets('keeps the start date for the whole session', (tester) async {
    final store = MemoryLocalStore();
    await tester.pumpWidget(KluraApp(today: today, store: store));
    await tester.pumpWidget(
      KluraApp(today: DateTime(2026, 11, 12), store: store),
    );

    expect(find.text('Wednesday, November 11, 2026'), findsOneWidget);

    await tester.tap(find.text('Normal'));
    await tester.pumpAndSettle();

    expect(
      screen(tester).controller.seedKey,
      bridgesDailySeedKey(BridgesLevel.normal, today),
    );
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
