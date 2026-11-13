import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klura/app/klura_settings.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/play/puzzle_sound.dart';
import 'package:klura/puzzles/logjam/logic/logjam_board.dart';
import 'package:klura/puzzles/logjam/logic/logjam_game.dart';
import 'package:klura/puzzles/logjam/logic/logjam_generator.dart';
import 'package:klura/puzzles/logjam/logic/logjam_text.dart';
import 'package:klura/puzzles/logjam/logjam_board_geometry.dart';
import 'package:klura/puzzles/logjam/logjam_board_view.dart';
import 'package:klura/puzzles/logjam/logjam_controller.dart';
import 'package:klura/puzzles/logjam/logjam_screen.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // Solved in two moves: B down 1, then the marked log right 1.
  final small = parseLogjam('''
A...
A**B>
...B
CC..
''');
  const marked = 0;
  const b = 2;
  const c = 3;

  late KluraSettings settings;
  late _RecordedSounds sounds;

  Future<LogjamController> pumpGame(
    WidgetTester tester, {
    double textScale = 1,
    LogjamBoard? puzzle,
  }) async {
    final controller = LogjamController(
      level: LogjamLevel.normal,
      seedKey: 'test',
      game: LogjamGame(puzzle ?? small),
      fewestMoves: 2,
      clock: () => Duration.zero,
    );
    addTearDown(controller.dispose);
    settings = KluraSettings(MemoryLocalStore());
    addTearDown(settings.dispose);
    sounds = _RecordedSounds();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 800),
            textScaler: TextScaler.linear(textScale),
          ),
          child: LogjamScreen(
            controller: controller,
            settings: settings,
            sound: sounds,
          ),
        ),
      ),
    );
    return controller;
  }

  /// The geometry of the [small] board on screen and where it lies, in
  /// global coordinates.
  (LogjamBoardGeometry, Offset) geometryOf(WidgetTester tester) {
    final board = tester.getRect(
      find
          .descendant(
            of: find.byType(LogjamBoardView),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    final geometry = LogjamBoardGeometry(
      width: small.width,
      height: small.height,
      cellSize: board.width / LogjamBoardGeometry.widthInCells(small.width),
    );
    return (geometry, board.topLeft);
  }

  /// Drags the log at [piece] by [cells] along a row, or down a column if
  /// [down], from the middle of its first cell.
  Future<void> dragLog(
    WidgetTester tester,
    LogjamController controller,
    int piece,
    double cells, {
    bool down = false,
  }) async {
    final (geometry, origin) = geometryOf(tester);
    final log = controller.game.board.pieces[piece];
    final start = origin + geometry.rectOf(log.cells.first).center;
    final distance = cells * geometry.cellSize;
    await tester.dragFrom(
      start,
      down ? Offset(0, distance) : Offset(distance, 0),
    );
    await tester.pump();
  }

  Future<void> tapLog(
    WidgetTester tester,
    LogjamController controller,
    int piece,
  ) async {
    final (geometry, origin) = geometryOf(tester);
    final log = controller.game.board.pieces[piece];
    await tester.tapAt(origin + geometry.rectOf(log.cells.first).center);
    await tester.pump();
  }

  Future<void> shiftArrow(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
  }

  testWidgets('a drag slides a log along its length to the nearest cell', (
    tester,
  ) async {
    final controller = await pumpGame(tester);
    expect(find.text('0 moves'), findsOneWidget);

    await dragLog(tester, controller, c, 1.6);

    expect(
      controller.game.board.pieces[c],
      const LogjamPiece.horizontal(2, 3, 2),
    );
    expect(controller.game.moves, const [LogjamMove(piece: c, to: 2)]);
    expect(find.text('1 move'), findsOneWidget);
    expect(sounds.played, [PuzzleSound.log]);
  });

  testWidgets('a log pushed against another stops there and knocks', (
    tester,
  ) async {
    final controller = await pumpGame(tester);

    await dragLog(tester, controller, marked, 1);
    await tester.pumpAndSettle();

    expect(controller.game.moves, isEmpty);
    expect(sounds.played, [PuzzleSound.blocked]);
  });

  testWidgets('a drag across a log or a tap moves nothing', (tester) async {
    final controller = await pumpGame(tester);

    await dragLog(tester, controller, c, -1, down: true);
    await tapLog(tester, controller, c);
    await tester.pumpAndSettle();

    expect(controller.game.moves, isEmpty);
    expect(sounds.played, isEmpty);
  });

  testWidgets('slides of the same log in a row count as one move', (
    tester,
  ) async {
    final controller = await pumpGame(tester);

    await dragLog(tester, controller, c, 1);
    await dragLog(tester, controller, c, 1);

    expect(find.text('1 move'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(controller.game.board, small);
    expect(find.text('0 moves'), findsOneWidget);
  });

  testWidgets('an undo during a drag ends the drag without a move', (
    tester,
  ) async {
    final controller = await pumpGame(tester);
    await dragLog(tester, controller, c, 2);
    final (geometry, origin) = geometryOf(tester);

    final gesture = await tester.startGesture(
      origin +
          geometry.rectOf(controller.game.board.pieces[1].cells.first).center,
    );
    await gesture.moveBy(Offset(0, geometry.cellSize * 0.5));
    await gesture.moveBy(Offset(0, geometry.cellSize * 0.5));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.game.moves, isEmpty);
    expect(controller.game.board, small);
  });

  testWidgets('start over puts the logs back and undo brings the moves back', (
    tester,
  ) async {
    final controller = await pumpGame(tester);
    await dragLog(tester, controller, c, 2);

    await tester.tap(find.text('Start over').hitTestable());
    await tester.pump();

    expect(controller.game.board, small);
    expect(
      find.text('Logs back where they began. Undo brings your moves back.'),
      findsOneWidget,
    );
    expect(sounds.played, [PuzzleSound.log]);

    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(controller.game.moves, const [LogjamMove(piece: c, to: 2)]);
  });

  testWidgets('solving floats the marked log out and shows the moves', (
    tester,
  ) async {
    final controller = await pumpGame(tester);

    await dragLog(tester, controller, b, 1, down: true);
    await dragLog(tester, controller, marked, 1);
    await tester.pumpAndSettle();

    expect(controller.game.isSolved, isTrue);
    expect(sounds.played, [PuzzleSound.log, PuzzleSound.solved]);
    expect(find.text('Solved in 2 moves'), findsOneWidget);
    expect(find.textContaining('the fewest possible'), findsOneWidget);

    // A solved board takes no moves.
    await dragLog(tester, controller, c, 2);
    expect(controller.game.moves, hasLength(2));
  });

  testWidgets('a solve in more moves names the fewest possible', (
    tester,
  ) async {
    final controller = await pumpGame(tester);

    await dragLog(tester, controller, c, 1);
    await dragLog(tester, controller, b, 1, down: true);
    await dragLog(tester, controller, marked, 1);
    await tester.pumpAndSettle();

    expect(find.text('Solved in 3 moves'), findsOneWidget);
    expect(find.textContaining('fewest possible 2'), findsOneWidget);
    expect(controller.bestMoves, 3);
  });

  testWidgets('the arrow keys choose a log and Shift with one slides it', (
    tester,
  ) async {
    final controller = await pumpGame(tester);

    // The first arrow gives the board the focus, on the marked log.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await shiftArrow(tester, LogicalKeyboardKey.arrowRight);
    await shiftArrow(tester, LogicalKeyboardKey.arrowUp);

    expect(controller.game.moves, isEmpty);
    expect(sounds.played, [PuzzleSound.blocked]);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await shiftArrow(tester, LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await shiftArrow(tester, LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(controller.game.moves, const [
      LogjamMove(piece: b, to: 2),
      LogjamMove(piece: marked, to: 2),
    ]);
    expect(controller.game.isSolved, isTrue);
    expect(sounds.played, [
      PuzzleSound.blocked,
      PuzzleSound.log,
      PuzzleSound.solved,
    ]);
  });

  testWidgets('an arrow moves to the log beside rather than a row away', (
    tester,
  ) async {
    final controller = await pumpGame(
      tester,
      puzzle: parseLogjam('''
......
..AAA.
.**.B.>
....B.
......
......
'''),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await shiftArrow(tester, LogicalKeyboardKey.arrowDown);

    expect(controller.game.moves, const [LogjamMove(piece: 2, to: 3)]);
  });

  testWidgets('cell by cell with the keys is still one move', (tester) async {
    final controller = await pumpGame(tester);
    await tapLog(tester, controller, c);

    await shiftArrow(tester, LogicalKeyboardKey.arrowRight);
    await shiftArrow(tester, LogicalKeyboardKey.arrowRight);

    expect(controller.game.moves, const [LogjamMove(piece: c, to: 2)]);
    expect(find.text('1 move'), findsOneWidget);
  });

  testWidgets('describes the board and each log for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpGame(tester);

    expect(
      find.bySemanticsLabel(
        'Logjam board, 4 columns by 4 rows, 4 logs. The gap in the boom is '
        'at the right end of row 2. The marked log lies in row 2, columns 2 '
        'to 3.',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Marked log, 2 cells, row 2, columns 2 to 3, cannot slide',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Log, 2 cells, column 4, rows 2 to 3, can slide 1 up and 1 down',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Log, 2 cells, row 4, columns 1 to 2, can slide '
        '2 right',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('the solved message wraps rather than cuts off large text', (
    tester,
  ) async {
    final controller = await pumpGame(tester, textScale: 2);

    controller
      ..slide(const LogjamMove(piece: c, to: 1))
      ..slide(const LogjamMove(piece: b, to: 2))
      ..slide(const LogjamMove(piece: marked, to: 2));
    await tester.pumpAndSettle();

    final detail = find.textContaining('fewest possible 2');
    expect(detail, findsOneWidget);
    expect(
      tester.getRect(detail).top,
      greaterThanOrEqualTo(
        tester.getRect(find.text('Solved in 3 moves')).bottom,
      ),
    );
  });

  testWidgets('explains the rules', (tester) async {
    await pumpGame(tester);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pumpAndSettle();

    expect(
      find.text('One slide is one move, however far it goes.'),
      findsOneWidget,
    );
    expect(find.text('Moving logs'), findsOneWidget);
  });
}

/// Keeps every sound it is asked to play, in order.
final class _RecordedSounds implements SoundOutput {
  final List<PuzzleSound> played = [];

  @override
  void play(PuzzleSound sound) => played.add(sound);
}
