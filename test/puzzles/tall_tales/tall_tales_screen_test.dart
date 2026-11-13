import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klura/app/klura_settings.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/play/puzzle_sound.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_game.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_generator.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_text.dart';
import 'package:klura/puzzles/tall_tales/tall_tales_board.dart';
import 'package:klura/puzzles/tall_tales/tall_tales_controller.dart';
import 'package:klura/puzzles/tall_tales/tall_tales_screen.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // Solved by Alva telling the truth, and Bo and Cajsa tall tales.
  const small = '''
Alva: Bo and I are not alike.
Bo: Cajsa tells the truth.
Cajsa: Alva tells tall tales.
''';

  // A daily puzzle of the most fishers, with long statements.
  final hard = formatTallTales(
    generateDailyTallTales(TallTalesLevel.hard, DateTime(2026, 11, 13)).puzzle,
  );

  late KluraSettings settings;
  late _RecordedSounds sounds;

  Future<TallTalesController> pumpGame(
    WidgetTester tester,
    String text, {
    bool disableAnimations = false,
    double textScale = 1,
    Size size = const Size(400, 800),
  }) async {
    final (puzzle, marks) = parseTallTales(text);
    final controller = TallTalesController(
      level: TallTalesLevel.normal,
      seedKey: 'test',
      game: TallTalesGame(puzzle, marks),
      clock: () => Duration.zero,
    );
    addTearDown(controller.dispose);
    settings = KluraSettings(MemoryLocalStore());
    addTearDown(settings.dispose);
    sounds = _RecordedSounds();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: TallTalesScreen(
            controller: controller,
            settings: settings,
            sound: sounds,
          ),
        ),
      ),
    );
    return controller;
  }

  /// The plank of the fisher called [name], whose words begin with the
  /// name.
  Finder plank(String name) => find.descendant(
    of: find.byType(TallTalesBoard),
    matching: find.textContaining(RegExp('^$name  “')),
  );

  Future<void> tapPlank(WidgetTester tester, String name) async {
    await tester.tap(plank(name));
    await tester.pump();
  }

  String marksOf(TallTalesController controller) =>
      formatTallTales(controller.game.puzzle, controller.game.marks);

  testWidgets('a tap moves a fisher through the truth, tall tales and none', (
    tester,
  ) async {
    final controller = await pumpGame(tester, small);

    await tapPlank(tester, 'Bo');
    expect(find.text('Truth'), findsOneWidget);

    await tapPlank(tester, 'Bo');
    expect(find.text('Tall tales'), findsOneWidget);

    await tapPlank(tester, 'Bo');
    expect(controller.game.isBlank, isTrue);
    expect(controller.game.canUndo, isTrue);
  });

  testWidgets('shows each statement after its speaker', (tester) async {
    await pumpGame(tester, small);

    // Each name in a statement has its mark beside it, a placeholder in the
    // plain text.
    expect(
      find.textContaining('Alva  “Bo￼ and I are not alike.”'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Cajsa  “Alva￼ tells tall tales.”'),
      findsOneWidget,
    );
  });

  testWidgets('names a statement that does not fit in words', (tester) async {
    await pumpGame(tester, '''
+ Alva: Bo and I are not alike.
+ Bo: Cajsa tells the truth.
. Cajsa: Alva tells tall tales.
''');

    expect(
      find.textContaining(
        "Alva's statement is false, but Alva is marked as telling the truth",
      ),
      findsOneWidget,
    );
  });

  testWidgets('names a true statement from a teller of tall tales', (
    tester,
  ) async {
    await pumpGame(tester, '''
- Alva: Bo and I are not alike.
+ Bo: Cajsa tells the truth.
. Cajsa: Alva tells tall tales.
''');

    expect(
      find.textContaining(
        "Alva's statement is true, but Alva is marked as telling tall tales",
      ),
      findsOneWidget,
    );
  });

  testWidgets('lists every statement that does not fit', (tester) async {
    await pumpGame(tester, '''
- Alva: Bo and I are not alike.
+ Bo: Cajsa tells the truth.
- Cajsa: Alva tells tall tales.
''');

    expect(
      find.textContaining(
        'The statements of Alva, Bo and Cajsa do not fit their marks',
      ),
      findsOneWidget,
    );
  });

  testWidgets('says nothing while the marks so far fit', (tester) async {
    await pumpGame(tester, '''
+ Alva: Bo and I are not alike.
- Bo: Cajsa tells the truth.
. Cajsa: Alva tells tall tales.
''');

    expect(find.textContaining('marked as'), findsNothing);
    expect(find.textContaining('do not fit'), findsNothing);
  });

  testWidgets('solving shows the solved message and locks the jetty', (
    tester,
  ) async {
    final controller = await pumpGame(tester, '''
+ Alva: Bo and I are not alike.
- Bo: Cajsa tells the truth.
+ Cajsa: Alva tells tall tales.
''');

    await tapPlank(tester, 'Cajsa');
    await tester.pumpAndSettle();

    expect(controller.game.isSolved, isTrue);
    expect(find.text('Solved'), findsOneWidget);

    await tapPlank(tester, 'Alva');

    expect(marksOf(controller), '''
+ Alva: Bo and I are not alike.
- Bo: Cajsa tells the truth.
- Cajsa: Alva tells tall tales.
''');
  });

  testWidgets('the arrow keys move between fishers and Space marks one', (
    tester,
  ) async {
    final controller = await pumpGame(tester, small);
    await tapPlank(tester, 'Alva');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(marksOf(controller), '''
+ Alva: Bo and I are not alike.
- Bo: Cajsa tells the truth.
+ Cajsa: Alva tells tall tales.
''');
  });

  testWidgets('an arrow key gives the jetty the focus on the first fisher', (
    tester,
  ) async {
    final controller = await pumpGame(tester, small);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(marksOf(controller), '''
+ Alva: Bo and I are not alike.
. Bo: Cajsa tells the truth.
. Cajsa: Alva tells tall tales.
''');
  });

  testWidgets('describes each fisher for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = await pumpGame(tester, '''
+ Alva: Bo and I are not alike.
+ Bo: Cajsa tells the truth.
. Cajsa: Alva tells tall tales.
''');

    expect(
      tester.getSemantics(plank('Alva')),
      matchesSemantics(
        label:
            'Alva says: Bo and I are not alike. Marked as telling the '
            'truth. Does not fit the marks.',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(plank('Cajsa')).label,
      'Cajsa says: Alva tells tall tales. Unmarked.',
    );

    tester.semantics.tap(find.semantics.byLabel(RegExp('^Cajsa says')));
    await tester.pump();

    expect(controller.game.marks[2], isNotNull);
    semantics.dispose();
  });

  testWidgets('scrolls a full jetty with large text, without overflow', (
    tester,
  ) async {
    await pumpGame(tester, hard, textScale: 2, size: const Size(360, 640));

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsWidgets);

    await tester.dragUntilVisible(
      plank('Hugo'),
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.tap(plank('Hugo'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('start over clears the marks and undo brings them back', (
    tester,
  ) async {
    final controller = await pumpGame(tester, '''
+ Alva: Bo and I are not alike.
- Bo: Cajsa tells the truth.
. Cajsa: Alva tells tall tales.
''');

    await tester.tap(find.text('Start over').hitTestable());
    await tester.pump();

    expect(controller.game.isBlank, isTrue);
    expect(find.text('Marks cleared. Undo brings them back.'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(controller.game.marks.marked, 0x3);
  });

  testWidgets('explains the rules', (tester) async {
    await pumpGame(tester, small);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Each fisher on the jetty either always tells the truth or always '
        'tells tall tales.',
      ),
      findsOneWidget,
    );
    expect(find.text('Marking fishers'), findsOneWidget);
  });

  group('sound', () {
    testWidgets('each tap plays the sound of the new mark', (tester) async {
      await pumpGame(tester, small);

      await tapPlank(tester, 'Bo');
      await tapPlank(tester, 'Bo');
      await tapPlank(tester, 'Bo');

      expect(sounds.played, [
        PuzzleSound.truth,
        PuzzleSound.tallTales,
        PuzzleSound.removed,
      ]);
    });

    testWidgets('the move that solves the puzzle chimes instead', (
      tester,
    ) async {
      await pumpGame(tester, '''
+ Alva: Bo and I are not alike.
- Bo: Cajsa tells the truth.
+ Cajsa: Alva tells tall tales.
''');

      await tapPlank(tester, 'Cajsa');
      await tester.pumpAndSettle();

      expect(sounds.played, [PuzzleSound.solved]);
    });

    testWidgets('moving the focus stays silent', (tester) async {
      await pumpGame(tester, small);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(sounds.played, isEmpty);
    });

    testWidgets('a solve with reduced motion still chimes', (tester) async {
      await pumpGame(tester, '''
+ Alva: Bo and I are not alike.
- Bo: Cajsa tells the truth.
+ Cajsa: Alva tells tall tales.
''', disableAnimations: true);

      await tapPlank(tester, 'Cajsa');
      await tester.pump();

      expect(sounds.played, [PuzzleSound.solved]);
    });
  });
}

final class _RecordedSounds implements SoundOutput {
  final List<PuzzleSound> played = [];

  @override
  void play(PuzzleSound sound) => played.add(sound);
}
