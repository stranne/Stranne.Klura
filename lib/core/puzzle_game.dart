/// A game in progress as every puzzle screen sees it.
///
/// Each puzzle's game is an immutable value that remembers the game before
/// each move, so a move or an undo returns another game.
abstract interface class PuzzleGame {
  /// Whether the player's marks meet every rule, which solves the puzzle.
  bool get isSolved;

  /// Whether the board has none of the player's marks.
  bool get isBlank;

  /// Whether an undo would take back a move.
  bool get canUndo;

  /// Whether starting over would clear anything.
  bool get canReset;
}
