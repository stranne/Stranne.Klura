import 'package:klura/puzzles/tall_tales/logic/tall_tales_marks.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_puzzle.dart';

/// How a statement fares against the player's marks.
enum StatementStatus {
  /// Someone the statement depends on is unmarked, so it is not judged yet.
  open,

  /// Everyone it depends on is marked, and it is true for a truth-teller or
  /// false for a teller of tall tales.
  fits,

  /// Everyone it depends on is marked, and it is false for a truth-teller
  /// or true for a teller of tall tales.
  broken,
}

/// The result of judging the player's marks against the statements.
final class TallTalesCheck {
  const TallTalesCheck._(this.statuses);

  /// The status of each fisher's statement, in the order they sit.
  final List<StatementStatus> statuses;

  /// The fishers whose statements are broken, in the order they sit.
  List<int> get broken => [
    for (var fisher = 0; fisher < statuses.length; fisher++)
      if (statuses[fisher] == StatementStatus.broken) fisher,
  ];

  /// Whether every statement fits, which solves the puzzle.
  ///
  /// Every statement depends on its speaker, so this needs every fisher
  /// marked.
  bool get isSolved =>
      statuses.every((status) => status == StatementStatus.fits);
}

/// Judges [marks] against the statements of [puzzle].
///
/// A statement is judged once everyone it depends on is marked: its speaker
/// and the fishers it names, or every fisher for a count. Until then it
/// stays open, even where the marks so far already break it whatever the
/// rest turn out to be. A broken statement is then a plain fact about the
/// marks, never a deduction made for the player.
///
/// Throws an [ArgumentError] if [marks] is not for as many fishers as
/// [puzzle] has.
TallTalesCheck checkTallTales(TallTalesPuzzle puzzle, TallTalesMarks marks) {
  if (marks.length != puzzle.fisherCount) {
    throw ArgumentError.value(
      marks,
      'marks',
      'Must mark the ${puzzle.fisherCount} fishers of the puzzle',
    );
  }
  final marked = marks.marked;
  final truthful = marks.truthful;
  return TallTalesCheck._(
    List.unmodifiable([
      for (var speaker = 0; speaker < puzzle.fisherCount; speaker++)
        if (!puzzle.dependsOn(speaker).every((f) => (marked >> f) & 1 == 1))
          StatementStatus.open
        else if (puzzle.fitsSpeaker(speaker, truthful))
          StatementStatus.fits
        else
          StatementStatus.broken,
    ]),
  );
}
