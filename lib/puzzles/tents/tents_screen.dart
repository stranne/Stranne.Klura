import 'package:klura/app/klura_settings.dart';
import 'package:klura/play/puzzle_screen.dart';
import 'package:klura/play/puzzle_sound.dart';
import 'package:klura/puzzles/tents/logic/tents_game.dart';
import 'package:klura/puzzles/tents/logic/tents_generator.dart';
import 'package:klura/puzzles/tents/logic/tents_rules.dart';
import 'package:klura/puzzles/tents/tents_board.dart';
import 'package:klura/puzzles/tents/tents_controller.dart';
import 'package:material_ui/material_ui.dart';

/// The route name of the daily puzzle at [level], such as `/tents/normal`.
String tentsRouteName(TentsLevel level) => '/tents/${level.name}';

/// The name of [level] as the player sees it.
String tentsLevelTitle(TentsLevel level) => switch (level) {
  TentsLevel.normal => 'Normal',
  TentsLevel.hard => 'Hard',
};

/// Plays one game of Tents: the board, the time played, the sounds of
/// moves, undo and starting over.
///
/// The game's timer runs while this screen is open and the app is in front.
class TentsScreen extends StatelessWidget {
  const TentsScreen({
    required this.controller,
    required this.settings,
    required this.sound,
    super.key,
  });

  final TentsController controller;

  /// Whether to show the time played and play the sounds of moves.
  final KluraSettings settings;

  /// Where the sounds of moves are heard.
  final SoundOutput sound;

  @override
  Widget build(BuildContext context) {
    return PuzzleScreen<TentsGame>(
      title: 'Tents · ${tentsLevelTitle(controller.level)}',
      controller: controller,
      settings: settings,
      sound: sound,
      board: (context, focusNode, showNotice, playSound) => TentsBoard(
        controller: controller,
        focusNode: focusNode,
        onSound: playSound,
      ),
      problemIn: _problemIn,
      solvedDetail:
          'All ${controller.game.puzzle.trees.length} trees have a tent',
      resetNotice: 'Board cleared. Undo brings the tents back.',
      howToPlay: _howToPlay,
    );
  }
}

/// Names what in [game] the player should look at, or returns `null` when
/// nothing is wrong. Progress itself shows on the board, in the numbers
/// that fade once met.
PuzzleNotice? _problemIn(TentsGame game) {
  final check = game.check;
  final overRows = check.rowStatuses.where(_isOver).length;
  final overColumns = check.columnStatuses.where(_isOver).length;
  final withoutTree = check.tentsWithoutTree.length;
  final problems = [
    if (check.touching.isNotEmpty) 'Some tents touch',
    if (withoutTree == 1) 'A tent has no tree beside it',
    if (withoutTree > 1) '$withoutTree tents have no tree beside them',
    if (check.tentsSharingTree.isNotEmpty) 'Some tents have to share a tree',
    if (overRows + overColumns > 0)
      switch ((overRows, overColumns)) {
        (1, 0) => 'A row has too many tents',
        (0, 1) => 'A column has too many tents',
        (_, 0) => 'Some rows have too many tents',
        (0, _) => 'Some columns have too many tents',
        _ => 'Some rows and columns have too many tents',
      },
  ];
  return problems.isEmpty
      ? null
      : (text: problems.join(' · '), isProblem: true);
}

bool _isOver(LineStatus status) => status == LineStatus.over;

const HowToPlay _howToPlay = (
  rules: [
    HowToPlayPoint(
      marker: '1',
      text:
          'Each tree needs a tent of its own, directly above, below, left '
          'or right of it.',
    ),
    HowToPlayPoint(
      marker: '2',
      text: 'Tents never touch each other, not even diagonally.',
    ),
    HowToPlayPoint(
      marker: '3',
      text:
          'The numbers beside the grid tell how many tents each row and '
          'column holds.',
    ),
  ],
  controlsTitle: 'Placing tents',
  controls: [
    HowToPlayPoint(
      text:
          'Tap a cell once for grass, twice for a tent and a third time to '
          'clear it. Grass is only a note for cells where no tent can go.',
    ),
    HowToPlayPoint(
      text:
          'Drag along a row or column to put grass on every empty cell on '
          'the way. A drag that starts on grass clears grass instead.',
    ),
    HowToPlayPoint(
      text:
          'With a keyboard, the arrow keys move between cells, Space '
          'changes a cell and Ctrl and Z undoes.',
    ),
  ],
  marksName: 'tents and grass',
);
