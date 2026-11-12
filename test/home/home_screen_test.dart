import 'package:flutter_test/flutter_test.dart';
import 'package:klura/app/klura_settings.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/home/home_screen.dart';
import 'package:klura/puzzles/bridges/bridges_controller.dart';
import 'package:klura/puzzles/bridges/bridges_daily_games.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_storage.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final today = DateTime(2026, 11, 11);

  Future<(BridgesDailyGames, KluraSettings)> pumpHome(
    WidgetTester tester, {
    LocalStore? store,
  }) async {
    final storage = store ?? MemoryLocalStore();
    final bridges = BridgesDailyGames(today, BridgesStorage(storage));
    addTearDown(bridges.dispose);
    final settings = KluraSettings(storage);
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(today: today, bridges: bridges, settings: settings),
      ),
    );
    return (bridges, settings);
  }

  void solve(BridgesController game) {
    final solution = generateDailyBridges(game.level, today).solution;
    for (final MapEntry(key: connection, value: count)
        in solution.bridges.entries) {
      for (var bridge = 0; bridge < count; bridge++) {
        game.cycleBridges(connection);
      }
    }
  }

  testWidgets('shows the date and both Bridges levels', (tester) async {
    await pumpHome(tester);

    expect(find.text('Klura'), findsOneWidget);
    expect(find.text('Wednesday, November 11, 2026'), findsOneWidget);
    expect(find.text('Bridges'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('10 × 10 · 30 islands'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
    expect(find.text('10 × 12 · 36 islands'), findsOneWidget);
    expect(find.text('In progress'), findsNothing);
    expect(find.textContaining('streak'), findsNothing);
  });

  testWidgets('shows how far each opened game has come', (tester) async {
    final (bridges, _) = await pumpHome(tester);

    final normal = bridges.open(BridgesLevel.normal);
    normal.cycleBridges(normal.game.puzzle.connections.first);
    await tester.pump();

    expect(find.text('In progress'), findsOneWidget);

    solve(bridges.open(BridgesLevel.hard));
    await tester.pump();

    expect(find.text('Solved · 0:00'), findsOneWidget);
    expect(find.text('1-day streak'), findsOneWidget);
  });

  testWidgets('a solved puzzle stays solved after a start over', (
    tester,
  ) async {
    final (bridges, settings) = await pumpHome(tester);
    final hard = bridges.open(BridgesLevel.hard);

    solve(hard);
    hard.reset();
    await tester.pump();

    expect(find.text('Solved · 0:00'), findsOneWidget);

    settings.showTimer = false;
    await tester.pump();

    expect(find.text('Solved'), findsOneWidget);
  });

  testWidgets('shows saved progress and the streak in a new session', (
    tester,
  ) async {
    final store = MemoryLocalStore();
    final storage = BridgesStorage(store)
      ..recordSolve(
        BridgesLevel.normal,
        DateTime(2026, 11, 9),
        const Duration(minutes: 3),
      )
      ..recordSolve(
        BridgesLevel.hard,
        DateTime(2026, 11, 10),
        const Duration(minutes: 9),
      )
      ..recordSolve(
        BridgesLevel.normal,
        today,
        const Duration(minutes: 4, seconds: 12),
      );
    final earlier = BridgesDailyGames(today, storage);
    final hard = earlier.open(BridgesLevel.hard);
    hard.cycleBridges(hard.game.puzzle.connections.first);
    earlier.dispose();

    await pumpHome(tester, store: store);

    expect(find.text('Solved · 4:12'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('3-day streak'), findsOneWidget);
  });
}
