import 'package:klura/app/klura_settings.dart';
import 'package:klura/play/puzzle_screen.dart';
import 'package:klura/play/puzzle_sound.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_game.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_generator.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_marks.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_puzzle.dart';
import 'package:klura/puzzles/tall_tales/tall_tales_board.dart';
import 'package:klura/puzzles/tall_tales/tall_tales_controller.dart';
import 'package:material_ui/material_ui.dart';

/// The route name of the daily puzzle at [level], such as
/// `/tall-tales/normal`.
String tallTalesRouteName(TallTalesLevel level) => '/tall-tales/${level.name}';

/// The name of [level] as the player sees it.
String tallTalesLevelTitle(TallTalesLevel level) => switch (level) {
  TallTalesLevel.normal => 'Normal',
  TallTalesLevel.hard => 'Hard',
};

/// Plays one game of Tall Tales: the jetty, the time played, the sounds of
/// moves, undo and starting over.
///
/// The game's timer runs while this screen is open and the app is in front.
class TallTalesScreen extends StatelessWidget {
  const TallTalesScreen({
    required this.controller,
    required this.settings,
    required this.sound,
    super.key,
  });

  final TallTalesController controller;

  /// Whether to show the time played and play the sounds of moves.
  final KluraSettings settings;

  /// Where the sounds of moves are heard.
  final SoundOutput sound;

  @override
  Widget build(BuildContext context) {
    return PuzzleScreen<TallTalesGame>(
      title: 'Tall Tales · ${tallTalesLevelTitle(controller.level)}',
      controller: controller,
      settings: settings,
      sound: sound,
      board: (context, focusNode, showNotice, playSound) => TallTalesBoard(
        controller: controller,
        focusNode: focusNode,
        onSound: playSound,
      ),
      problemIn: _problemIn,
      solvedDetail: 'All ${controller.game.puzzle.fisherCount} statements fit',
      resetNotice: 'Marks cleared. Undo brings them back.',
      howToPlay: _howToPlay,
    );
  }
}

/// Names the statements in [game] that do not fit their marks, or returns
/// `null` when none is broken. A statement is judged only once everyone it
/// depends on is marked, so this never runs ahead of the player.
PuzzleNotice? _problemIn(TallTalesGame game) {
  final broken = game.check.broken;
  if (broken.isEmpty) {
    return null;
  }
  if (broken case [final fisher]) {
    final name = tallTalesNames[fisher];
    return (
      text: switch (game.marks[fisher]) {
        TallTalesMark.truth =>
          "$name's statement is false, but $name is marked as telling the "
              'truth',
        _ =>
          "$name's statement is true, but $name is marked as telling tall "
              'tales',
      },
      isProblem: true,
    );
  }
  final names = [for (final fisher in broken) tallTalesNames[fisher]];
  final listed =
      '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  return (
    text: 'The statements of $listed do not fit their marks',
    isProblem: true,
  );
}

const HowToPlay _howToPlay = (
  rules: [
    HowToPlayPoint(
      marker: '1',
      text:
          'Each fisher on the jetty either always tells the truth or always '
          'tells tall tales.',
    ),
    HowToPlayPoint(
      marker: '2',
      text:
          "A truth-teller's statement is true. A teller of tall tales' "
          'statement is false.',
    ),
    HowToPlayPoint(
      marker: '3',
      text:
          'Mark every fisher. Only one way of marking them makes every '
          'statement fit.',
    ),
    HowToPlayPoint(
      marker: '4',
      text:
          'Two fishers are alike when both tell the truth or both tell tall '
          'tales. Us means everyone on the jetty.',
    ),
  ],
  controlsTitle: 'Marking fishers',
  controls: [
    HowToPlayPoint(
      text:
          'Tap a fisher once for the truth, twice for tall tales and a third '
          'time to clear the mark.',
    ),
    HowToPlayPoint(
      text:
          'Once everyone a statement depends on is marked, a statement that '
          'does not fit gets a red edge.',
    ),
    HowToPlayPoint(
      text:
          'With a keyboard, the arrow keys move between fishers, Space '
          'changes a mark and Ctrl and Z undoes.',
    ),
  ],
  marksName: 'marks',
);
