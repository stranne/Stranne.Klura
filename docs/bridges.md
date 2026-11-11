# Bridges

Bridges is the first Klura puzzle. It belongs to the genre known as
Hashiwokakero or Hashi. Klura uses its own puzzles, visuals and wording; it
does not copy puzzles or visuals from any published version.

## Rules

1. Each island shows how many bridges touch it.
2. Bridges run straight horizontally or vertically between two islands, never
   diagonally, with at most two bridges between the same pair.
3. Bridges never cross each other or pass over an island.
4. All islands are connected.
5. There are no loops: exactly one route links any two islands. A double
   bridge counts as one connection, not a loop.

Rule 5 is Klura's addition to the usual rules of the genre. It makes every
solution a tree, so a board with N islands has exactly N - 1 connected pairs.

Islands never sit side by side in a row or column, so every bridge spans at
least one empty cell and stays visible.

## Daily puzzle

The puzzle of the day is generated on the device by
`generateDailyBridges(localDate)`, from the seed key
`dailySeedKey(puzzleId: 'bridges', generatorVersion: bridgesGeneratorVersion,
date: localDate)`, for example `bridges:v1:2026-11-11`. Generation uses only
`SeededRandom`. Increase `bridgesGeneratorVersion` whenever a change would
alter the puzzle for an existing key, and save the puzzle itself together with
the player's progress.

Every daily puzzle uses `BridgesConfig.daily`: 16 islands on a grid 7 cells
wide and 9 high. Difficulty is only grid size and island count; grading by
deduction technique, or by weekday, can come later.

## Code

The logic lives in `lib/puzzles/bridges/logic/` and does not depend on
Flutter.

| File | Responsibility |
| --- | --- |
| `geometry.dart` | `Position`, `Direction` and `Connection`, including whether two connections cross |
| `bridges_puzzle.dart` | `BridgesPuzzle`: the grid, its islands, each island's nearest neighbors and every possible connection |
| `bridge_arrangement.dart` | `BridgeArrangement`: the player's bridges as an immutable value |
| `bridges_rules.dart` | `checkBridges`: judges an arrangement against the rules |
| `bridges_solver.dart` | `solveBridges`: finds solutions up to a limit |
| `bridges_generator.dart` | `BridgesConfig`, `generateBridges` and the daily entry point |
| `bridges_text.dart` | `formatBridges` and `parseBridges`: a text notation for tests |
| `union_find.dart` | Disjoint groups of islands, shared by the three above it |

## Rules check

The game accepts any arrangement that satisfies the rules rather than
comparing with a stored solution, so a generator mistake can never reject a
correct answer. `checkBridges` reports each island as under, met or over its
number, every pair of crossing bridges, whether all islands are connected and
which connections lie on a loop. An arrangement is solved when every island is
met and there are no crossings or loops on a connected board.

## Solver

`solveBridges` searches depth first over the number of bridges on each
possible connection. Each connection keeps a range of counts, at first 0 to 2.
Before every branch, propagation narrows the ranges until no rule narrows them
further:

- An island's number bounds each of its connections by what its other
  connections can and must carry.
- A connection that must have a bridge rules out every connection it crosses.
- Connections that must have bridges may not form a loop, so no connection may
  join two islands they already link.
- Connections that may still have bridges must link every island. If only
  N - 1 of them remain, each needs a bridge.

The search then branches on the open connection with the fewest choices, at
the island with the fewest open connections. It stops at the requested limit;
a limit of 2 tells a unique puzzle from one with several solutions. The
solver never sees the generator's solution. A test compares it with a brute
force search over the rules check on hundreds of small random boards.

## Generator

`generateBridges` follows the design of the earlier C# prototype in
`C:\Source\Stranne.HahiPuzzle` (`Stranne.HashiPuzzle.Logic`), with these steps
for each attempt:

1. Place the islands one at a time on random cells. Each new island keeps a
   gap to every other island and shares a row or column with at least one.
   Reject the layout if an edge row or column of the grid stays empty, so the
   puzzle fills its board.
2. Build a random spanning tree with Kruskal's algorithm: take the
   connections in random order and skip any that would close a loop or cross
   one already chosen. If the order strands an island, the attempt fails.
3. Give each connection of the tree two bridges with a 35 % chance, otherwise
   one, and number the islands to match.
4. Run the solver with a limit of 2 and keep the puzzle only if the tree is
   its single solution.

Attempt n draws from `SeededRandom.fromKey('<seed key>#n')`. A failed attempt
moves on to the next, up to 1000. Most attempts fail in steps 1 and 2, which
are cheap; about two candidates in three that reach step 4 are unique.

This version avoids four flaws of the prototype. Its solver started from the
stored solution, so its uniqueness check passed every puzzle. It computed
crossing conflicts but never enforced them, and its tree builder ignored
crossings altogether. It also capped island numbers, which could leave them
out of step with the bridges.

## Performance

Generation runs on the browser's main thread, so each daily puzzle must take
well under 100 ms. `dart run tool/benchmark_bridges.dart` generates the 731
daily puzzles from 2026-11-11; the script's documentation also shows how to
run it compiled to JavaScript under Node.js. On 2026-11-11, on the
development machine (Windows on ARM):

| | Dart VM | JavaScript (Node.js) |
| --- | --- | --- |
| First puzzle, cold | 14 to 15 ms | 8 to 10 ms |
| Mean | 0.7 ms | 1.5 ms |
| 95th percentile | 2.2 ms | 4 ms |
| Worst | 6 ms | 9 ms, with rare pauses up to 30 ms |

Puzzles need 16 attempts on average, 12 at the median, 50 at the 95th
percentile and 103 at worst (2026-12-18). A phone browser is slower than this
machine, but the margin is wide.

## Text notation

Tests draw boards as text, one character per cell, with `formatBridges` and
`parseBridges`:

| Character | Cell |
| --- | --- |
| `1` to `8` | An island needing that many bridges |
| `.` | Empty |
| `-` `=` | One or two horizontal bridges |
| `\|` `║` | One or two vertical bridges |
| `┼` `╪` `╫` `╬` | Crossing bridges, which break rule 3: single, horizontal double, vertical double, both double |

For example, the puzzle of 2026-11-11 and its solution:

```text
2.3..2.    2-3==2.
.2....3    |2====3
3...4..    3===4.|
.......    ....║.|
2..1..2    2--1║.2
.......    |...║.|
.1..4.2    |1--4.2
.......    |...|.|
2...4.3    2---4=3
```

## Interaction goals for version 1

- Drag from an island toward a neighbor to add a bridge; tap a bridge to cycle
  between one, two and none.
- A bridge that would cross another is not placed; give a small shake instead
  of an error message.
- Islands change appearance when their count is met. Gently mark overfull
  islands and closed loops.
- Unlimited undo, an optional quiet timer and a short completion animation.
- Progress saves automatically. Opening the same puzzle again restores it.
- A reset clears every bridge to start over, also after the puzzle is solved.
- The next day's puzzle appears on the next launch. An open game is never
  replaced while the player is in it.
- Try the interaction on a phone early and adjust it until play feels smooth.
- No accounts, ads or hints in version 1.
