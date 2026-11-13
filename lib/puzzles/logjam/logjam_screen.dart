import 'package:klura/app/klura_settings.dart';
import 'package:klura/play/puzzle_screen.dart';
import 'package:klura/play/puzzle_sound.dart';
import 'package:klura/puzzles/logjam/logic/logjam_game.dart';
import 'package:klura/puzzles/logjam/logic/logjam_generator.dart';
import 'package:klura/puzzles/logjam/logjam_board_view.dart';
import 'package:klura/puzzles/logjam/logjam_controller.dart';
import 'package:material_ui/material_ui.dart';

/// The route name of the daily puzzle at [level], such as `/logjam/normal`.
String logjamRouteName(LogjamLevel level) => '/logjam/${level.name}';

/// The name of [level] as the player sees it.
String logjamLevelTitle(LogjamLevel level) => switch (level) {
  LogjamLevel.normal => 'Normal',
  LogjamLevel.hard => 'Hard',
};

/// [count] moves in words, such as `1 move` or `4 moves`.
String logjamMoves(int count) => count == 1 ? '1 move' : '$count moves';

/// Plays one game of Logjam: the river, the moves so far, the time played,
/// the sounds of slides, undo and starting over.
///
/// The game's timer runs while this screen is open and the app is in front.
/// After a solve the panel says how many moves it took and the fewest
/// possible, which gives a replay a goal without showing the way.
class LogjamScreen extends StatelessWidget {
  const LogjamScreen({
    required this.controller,
    required this.settings,
    required this.sound,
    super.key,
  });

  final LogjamController controller;

  /// Whether to show the time played and play the sounds of slides.
  final KluraSettings settings;

  /// Where the sounds of slides are heard.
  final SoundOutput sound;

  @override
  Widget build(BuildContext context) {
    return PuzzleScreen<LogjamGame>(
      title: 'Logjam · ${logjamLevelTitle(controller.level)}',
      controller: controller,
      settings: settings,
      sound: sound,
      board: (context, focusNode, showNotice, playSound) => LogjamBoardView(
        controller: controller,
        focusNode: focusNode,
        onSound: playSound,
      ),
      // A log in the way is no mistake, and the board shows it, so the
      // status line has nothing to name.
      problemIn: (game) => null,
      solvedMessage: _solvedMessage,
      countIn: (game) => logjamMoves(game.moves.length),
      resetNotice: 'Logs back where they began. Undo brings your moves back.',
      howToPlay: _howToPlay,
    );
  }

  /// `Solved in 15 moves · fewest possible 13`, or `Solved in 13 moves · the
  /// fewest possible` when they match.
  SolvedMessage _solvedMessage(LogjamGame game) {
    final moves = game.moves.length;
    final fewest = controller.fewestMoves;
    final title = 'Solved in ${logjamMoves(moves)}';
    return moves <= fewest
        ? (
            title: title,
            detail: 'the fewest possible',
            spoken: '$title, the fewest possible.',
          )
        : (
            title: title,
            detail: 'fewest possible $fewest',
            spoken: '$title. The fewest possible is $fewest.',
          );
  }
}

const HowToPlay _howToPlay = (
  rules: [
    HowToPlayPoint(
      marker: '1',
      text:
          'Logs lie along a row or a column and slide only along their '
          'length, as far as the water is clear. They never turn or pass '
          'each other.',
    ),
    HowToPlayPoint(
      marker: '2',
      text: 'One slide is one move, however far it goes.',
    ),
    HowToPlayPoint(
      marker: '3',
      text:
          'Free the marked log, the one with arrows, by sliding it out '
          'through the gap in the boom on the right.',
    ),
  ],
  controlsTitle: 'Moving logs',
  controls: [
    HowToPlayPoint(
      text:
          'Drag a log along its length and let go. It stops at the first '
          'log in its way. A tap shows how far a log can slide.',
    ),
    HowToPlayPoint(
      text:
          'With a keyboard, the arrow keys choose a log, Shift and an arrow '
          'slides it and Ctrl and Z undoes.',
    ),
    HowToPlayPoint(
      text:
          'Sliding the same log again straight away still counts as one '
          'move, and sliding it back to where it began takes the move back.',
    ),
    HowToPlayPoint(
      text:
          'When you solve the puzzle, you see your moves and the fewest '
          'possible.',
    ),
  ],
  marksName: 'moves',
);
