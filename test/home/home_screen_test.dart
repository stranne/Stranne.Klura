import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klura/home/home_screen.dart';
import 'package:klura/puzzles/bridges/bridges_daily_games.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';

void main() {
  final today = DateTime(2026, 11, 11);

  Future<BridgesDailyGames> pumpHome(WidgetTester tester) async {
    final bridges = BridgesDailyGames(today);
    addTearDown(bridges.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(today: today, bridges: bridges),
      ),
    );
    return bridges;
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
  });

  testWidgets('shows how far each opened game has come', (tester) async {
    final bridges = await pumpHome(tester);

    final normal = bridges.open(BridgesLevel.normal);
    normal.cycleBridges(normal.game.puzzle.connections.first);
    await tester.pump();

    expect(find.text('In progress'), findsOneWidget);

    final hard = bridges.open(BridgesLevel.hard);
    final solution = generateDailyBridges(BridgesLevel.hard, today).solution;
    for (final MapEntry(key: connection, value: count)
        in solution.bridges.entries) {
      for (var bridge = 0; bridge < count; bridge++) {
        hard.cycleBridges(connection);
      }
    }
    await tester.pump();

    expect(find.text('Solved'), findsOneWidget);
  });
}
