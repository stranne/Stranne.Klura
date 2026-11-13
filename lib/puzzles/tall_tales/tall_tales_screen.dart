import 'package:klura/app/klura_settings.dart';
import 'package:klura/play/puzzle_screen.dart';
import 'package:klura/play/puzzle_sound.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_game.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_generator.dart';
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

/// Says that the marks do not solve [game] once every fisher is marked, or
/// returns `null`.
///
/// It never says which statement does not fit, nor how many. A fisher has
/// only two kinds, so naming a statement would all but name the fisher to
/// change, and a count would let the player home in by trial; finding the
/// mistake is the player's.
PuzzleNotice? _problemIn(TallTalesGame game) =>
    game.marks.isComplete && !game.isSolved
    ? (
        text: 'Every fisher is marked, but not every statement fits',
        isProblem: true,
      )
    : null;

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
          'Nothing is checked as you mark. Once every fisher is marked, you '
          'learn whether every statement fits, but not which one does not.',
    ),
    HowToPlayPoint(
      text:
          'With a keyboard, the arrow keys move between fishers, Space '
          'changes a mark and Ctrl and Z undoes.',
    ),
  ],
  marksName: 'marks',
);
