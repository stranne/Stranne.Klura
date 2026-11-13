import 'package:flutter_test/flutter_test.dart';
import 'package:klura/app/klura_settings.dart';
import 'package:klura/core/grid.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/home/home_screen.dart';
import 'package:klura/puzzles/bridges/bridges_controller.dart';
import 'package:klura/puzzles/bridges/bridges_daily_games.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_storage.dart';
import 'package:klura/puzzles/logjam/logic/logjam_generator.dart';
import 'package:klura/puzzles/logjam/logic/logjam_storage.dart';
import 'package:klura/puzzles/logjam/logjam_daily_games.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_generator.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_marks.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_storage.dart';
import 'package:klura/puzzles/tall_tales/tall_tales_daily_games.dart';
import 'package:klura/puzzles/tents/logic/tents_generator.dart';
import 'package:klura/puzzles/tents/logic/tents_storage.dart';
import 'package:klura/puzzles/tents/tents_daily_games.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final today = DateTime(2026, 11, 11);

  /// Today's Logjam games on the home screen [pumpAll] last built.
  late LogjamDailyGames logjam;

  /// Today's Tall Tales games on the home screen [pumpAll] last built.
  late TallTalesDailyGames tallTales;

  Future<(BridgesDailyGames, TentsDailyGames, KluraSettings)> pumpAll(
    WidgetTester tester, {
    LocalStore? store,
    Size size = const Size(400, 1000),
    double textScale = 1,
  }) async {
    final storage = store ?? MemoryLocalStore();
    final bridges = BridgesDailyGames(today, BridgesStorage(storage));
    addTearDown(bridges.dispose);
    final tents = TentsDailyGames(today, TentsStorage(storage));
    addTearDown(tents.dispose);
    logjam = LogjamDailyGames(today, LogjamStorage(storage));
    addTearDown(logjam.dispose);
    tallTales = TallTalesDailyGames(today, TallTalesStorage(storage));
    addTearDown(tallTales.dispose);
    final settings = KluraSettings(storage);
    addTearDown(settings.dispose);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          today: today,
          bridges: bridges,
          tents: tents,
          logjam: logjam,
          tallTales: tallTales,
          settings: settings,
        ),
      ),
    );
    return (bridges, tents, settings);
  }

  Future<(BridgesDailyGames, KluraSettings)> pumpHome(
    WidgetTester tester, {
    LocalStore? store,
  }) async {
    final (bridges, _, settings) = await pumpAll(tester, store: store);
    return (bridges, settings);
  }

  /// The card of [puzzle].
  Finder card(String puzzle) =>
      find.ancestor(of: find.text(puzzle), matching: find.byType(Card));

  /// The text [text] in the card of [puzzle].
  Finder inCard(String puzzle, String text) =>
      find.descendant(of: card(puzzle), matching: find.text(text));

  void solve(BridgesController game) {
    final solution = generateDailyBridges(game.level, today).solution;
    for (final MapEntry(key: connection, value: count)
        in solution.bridges.entries) {
      for (var bridge = 0; bridge < count; bridge++) {
        game.cycleBridges(connection);
      }
    }
  }

  testWidgets('shows the date and both levels of each puzzle', (tester) async {
    final semantics = tester.ensureSemantics();
    // Tall enough for all four cards, since the list builds only those in
    // view.
    await pumpAll(tester, size: const Size(400, 1400));

    expect(find.text('Klura'), findsOneWidget);
    expect(find.text("Today's puzzles"), findsOneWidget);
    expect(find.text('Wed, Nov 11'), findsOneWidget);
    // The date is read aloud in full, with the name above it.
    final header = tester.getSemantics(find.text('Wed, Nov 11')).label;
    expect(header, contains('Wednesday, November 11, 2026'));
    expect(header, isNot(contains('Wed, Nov 11')));
    expect(inCard('Bridges', 'Normal'), findsOneWidget);
    expect(inCard('Bridges', '10 × 10 · 30 islands'), findsOneWidget);
    expect(inCard('Bridges', 'Hard'), findsOneWidget);
    expect(inCard('Bridges', '10 × 12 · 36 islands'), findsOneWidget);
    expect(inCard('Tents', 'Normal'), findsOneWidget);
    expect(inCard('Tents', '8 × 8 · 12 tents'), findsOneWidget);
    expect(inCard('Tents', 'Hard'), findsOneWidget);
    expect(inCard('Tents', '10 × 10 · 20 tents'), findsOneWidget);
    expect(inCard('Logjam', 'Normal'), findsOneWidget);
    expect(inCard('Logjam', '6 × 6 · 10 to 14 moves'), findsOneWidget);
    expect(inCard('Logjam', 'Hard'), findsOneWidget);
    expect(inCard('Logjam', '6 × 6 · 20 to 25 moves'), findsOneWidget);
    expect(inCard('Tall Tales', 'Normal'), findsOneWidget);
    expect(inCard('Tall Tales', '7 fishers'), findsOneWidget);
    expect(inCard('Tall Tales', 'Hard'), findsOneWidget);
    expect(inCard('Tall Tales', '8 fishers'), findsOneWidget);
    expect(find.text('In progress'), findsNothing);
    semantics.dispose();
  });

  testWidgets('places the puzzles side by side in even rows on a wide screen', (
    tester,
  ) async {
    await pumpAll(tester, size: const Size(1280, 800));

    final bridges = tester.getRect(card('Bridges'));
    final tents = tester.getRect(card('Tents'));
    final logjam = tester.getRect(card('Logjam'));
    final tallTales = tester.getRect(card('Tall Tales'));
    // Four cards make two rows of two rather than three and one.
    expect(tents.top, bridges.top);
    expect(tents.height, bridges.height);
    expect(tents.left, greaterThan(bridges.right));
    expect(logjam.top, greaterThan(bridges.bottom));
    expect(logjam.left, bridges.left);
    expect(tallTales.top, logjam.top);
    expect(tallTales.height, logjam.height);
    expect(tallTales.left, tents.left);
    // The levels line up across the row.
    expect(
      tester.getTopLeft(inCard('Tents', 'Hard')).dy,
      tester.getTopLeft(inCard('Bridges', 'Hard')).dy,
    );
    // The date sits at the right edge of the cards.
    expect(
      tester.getTopRight(find.text('Wed, Nov 11')).dx,
      lessThan(tents.right),
    );
    expect(
      tester.getTopRight(find.text('Wed, Nov 11')).dx,
      greaterThan(tents.right - 24),
    );
  });

  testWidgets('stacks the puzzles on a narrow screen', (tester) async {
    await pumpAll(tester);

    expect(
      tester.getRect(card('Tents')).top,
      greaterThan(tester.getRect(card('Bridges')).bottom),
    );
  });

  testWidgets('stacks the puzzles where large text needs the room', (
    tester,
  ) async {
    await pumpAll(tester, size: const Size(1280, 2400), textScale: 2);

    expect(
      tester.getRect(card('Tents')).top,
      greaterThan(tester.getRect(card('Bridges')).bottom),
    );
  });

  testWidgets('puts the date below the name where large text needs the room', (
    tester,
  ) async {
    await pumpAll(tester, size: const Size(320, 1000), textScale: 2);

    expect(
      tester.getRect(find.text('Wed, Nov 11')).top,
      greaterThan(tester.getRect(find.text("Today's puzzles")).bottom),
    );
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

  testWidgets('shows saved progress in a new session, without a streak', (
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
    // Days solved in a row are not counted, so a missed day costs nothing.
    expect(find.textContaining('streak'), findsNothing);
  });

  testWidgets('shows how far each Tents game has come', (tester) async {
    final (_, tents, _) = await pumpAll(tester);

    final normal = tents.open(TentsLevel.normal);
    normal.cycleMark(normal.game.puzzle.trees.first.step(Direction.down));
    await tester.pump();

    expect(inCard('Tents', 'In progress'), findsOneWidget);
    expect(inCard('Bridges', 'In progress'), findsNothing);

    final hard = tents.open(TentsLevel.hard);
    for (final tent in generateDailyTents(
      TentsLevel.hard,
      today,
    ).solution.tents) {
      hard
        ..cycleMark(tent)
        ..cycleMark(tent);
    }
    await tester.pump();

    expect(inCard('Tents', 'Solved · 0:00'), findsOneWidget);
  });

  testWidgets('shows how far each Tall Tales game has come', (tester) async {
    await pumpAll(tester, size: const Size(400, 1400));

    tallTales.open(TallTalesLevel.normal).cycleMark(0);
    await tester.pump();

    expect(inCard('Tall Tales', 'In progress'), findsOneWidget);
    expect(inCard('Logjam', 'In progress'), findsNothing);

    final hard = tallTales.open(TallTalesLevel.hard);
    final solution = generateDailyTallTales(
      TallTalesLevel.hard,
      today,
    ).solution;
    for (var fisher = 0; fisher < solution.length; fisher++) {
      hard.cycleMark(fisher);
      if (solution[fisher] == TallTalesMark.tallTales) {
        hard.cycleMark(fisher);
      }
    }
    await tester.pump();

    expect(inCard('Tall Tales', 'Solved · 0:00'), findsOneWidget);
  });

  testWidgets('shows how far each Logjam game has come, with its moves', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final (_, _, settings) = await pumpAll(tester);

    final normal = logjam.open(LogjamLevel.normal);
    normal.slide(normal.game.board.moves.first);
    await tester.pump();

    expect(inCard('Logjam', 'In progress'), findsOneWidget);

    final hard = logjam.open(LogjamLevel.hard);
    generateDailyLogjam(LogjamLevel.hard, today).solution.forEach(hard.slide);
    await tester.pump();

    final fewest = hard.fewestMoves;
    expect(inCard('Logjam', 'Solved · 0:00'), findsOneWidget);
    expect(inCard('Logjam', '$fewest moves'), findsOneWidget);
    // Read aloud as one, without the dot.
    expect(
      tester.getSemantics(inCard('Logjam', 'Solved · 0:00')).label,
      allOf(
        contains('Solved in 0 seconds, $fewest moves'),
        isNot(contains('Solved · 0:00')),
      ),
    );

    // The solve and its moves stand after a start over.
    hard.reset();
    settings.showTimer = false;
    await tester.pump();

    expect(inCard('Logjam', 'Solved'), findsOneWidget);
    expect(inCard('Logjam', '$fewest moves'), findsOneWidget);
    semantics.dispose();
  });
}
