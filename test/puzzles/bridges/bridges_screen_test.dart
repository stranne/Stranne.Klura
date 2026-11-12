import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klura/app/klura_settings.dart';
import 'package:klura/core/grid.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/play/puzzle_sound.dart';
import 'package:klura/puzzles/bridges/bridges_board.dart';
import 'package:klura/puzzles/bridges/bridges_controller.dart';
import 'package:klura/puzzles/bridges/bridges_screen.dart';
import 'package:klura/puzzles/bridges/logic/bridge_arrangement.dart';
import 'package:klura/puzzles/bridges/logic/bridges_game.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_text.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';
import 'package:material_ui/material_ui.dart';

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

  var now = Duration.zero;
  late LocalStore store;
  late KluraSettings settings;
  late _RecordedSounds sounds;

  Future<BridgesController> pumpGame(
    WidgetTester tester,
    String board, {
    bool disableAnimations = false,
    Size screen = const Size(400, 800),
    double textScale = 1,
  }) async {
    final (:puzzle, :arrangement) = parseBridges(board);
    now = Duration.zero;
    final controller = BridgesController(
      level: BridgesLevel.normal,
      seedKey: 'test',
      game: BridgesGame(puzzle, arrangement),
      clock: () => now,
    );
    addTearDown(controller.dispose);
    store = MemoryLocalStore();
    settings = KluraSettings(store);
    addTearDown(settings.dispose);
    sounds = _RecordedSounds();
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: screen,
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: BridgesScreen(
            controller: controller,
            settings: settings,
            sound: sounds,
          ),
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

  /// What each live region on screen says, as a screen reader speaks it
  /// when it changes.
  List<String> liveRegionLabels() => [
    for (final node
        in find.semantics.byFlag(SemanticsFlag.isLiveRegion).evaluate())
      node.label,
  ];

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

  testWidgets('a click that slips a little still counts', (tester) async {
    final controller = await pumpGame(tester, crossing);
    final gap = centerOf(tester, controller, const Position(1, 2));

    // A mouse turns a press into a drag after two pixels.
    final gesture = await tester.startGesture(
      gap,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(3, 2));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.game.arrangement[across], 1);
  });

  testWidgets('a press on a bridge beside an island is about the bridge', (
    tester,
  ) async {
    // The bridge down column 1 passes right beside the island at (0, 2),
    // whose bridge to the right would cross it.
    final controller = await pumpGame(tester, '''
.1...
.....
1...1
.....
.1...
''');
    final beside = Connection(const Position(1, 0), const Position(1, 4));
    final blocked = Connection(const Position(0, 2), const Position(4, 2));
    controller.cycleBridges(beside);
    await tester.pumpAndSettle();
    final cell = cellSizeOf(tester, controller);
    // On the bridge's left edge, within reach of the island for a drag.
    final press =
        centerOf(tester, controller, const Position(1, 2)) -
        Offset(cell * 0.27, 0);

    await tester.dragFrom(press, Offset(cell * 1.2, 0));
    await tester.pumpAndSettle();

    expect(controller.game.arrangement[blocked], 0);
    expect(controller.game.arrangement[beside], 1);
    expect(
      find.textContaining('Bridges cannot cross each other.'),
      findsNothing,
    );

    final gesture = await tester.startGesture(
      press,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(3, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.game.arrangement[beside], 2);
  });

  testWidgets('a press on the bridge an island leaves from drags from it', (
    tester,
  ) async {
    final controller = await pumpGame(tester, crossing);
    controller.cycleBridges(across);
    await tester.pumpAndSettle();
    final cell = cellSizeOf(tester, controller);
    // On the bridge, beside the island at (0, 2) that it leaves from.
    final press =
        centerOf(tester, controller, const Position(0, 2)) +
        Offset(cell * 0.6, 0);

    await tester.dragFrom(press, Offset(cell * 1.2, 0));
    await tester.pumpAndSettle();

    expect(controller.game.arrangement[across], 2);
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

  testWidgets('two arrows pressed together move diagonally', (tester) async {
    // The island in the middle lies diagonally from the first one, which
    // has neighbors straight down and to the right. Down and then Right
    // alone would reach the island at the right end of row 3.
    final controller = await pumpGame(tester, '''
1.1
.2.
1.1
.1.
''');
    await tester.tapAt(centerOf(tester, controller, const Position(2, 3)));
    await tester.pump();

    // Down steps to the island below; Right while Down is held turns that
    // step into one down and to the right from the first island.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(
      controller.game.arrangement,
      BridgeArrangement({
        Connection(const Position(1, 1), const Position(1, 3)): 1,
      }),
    );
  });

  testWidgets('an arrow key gives the board the focus without moving', (
    tester,
  ) async {
    final controller = await pumpGame(tester, small);

    // Arrows with Alt and the like are left to the browser.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();

    expect(_boardHasFocus(), isFalse);

    // The first press only shows the focus ring on the first island, even
    // with Shift.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(_boardHasFocus(), isTrue);
    expect(controller.game.arrangement.isEmpty, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(controller.game.arrangement, BridgeArrangement({left: 1}));
  });

  testWidgets('an arrow key brings the focus back to the board', (
    tester,
  ) async {
    final controller = await pumpGame(tester, small);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<AppBar>(),
      isNotNull,
    );

    // The press leaves the focus ring on the first island, from which Shift
    // and Down builds; one step to the right would have nothing below.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(_boardHasFocus(), isTrue);
    expect(controller.game.arrangement, BridgeArrangement({left: 1}));
  });

  testWidgets('a solved board gives up the focus until a start over', (
    tester,
  ) async {
    final controller = await pumpGame(tester, small);
    await tester.tapAt(centerOf(tester, controller, const Position(1, 1)));
    await tester.pump();

    expect(_boardHasFocus(), isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(controller.game.isSolved, isTrue);
    expect(_boardHasFocus(), isFalse);

    await tester.tapAt(centerOf(tester, controller, const Position(1, 1)));
    await tester.pump();

    expect(_boardHasFocus(), isFalse);

    await tester.tap(find.text('Start over').hitTestable());
    await tester.pumpAndSettle();
    await tester.tapAt(centerOf(tester, controller, const Position(1, 1)));
    await tester.pump();

    expect(_boardHasFocus(), isTrue);
  });

  testWidgets('the move that solves the puzzle moves the focus to Done', (
    tester,
  ) async {
    final controller = await pumpGame(tester, small);
    await tester.tapAt(centerOf(tester, controller, const Position(1, 1)));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(controller.game.isSolved, isTrue);
    expect(Focus.of(tester.element(find.text('Done'))).hasPrimaryFocus, isTrue);

    // The solved board takes no moves, so an arrow does not bring the focus
    // back to it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    expect(_boardHasFocus(), isFalse);
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
        'Bridges board, 3 columns by 3 rows, 3 islands, 0 complete',
      ),
      findsOneWidget,
    );
    // The filled islands show progress, so it is not written out as well.
    expect(find.textContaining('complete'), findsNothing);

    controller.cycleBridges(top);
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(
        'Island 2, row 1, column 3. complete. 2 to the '
        'left',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Bridges board, 3 columns by 3 rows, 3 islands, 1 complete',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('the status line speaks its message alone', (tester) async {
    const problems =
        'Some bridges form a loop · An island has too many bridges';
    const notice = 'Board cleared. Undo brings the bridges back.';
    final semantics = tester.ensureSemantics();
    await pumpGame(tester, '''
2-4=1
|.|..
2-2..
''');
    await tester.pump();

    expect(liveRegionLabels(), [problems]);

    // Halfway through the fade from the problems to the notice, both are
    // on screen, but only the notice is said.
    await tester.tap(find.text('Start over').hitTestable());
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.textContaining(problems), findsOneWidget);
    expect(find.textContaining(notice), findsOneWidget);
    expect(liveRegionLabels(), [notice]);
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

  testWidgets('the numbers on the islands keep their size with large text', (
    tester,
  ) async {
    await pumpGame(tester, small);
    final number = tester.getSize(find.text('3'));
    final undo = tester.getSize(find.text('Undo'));

    await pumpGame(tester, small, textScale: 2);

    expect(tester.getSize(find.text('3')), number);
    expect(tester.getSize(find.text('Undo')).height, greaterThan(undo.height));
  });

  testWidgets('large text fits on a narrow phone', (tester) async {
    final controller = await pumpGame(
      tester,
      small,
      screen: const Size(320, 640),
      textScale: 2,
    );

    // A layout that overflows reports an exception.
    expect(tester.takeException(), isNull);

    controller
      ..cycleBridges(top)
      ..cycleBridges(top)
      ..cycleBridges(left);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Done').hitTestable(), findsOneWidget);
  });

  group('timer', () {
    testWidgets('shows the time played and counts while on screen', (
      tester,
    ) async {
      final controller = await pumpGame(tester, crossing);

      expect(controller.timer.isRunning, isTrue);
      expect(find.text('0:00'), findsOneWidget);

      now += const Duration(minutes: 1, seconds: 5);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('1:05'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Time played, 1 minute 5 seconds'),
        findsOneWidget,
      );
    });

    testWidgets('pauses while the app is hidden', (tester) async {
      final controller = await pumpGame(tester, crossing);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      now += const Duration(minutes: 10);

      expect(controller.timer.isRunning, isFalse);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      now += const Duration(seconds: 3);
      await tester.pump(const Duration(seconds: 1));

      expect(controller.timer.isRunning, isTrue);
      expect(controller.timer.elapsed, const Duration(seconds: 3));
    });

    testWidgets('pauses while how to play is open', (tester) async {
      final controller = await pumpGame(tester, crossing);
      now += const Duration(seconds: 4);

      await tester.tap(find.byTooltip('How to play'));
      await tester.pumpAndSettle();
      now += const Duration(minutes: 3);

      expect(find.text('How to play'), findsOneWidget);
      expect(controller.timer.isRunning, isFalse);
      expect(controller.timer.elapsed, const Duration(seconds: 4));

      // A tap above the sheet closes it.
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      now += const Duration(seconds: 2);

      expect(find.text('How to play'), findsNothing);
      expect(controller.timer.isRunning, isTrue);
      expect(controller.timer.elapsed, const Duration(seconds: 6));
    });

    testWidgets('stays paused when the app comes back to how to play', (
      tester,
    ) async {
      final controller = await pumpGame(tester, crossing);
      await tester.tap(find.byTooltip('How to play'));
      await tester.pumpAndSettle();

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      now += const Duration(minutes: 1);

      expect(controller.timer.isRunning, isFalse);
      expect(controller.timer.elapsed, Duration.zero);
    });

    testWidgets('pauses when the player leaves the game', (tester) async {
      final controller = await pumpGame(tester, crossing);
      now += const Duration(seconds: 8);

      await tester.pumpWidget(const SizedBox());
      now += const Duration(minutes: 1);

      expect(controller.timer.isRunning, isFalse);
      expect(controller.timer.elapsed, const Duration(seconds: 8));
    });

    testWidgets('hides on a tap and comes back from its icon', (tester) async {
      final controller = await pumpGame(tester, crossing);
      now += const Duration(seconds: 12);
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('0:12'));
      await tester.pump();

      expect(find.text('0:12'), findsNothing);
      expect(settings.showTimer, isFalse);
      expect(KluraSettings(store).showTimer, isFalse);
      expect(controller.timer.isRunning, isTrue);

      now += const Duration(seconds: 30);
      await tester.tap(find.byTooltip('Show timer'));
      await tester.pump();

      expect(find.text('0:42'), findsOneWidget);
      expect(settings.showTimer, isTrue);
    });

    testWidgets('the solved panel shows the time of the first solve', (
      tester,
    ) async {
      final controller = await pumpGame(tester, small, disableAnimations: true);
      now += const Duration(minutes: 2, seconds: 30);
      controller
        ..cycleBridges(top)
        ..cycleBridges(top)
        ..cycleBridges(left);
      now += const Duration(minutes: 1);
      await tester.pumpAndSettle();

      expect(find.text('Solved').hitTestable(), findsOneWidget);
      expect(find.text('  ·  2:30'), findsOneWidget);
      expect(find.text('2:30'), findsOneWidget);
      expect(controller.timer.isRunning, isFalse);

      settings.showTimer = false;
      await tester.pumpAndSettle();

      expect(find.text('  ·  All 3 islands are linked'), findsOneWidget);
      expect(find.textContaining('2:30'), findsNothing);
    });

    testWidgets('a screen reader hears the solve and its time', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = await pumpGame(tester, small, disableAnimations: true);
      now += const Duration(minutes: 2, seconds: 30);
      controller
        ..cycleBridges(top)
        ..cycleBridges(top)
        ..cycleBridges(left);
      await tester.pumpAndSettle();

      expect(liveRegionLabels(), ['Solved in 2 minutes 30 seconds']);

      settings.showTimer = false;
      await tester.pumpAndSettle();

      expect(liveRegionLabels(), ['Solved. All 3 islands are linked']);
      semantics.dispose();
    });
  });

  group('sound', () {
    testWidgets('each move plays the sound of the bridges it leaves', (
      tester,
    ) async {
      final controller = await pumpGame(tester, crossing);
      final gap = centerOf(tester, controller, const Position(1, 2));

      await tester.tapAt(gap);
      await tester.tapAt(gap);
      await tester.tapAt(gap);
      await tester.pumpAndSettle();

      expect(sounds.played, [
        PuzzleSound.bridge,
        PuzzleSound.doubleBridge,
        PuzzleSound.removed,
      ]);
    });

    testWidgets('a bridge that would cross another knocks', (tester) async {
      final controller = await pumpGame(tester, crossing);
      controller.cycleBridges(across);
      await tester.pumpAndSettle();
      final cell = cellSizeOf(tester, controller);

      await tester.dragFrom(
        centerOf(tester, controller, const Position(2, 0)),
        Offset(0, cell * 1.2),
      );
      await tester.pumpAndSettle();

      expect(sounds.played, [PuzzleSound.blocked]);
    });

    testWidgets('the move that solves the puzzle chimes instead', (
      tester,
    ) async {
      final controller = await pumpGame(tester, small);
      controller
        ..cycleBridges(top)
        ..cycleBridges(top);
      await tester.pumpAndSettle();

      await tester.tapAt(centerOf(tester, controller, const Position(0, 1)));
      await tester.pumpAndSettle();

      expect(controller.game.isSolved, isTrue);
      expect(sounds.played, [PuzzleSound.solved]);
    });

    testWidgets('undo, start over and moving the focus stay silent', (
      tester,
    ) async {
      final controller = await pumpGame(tester, small);
      await tester.tapAt(centerOf(tester, controller, const Position(1, 0)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start over').hitTestable());
      await tester.tap(find.text('Undo'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(controller.game.arrangement, BridgeArrangement({top: 1}));
      expect(sounds.played, [PuzzleSound.bridge]);
    });

    testWidgets('the speaker turns sounds off and on for every puzzle', (
      tester,
    ) async {
      final controller = await pumpGame(tester, crossing);
      final gap = centerOf(tester, controller, const Position(1, 2));
      expect(settings.playSounds, isTrue);

      await tester.tap(find.byTooltip('Turn sounds off'));
      await tester.pump();
      await tester.tapAt(gap);
      await tester.pumpAndSettle();

      expect(controller.game.arrangement[across], 1);
      expect(sounds.played, isEmpty);
      expect(KluraSettings(store).playSounds, isFalse);

      await tester.tap(find.byTooltip('Turn sounds on'));
      await tester.pump();
      await tester.tapAt(gap);
      await tester.pumpAndSettle();

      expect(sounds.played, [PuzzleSound.doubleBridge]);
      expect(KluraSettings(store).playSounds, isTrue);
    });
  });
}

bool _boardHasFocus() =>
    FocusManager.instance.primaryFocus?.debugLabel == 'Board';

/// Keeps every sound it is asked to play, in order.
final class _RecordedSounds implements SoundOutput {
  final List<PuzzleSound> played = [];

  @override
  void play(PuzzleSound sound) => played.add(sound);
}
