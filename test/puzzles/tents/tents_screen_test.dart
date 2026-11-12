import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klura/app/klura_settings.dart';
import 'package:klura/core/grid.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/puzzles/tents/logic/tents_game.dart';
import 'package:klura/puzzles/tents/logic/tents_generator.dart';
import 'package:klura/puzzles/tents/logic/tents_marks.dart';
import 'package:klura/puzzles/tents/logic/tents_text.dart';
import 'package:klura/puzzles/tents/tents_board.dart';
import 'package:klura/puzzles/tents/tents_board_geometry.dart';
import 'package:klura/puzzles/tents/tents_controller.dart';
import 'package:klura/puzzles/tents/tents_screen.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // Two trees in one column, solved by a tent to the right of each.
  const small = '''
  0002
1 ..T.
0 ....
1 ..T.
''';

  late KluraSettings settings;

  Future<TentsController> pumpGame(
    WidgetTester tester,
    String board, {
    bool disableAnimations = false,
  }) async {
    final (puzzle, marks) = parseTents(board);
    final controller = TentsController(
      level: TentsLevel.normal,
      seedKey: 'test',
      game: TentsGame(puzzle, marks),
      clock: () => Duration.zero,
    );
    addTearDown(controller.dispose);
    settings = KluraSettings(MemoryLocalStore());
    addTearDown(settings.dispose);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 800),
            disableAnimations: disableAnimations,
          ),
          child: TentsScreen(controller: controller, settings: settings),
        ),
      ),
    );
    return controller;
  }

  /// The center of [cell] on the board, in global coordinates.
  Offset centerOf(
    WidgetTester tester,
    TentsController controller,
    Position cell,
  ) {
    final board = tester.getRect(
      find
          .descendant(
            of: find.byType(TentsBoard),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    final puzzle = controller.game.puzzle;
    final cellSize =
        board.width / (puzzle.width + tentsClueStrip + tentsBoardMargin);
    final geometry = TentsBoardGeometry(
      width: puzzle.width,
      height: puzzle.height,
      cellSize: cellSize,
    );
    return board.topLeft + geometry.centerOf(cell);
  }

  String boardOf(TentsController controller) =>
      formatTents(controller.game.puzzle, controller.game.marks);

  Future<void> tapCell(
    WidgetTester tester,
    TentsController controller,
    Position cell,
  ) async {
    await tester.tapAt(centerOf(tester, controller, cell));
    await tester.pump();
  }

  testWidgets('a tap moves a cell through grass, a tent and empty', (
    tester,
  ) async {
    final controller = await pumpGame(tester, small);
    const cell = Position(1, 1);

    await tapCell(tester, controller, cell);
    expect(controller.game.marks[cell], TentsMark.grass);

    await tapCell(tester, controller, cell);
    expect(controller.game.marks[cell], TentsMark.tent);

    await tapCell(tester, controller, cell);
    expect(controller.game.marks[cell], isNull);
    expect(controller.game.canUndo, isTrue);
  });

  testWidgets('tapping a tree changes nothing', (tester) async {
    final controller = await pumpGame(tester, small);

    await tapCell(tester, controller, const Position(2, 0));

    expect(controller.game.isBlank, isTrue);
    expect(controller.game.canUndo, isFalse);
  });

  testWidgets('a drag along a row puts grass on its empty cells', (
    tester,
  ) async {
    final controller = await pumpGame(tester, '''
  0002
1 ..T^
0 ....
1 ..T.
''');

    await tester.dragFrom(
      centerOf(tester, controller, const Position(0, 0)),
      centerOf(tester, controller, const Position(3, 0)) -
          centerOf(tester, controller, const Position(0, 0)) +
          const Offset(0, 6),
    );
    await tester.pump();

    expect(boardOf(controller), '''
  0002
1 --T^
0 ....
1 ..T.
''');
    controller.undo();
    expect(controller.game.isBlank, isFalse);
    expect(controller.game.marks.grass, isEmpty);
  });

  testWidgets('a drag down a column follows the column', (tester) async {
    final controller = await pumpGame(tester, small);

    await tester.dragFrom(
      centerOf(tester, controller, const Position(0, 0)),
      centerOf(tester, controller, const Position(0, 2)) -
          centerOf(tester, controller, const Position(0, 0)) +
          const Offset(8, 0),
    );
    await tester.pump();

    expect(boardOf(controller), '''
  0002
1 -.T.
0 -...
1 -.T.
''');
  });

  testWidgets('a drag that starts on grass clears grass', (tester) async {
    final controller = await pumpGame(tester, '''
  0002
1 --T^
0 -...
1 ..T.
''');

    await tester.dragFrom(
      centerOf(tester, controller, const Position(0, 0)),
      centerOf(tester, controller, const Position(3, 0)) -
          centerOf(tester, controller, const Position(0, 0)),
    );
    await tester.pump();

    expect(boardOf(controller), '''
  0002
1 ..T^
0 -...
1 ..T.
''');
  });

  testWidgets('a click that slips a little still counts', (tester) async {
    final controller = await pumpGame(tester, small);
    const cell = Position(3, 1);

    await tester.dragFrom(
      centerOf(tester, controller, cell),
      const Offset(4, 3),
    );
    await tester.pump();

    expect(controller.game.marks[cell], TentsMark.grass);
  });

  testWidgets('names touching tents and crowded lines in words', (
    tester,
  ) async {
    await pumpGame(tester, '''
  0002
1 ..T^
0 ...^
1 ..T.
''');

    expect(
      find.textContaining(
        'Some tents touch · A tent has no tree beside it · '
        'A row has too many tents',
      ),
      findsOneWidget,
    );
  });

  testWidgets('names tents that have no tree of their own', (tester) async {
    await pumpGame(tester, '''
  0002
1 ^.T.
0 ....
1 ..T.
''');

    expect(find.textContaining('A tent has no tree beside it'), findsOneWidget);
  });

  testWidgets('names tents that have to share a tree', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpGame(tester, '''
  0100
0 ...^
0 ....
1 .^T^
''');

    expect(
      find.textContaining(
        'A tent has no tree beside it · Some tents have to share a tree',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Row 3, column 4, tent, has to share a tree'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Row 3, column 3, tree, shared by too many tents'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('solving shows the solved message and locks the board', (
    tester,
  ) async {
    final controller = await pumpGame(tester, '''
  0002
1 ..T^
0 ....
1 ..T-
''');

    await tapCell(tester, controller, const Position(3, 2));
    await tester.pumpAndSettle();

    expect(controller.game.isSolved, isTrue);
    expect(find.text('Solved'), findsOneWidget);

    await tapCell(tester, controller, const Position(0, 0));

    expect(controller.game.marks[const Position(0, 0)], isNull);
  });

  testWidgets('the arrow keys move between cells and Space changes one', (
    tester,
  ) async {
    final controller = await pumpGame(tester, small);
    await tapCell(tester, controller, const Position(0, 0));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(boardOf(controller), '''
  0002
1 -.T^
0 ....
1 ..T.
''');
  });

  testWidgets('describes cells and numbers for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpGame(tester, '''
  0002
1 ..T^
0 -..^
1 ..T.
''');

    expect(
      find.bySemanticsLabel(
        'Tents board, 4 columns by 3 rows, 2 trees, 2 tents placed',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Row 1, column 3, tree'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Row 2, column 1, grass'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Row 2, column 4, tent, touches another tent, no tree beside it',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Column 4: 2 tents, 2 placed, complete'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Row 2: 0 tents, 1 placed, too many'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('start over clears the board and undo brings it back', (
    tester,
  ) async {
    final controller = await pumpGame(tester, '''
  0002
1 ..T^
0 --..
1 ..T.
''');

    await tester.tap(find.text('Start over').hitTestable());
    await tester.pump();

    expect(controller.game.isBlank, isTrue);
    expect(
      find.text('Board cleared. Undo brings the tents back.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(controller.game.marks.tents, const [Position(3, 0)]);
  });

  testWidgets('explains the rules', (tester) async {
    await pumpGame(tester, small);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pumpAndSettle();

    expect(
      find.text('Tents never touch each other, not even diagonally.'),
      findsOneWidget,
    );
    expect(find.text('Placing tents'), findsOneWidget);
  });
}
