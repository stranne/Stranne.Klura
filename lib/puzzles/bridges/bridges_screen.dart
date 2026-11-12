import 'package:klura/app/klura_settings.dart';
import 'package:klura/play/puzzle_screen.dart';
import 'package:klura/puzzles/bridges/bridges_board.dart';
import 'package:klura/puzzles/bridges/bridges_controller.dart';
import 'package:klura/puzzles/bridges/logic/bridges_game.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_rules.dart';
import 'package:material_ui/material_ui.dart';

/// The route name of the daily puzzle at [level], such as `/bridges/normal`.
String bridgesRouteName(BridgesLevel level) => '/bridges/${level.name}';

/// The name of [level] as the player sees it.
String bridgesLevelTitle(BridgesLevel level) => switch (level) {
  BridgesLevel.normal => 'Normal',
  BridgesLevel.hard => 'Hard',
};

/// Plays one game of Bridges: the board, how far the player has come, the
/// time played, undo and starting over.
///
/// The game's timer runs while this screen is open and the app is in front.
class BridgesScreen extends StatelessWidget {
  const BridgesScreen({
    required this.controller,
    required this.settings,
    super.key,
  });

  final BridgesController controller;

  /// Whether to show the time played.
  final KluraSettings settings;

  @override
  Widget build(BuildContext context) {
    return PuzzleScreen<BridgesGame>(
      title: 'Bridges · ${bridgesLevelTitle(controller.level)}',
      controller: controller,
      settings: settings,
      board: (context, showNotice) => BridgesBoard(
        controller: controller,
        onBlocked: () => showNotice((
          text: 'Bridges cannot cross each other.',
          isProblem: true,
        )),
      ),
      problemIn: _problemIn,
      solvedDetail:
          'All ${controller.game.puzzle.islands.length} islands are linked',
      resetNotice: 'Board cleared. Undo brings the bridges back.',
      howToPlay: _howToPlay,
    );
  }
}

/// Names what in [game] the player should look at, or returns `null` when
/// nothing is wrong. Progress itself shows on the board, in the filled
/// islands.
PuzzleNotice? _problemIn(BridgesGame game) {
  final check = game.check;
  final statuses = check.islandStatuses.values;
  final over = statuses.where((status) => status == IslandStatus.over).length;
  final met = statuses.where((status) => status == IslandStatus.met).length;
  final problems = [
    if (check.hasLoops) 'Some bridges form a loop',
    if (over == 1) 'An island has too many bridges',
    if (over > 1) '$over islands have too many bridges',
  ];
  if (problems.isNotEmpty) {
    return (text: problems.join(' · '), isProblem: true);
  }
  if (met == game.puzzle.islands.length && !check.isConnected) {
    return (
      text: 'Every number is met, but not all islands are linked',
      isProblem: true,
    );
  }
  return null;
}

const HowToPlay _howToPlay = (
  rules: [
    HowToPlayPoint(
      marker: '1',
      text: 'Each number tells how many bridges touch that island.',
    ),
    HowToPlayPoint(
      marker: '2',
      text:
          'Bridges run straight across or down, never diagonally. '
          'Two islands can share one or two bridges.',
    ),
    HowToPlayPoint(
      marker: '3',
      text: 'Bridges never cross each other or pass over an island.',
    ),
    HowToPlayPoint(marker: '4', text: 'Link all the islands into one group.'),
    HowToPlayPoint(
      marker: '5',
      text:
          'No loops: there is only one way along the bridges from '
          'any island to any other. A double bridge is not a loop.',
    ),
  ],
  controlsTitle: 'Building bridges',
  controls: [
    HowToPlayPoint(
      text:
          'Drag from an island toward a neighbor to build a bridge. '
          'Do it again for a second bridge, and once more to remove '
          'them.',
    ),
    HowToPlayPoint(
      text:
          'Tap a bridge, or the gap where one can go, to switch '
          'between one, two and no bridges.',
    ),
    HowToPlayPoint(
      text:
          'With a keyboard, the arrow keys move between islands, and two '
          'arrows pressed together move diagonally. Shift and an arrow '
          'builds a bridge, and Ctrl and Z undoes.',
    ),
  ],
  marksName: 'bridges',
);
