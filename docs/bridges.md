# Bridges

Bridges is the first Klura puzzle. It belongs to the genre known as
Hashiwokakero or Hashi. Klura uses its own puzzles, visuals and wording; it
does not copy puzzles or visuals from any published version.

## Rules

1. Each island shows how many bridges touch it.
2. Bridges run straight horizontally or vertically between two islands, with
   at most two bridges between the same pair.
3. Bridges never cross each other or pass over an island.
4. All islands are connected.
5. There are no loops: exactly one route links any two islands. A double
   bridge counts as one connection, not a loop.

Rule 5 makes every solution a tree. A board with N islands therefore has
exactly N - 1 connected pairs.

## Daily puzzle

The puzzle of the day is generated on the device from
`dailySeedKey(puzzleId: 'bridges', generatorVersion: ..., date: localDate)`,
for example `bridges:v1:2026-11-11`. Generation uses only `SeededRandom`.
Increase the generator version whenever a change would alter the puzzle for an
existing key, and save the puzzle itself together with the player's progress.

## Planned generator

The approach follows the earlier C# prototype in
`C:\Source\Stranne.HahiPuzzle` (`Stranne.HashiPuzzle.Logic`). Port the design,
not the code verbatim:

1. Place islands on the grid.
2. Build a random spanning tree of straight, non-crossing connections.
3. Choose one or two bridges for each connection and derive the island
   numbers.
4. Run a solver that enforces every rule above, including the no-loop rule,
   and accept the puzzle only when it has exactly one solution. Otherwise
   retry with the next derived seed.

Generation must finish well under a second in a phone browser. Difficulty
starts as grid size and island count; grading by deduction technique can come
later.

The game accepts any arrangement that satisfies the rules rather than
comparing with a stored solution, so a generator mistake can never reject a
correct answer.

## Interaction goals for version 1

- Drag from an island toward a neighbor to add a bridge; tap a bridge to cycle
  between one, two and none.
- A bridge that would cross another is not placed; give a small shake instead
  of an error message.
- Islands change appearance when their count is met. Gently mark overfull
  islands and closed loops.
- Unlimited undo, automatic saving, an optional quiet timer and a short
  completion animation.
- No accounts, ads or hints in version 1.
