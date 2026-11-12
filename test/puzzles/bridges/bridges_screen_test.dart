import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klura/puzzles/bridges/bridges_board.dart';
import 'package:klura/puzzles/bridges/bridges_controller.dart';
import 'package:klura/puzzles/bridges/bridges_screen.dart';
import 'package:klura/puzzles/bridges/logic/bridge_arrangement.dart';
import 'package:klura/puzzles/bridges/logic/bridges_game.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_text.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';

void main() {
  // A row and a column whose bridges would cross in the middle.
  const crossing = '''
..1..
.....
1...1
.....
..1..
''';
  final across = Connection(const Position(0, 2), const Position(4, 2));
  final down = Connection(const Position(2, 0), const Position(2, 4));

  // Solved by a double bridge along the top and a single one down the left.
  const small = '''
3.2
...
1..
''';
  final top = Connection(const Position(0, 0), const Position(2, 0));
  final left = Connection(const Position(0, 0), const Position(0, 2));

  Future<BridgesController> pumpGame(
    WidgetTester tester,
    String board, {
    bool disableAnimations = false,
  }) async {
    final (:puzzle, :arrangement) = parseBridges(board);
    final controller = BridgesController(
      level: BridgesLevel.normal,
      seedKey: 'test',
      game: BridgesGame(puzzle, arrangement),
    );
    addTearDown(controller.dispose);
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
          child: BridgesScreen(controller: controller),
        ),
      ),
    );
    return controller;
  }

  /// The center of [cell] on the board, in global coordinates.
  Offset centerOf(
    WidgetTester tester,
    BridgesController controller,
    Position cell,
  ) {
    final board = tester.getRect(
      find
          .descendant(
            of: find.byType(BridgesBoard),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    final cellSize = board.width / controller.game.puzzle.width;
    return board.topLeft +
        Offset((cell.x + 0.5) * cellSize, (cell.y + 0.5) * cellSize);
  }

  double cellSizeOf(WidgetTester tester, BridgesController controller) =>
      (centerOf(tester, controller, const Position(1, 0)) -
              centerOf(tester, controller, const Position(0, 0)))
          .dx;

  testWidgets('dragging from an island toward a neighbor builds a bridge', (
    tester,
  ) async {
    final controller = await pumpGame(tester, crossing);
    final cell = cellSizeOf(tester, controller);

    await tester.dragFrom(
      centerOf(tester, controller, const Position(0, 2)),
      Offset(cell * 1.2, cell * 0.2),
    );
    await tester.pumpAndSettle();

    expect(controller.game.arrangement[across], 1);
    expect(find.text('2 of 4 islands complete'), findsOneWidget);
  });

  testWidgets('a short drag that returns to its island builds nothing', (
    tester,
  ) async {
    final controller = await pumpGame(tester, crossing);
    final cell = cellSizeOf(tester, controller);
    final start = centerOf(tester, controller, const Position(0, 2));

    final gesture = await tester.startGesture(start);
    await gesture.moveBy(Offset(cell, 0));
    await gesture.moveBy(Offset(-cell * 0.9, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.game.arrangement.isEmpty, isTrue);
  });

  testWidgets('tapping a bridge cycles through two and none', (tester) async {
    final controller = await pumpGame(tester, crossing);
    final gap = centerOf(tester, controller, const Position(1, 2));

    await tester.tapAt(gap);
    await tester.pumpAndSettle();
    expect(controller.game.arrangement[across], 1);

    await tester.tapAt(gap);
    await tester.pumpAndSettle();
    expect(controller.game.arrangement[across], 2);

    await tester.tapAt(gap);
    await tester.pumpAndSettle();
    expect(controller.game.arrangement[across], 0);
  });

  testWidgets('tapping an island or an empty cell changes nothing', (
    tester,
  ) async {
    final controller = await pumpGame(tester, crossing);

    await tester.tapAt(centerOf(tester, controller, const Position(0, 2)));
    await tester.tapAt(centerOf(tester, controller, const Position(0, 0)));
    // Where the row and the column meet, an empty tap is ambiguous.
    await tester.tapAt(centerOf(tester, controller, const Position(2, 2)));
    await tester.pumpAndSettle();

    expect(controller.game.arrangement.isEmpty, isTrue);
  });

  testWidgets('a bridge that would cross another is never placed', (
    tester,
  ) async {
    final controller = await pumpGame(tester, crossing);
    controller.cycleBridges(across);
    await tester.pumpAndSettle();
    final cell = cellSizeOf(tester, controller);

    await tester.dragFrom(
      centerOf(tester, controller, const Position(2, 0)),
      Offset(0, cell * 1.2),
    );
    await tester.pump();

    expect(controller.game.arrangement[down], 0);
    expect(controller.game.check.crossings, isEmpty);
    expect(
      find.textContaining('Bridges cannot cross each other.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Bridges cannot cross each other.'),
      findsNothing,
    );
  });

  testWidgets('tapping where a bridge lies changes it, not the empty one', (
    tester,
  ) async {
    final controller = await pumpGame(tester, crossing);
    controller.cycleBridges(across);
    await tester.pumpAndSettle();

    await tester.tapAt(centerOf(tester, controller, const Position(2, 2)));
    await tester.pumpAndSettle();

    expect(controller.game.arrangement[across], 2);
    expect(controller.game.arrangement[down], 0);
  });

  testWidgets('undo and start over change the board', (tester) async {
    final controller = await pumpGame(tester, crossing);
    final gap = centerOf(tester, controller, const Position(1, 2));
    await tester.tapAt(gap);
    await tester.tapAt(gap);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(controller.game.arrangement[across], 1);

    await tester.tap(find.text('Start over').hitTestable());
    await tester.pumpAndSettle();

    expect(controller.game.arrangement.isEmpty, isTrue);
    expect(
      find.text('Board cleared. Undo brings the bridges back.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(controller.game.arrangement[across], 1);
  });

  testWidgets('undo and start over are off while there is nothing to do', (
    tester,
  ) async {
    await pumpGame(tester, crossing);

    final undo = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Undo'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    final reset = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Start over').hitTestable(),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );

    expect(undo.enabled, isFalse);
    expect(reset.enabled, isFalse);
  });

  testWidgets('solving shows the solved message and locks the board', (
    tester,
  ) async {
    final controller = await pumpGame(tester, small);
    final cell = cellSizeOf(tester, controller);
    final corner = centerOf(tester, controller, const Position(0, 0));

    expect(find.text('Solved').hitTestable(), findsNothing);

    await tester.dragFrom(corner, Offset(cell, 0));
    await tester.dragFrom(corner, Offset(cell, 0));
    await tester.dragFrom(corner, Offset(0, cell));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(controller.game.isSolved, isTrue);
    expect(find.text('Solved').hitTestable(), findsOneWidget);
    expect(find.text('Undo').hitTestable(), findsNothing);

    await tester.tapAt(centerOf(tester, controller, const Position(1, 0)));
    await tester.pumpAndSettle();

    expect(controller.game.arrangement[top], 2);

    await tester.tap(find.text('Start over').hitTestable());
    await tester.pumpAndSettle();

    expect(controller.game.arrangement.isEmpty, isTrue);
    expect(find.text('Solved').hitTestable(), findsNothing);
  });

  testWidgets('shows the solved message at once without animations', (
    tester,
  ) async {
    final controller = await pumpGame(tester, small, disableAnimations: true);
    controller
      ..cycleBridges(top)
      ..cycleBridges(top)
      ..cycleBridges(left);
    await tester.pumpAndSettle();

    expect(find.text('Solved').hitTestable(), findsOneWidget);
  });

  testWidgets('the arrow keys move between islands and build bridges', (
    tester,
  ) async {
    final controller = await pumpGame(tester, small);
    await tester.tapAt(centerOf(tester, controller, const Position(1, 1)));
    await tester.pump();

    // The first island in reading order has the focus to begin with.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(controller.game.arrangement, BridgeArrangement({top: 1, left: 1}));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(controller.game.arrangement, BridgeArrangement({top: 1}));
  });

  testWidgets('describes islands and progress for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = await pumpGame(tester, small);
    controller.cycleBridges(top);
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(
        'Island 3, row 1, column 1. 1 of 3 bridges. '
        '1 to the right',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Island 1, row 3, column 1. 0 of 1 bridges'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Bridges board, 3 columns by 3 rows, 3 islands',
      ),
      findsOneWidget,
    );
    expect(find.text('0 of 3 islands complete'), findsOneWidget);

    controller.cycleBridges(top);
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(
        'Island 2, row 1, column 3. complete. 2 to the '
        'left',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('names loops and overfull islands in words', (tester) async {
    await pumpGame(tester, '''
2-4=1
|.|..
2-2..
''');
    await tester.pump();

    expect(
      find.textContaining(
        'Some bridges form a loop · An island has too many bridges',
      ),
      findsOneWidget,
    );
  });

  testWidgets('says when every number is met but the islands are apart', (
    tester,
  ) async {
    await pumpGame(tester, '''
1-1
...
1-1
''');
    await tester.pump();

    expect(
      find.textContaining(
        'Every number is met, but not all islands are linked',
      ),
      findsOneWidget,
    );
  });
}
