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

Each day has one puzzle per level, generated on the device by
`generateDailyBridges(level, localDate)` from the seed key
`dailySeedKey(puzzleId: 'bridges-<level>', generatorVersion:
bridgesGeneratorVersion, date: localDate)`, for example
`bridges-normal:v2:2026-11-11`. Generation uses only `SeededRandom`. Increase
`bridgesGeneratorVersion` whenever a change would alter the puzzle for an
existing key, and save the puzzle itself together with the player's progress.

| Level | Grid | Islands | Reasoning | Open after basic moves |
| --- | --- | --- | --- | --- |
| Normal | 10 × 10 | 30 | Basic or advanced | Any |
| Hard | 10 wide, 12 high | 36 | Lookahead | At least 20 |

Both levels stay 10 cells wide, which leaves about 36 pixels per cell on a
typical phone; Hard uses the extra height of a portrait screen. The levels are
a first guess and need playtesting.

## Difficulty

A Bridges puzzle is hard for a person when many possibilities stay open and
ruling them out takes thought. Alignment alone can mislead: an island needing
six bridges with three neighbors has many lines around it, yet it is settled
at a glance. `gradeBridges` therefore measures two things from an empty board.

- **Reasoning**, the least of these that solves the puzzle:
  1. *Basic*: island numbers and crossings, one island at a time.
  2. *Advanced*: also the loop and connectivity rules.
  3. *Lookahead*: also trying one bridge, following its consequences and
     finding that it breaks a rule.
  4. *Search*: deeper trial and error, or no single solution.
- **Open after basic**: how many connections basic moves leave undecided,
  the choices a player has to think about rather than see at once.

Any grade below search proves that the puzzle has exactly one solution,
because every deduction holds for every solution. About half of the
generator's candidates grade as search, and every one checked so far had
several solutions; no unique puzzle has needed deeper trial and error.

## Code

The logic lives in `lib/puzzles/bridges/logic/` and does not depend on
Flutter. The screen that plays it lives beside it in `lib/puzzles/bridges/`.

| File | Responsibility |
| --- | --- |
| `geometry.dart` | `Position`, `Direction` and `Connection`, including whether two connections cross |
| `bridges_puzzle.dart` | `BridgesPuzzle`: the grid, its islands, each island's nearest neighbors and every possible connection |
| `bridge_arrangement.dart` | `BridgeArrangement`: the player's bridges as an immutable value |
| `bridges_rules.dart` | `checkBridges`: judges an arrangement against the rules |
| `bridges_solver.dart` | `solveBridges`, which finds solutions up to a limit, and `gradeBridges` |
| `bridges_generator.dart` | `BridgesLevel`, `BridgesConfig`, `generateBridges` and the daily entry point |
| `bridges_text.dart` | `formatBridges` and `parseBridges`: a text notation for tests |
| `bridges_game.dart` | `BridgesGame`: a game in progress, with its moves, undo history and rules check |
| `union_find.dart` | Disjoint groups of islands, shared by the rules check and the solver |

| File in `lib/puzzles/bridges/` | Responsibility |
| --- | --- |
| `bridges_controller.dart` | `BridgesController`: holds one `BridgesGame` and tells the screen about each move |
| `bridges_daily_games.dart` | `BridgesDailyGames`: the day's game at each level, kept for the session |
| `bridges_screen.dart` | The game screen: board, status line, buttons, solved panel and how to play |
| `bridges_board.dart` | The board widget: layout, gestures, keyboard, islands and their semantics |
| `bridges_board_painter.dart` | Paints grid dots, bridges, previews and the marks for loops, blocked moves and the solve |
| `bridges_board_geometry.dart` | Places cells in pixels and finds the island or bridge under a pointer |

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

`gradeBridges` reuses the same propagation. Basic moves are its first two
rules, advanced reasoning adds the other two, and lookahead tries the lowest
and highest count of each open connection in turn, ruling out any that makes
propagation fail.

## Generator

`generateBridges` builds a solution first and then makes sure that only it
fits, as the earlier C# prototype in `C:\Source\Stranne.HahiPuzzle`
(`Stranne.HashiPuzzle.Logic`) did. Each attempt:

1. Places one island on a random cell, then adds islands one at a time,
   choosing at random among every possible move. A move either runs a new
   straight bridge from an island over at least one free cell to a new
   island, or puts a new island on an existing bridge, at least two cells
   from either end, splitting it in two. Bridges never cross or pass over an
   island, and islands never sit side by side, so the islands and bridges
   always form a valid spanning tree. The attempt fails if no move remains
   or an edge row or column of the grid stays empty.
2. Gives each bridge two lines with a 35 % chance, otherwise one, and numbers
   the islands to match.
3. Grades the puzzle and keeps it only if the grade is below search and suits
   the level. The solver then confirms that the tree is the single solution.

Attempt n draws from `SeededRandom.fromKey('<seed key>#n')`, up to 1000
attempts. The first version placed every island before looking for a
spanning tree of non-crossing connections. On larger boards that tree
usually stranded an island: at 10 × 10 with 25 islands 89 % of attempts
failed there, and with 30 islands no puzzle was found in 1000 attempts.
Growing the tree together with the islands never strands one.

This version avoids four flaws of the prototype. Its solver started from the
stored solution, so its uniqueness check passed every puzzle. It computed
crossing conflicts but never enforced them, and its tree builder ignored
crossings altogether. It also capped island numbers, which could leave them
out of step with the bridges.

## Performance

Generation runs on the browser's main thread, so each daily puzzle must take
well under 100 ms. It runs at most once per level and day, since the puzzle is
saved with the player's progress. `dart run tool/benchmark_bridges.dart`
generates the 731 daily puzzles of each level from 2026-11-11; the script's
documentation also shows how to run it compiled to JavaScript under Node.js.
On 2026-11-11, on the development machine (Windows on ARM):

| | Normal, VM | Normal, Node.js | Hard, VM | Hard, Node.js |
| --- | --- | --- | --- | --- |
| First puzzle, cold | 34 ms | 17 to 18 ms | 24 ms | 9 ms |
| Mean | 2.0 ms | 3.1 ms | 3.2 ms | 4.5 ms |
| 95th percentile | 5.7 ms | 9 ms | 8.7 ms | 13 ms |
| Worst | 20 ms | 23 ms | 21 ms | 28 ms |

Normal puzzles need 10 attempts on average and 80 at worst (2028-05-17); Hard
puzzles need 11 on average and 71 at worst (2028-04-07). Growing the board and
grading it take about equal shares of the time, and each attempt uses only a
few kilobytes. A phone browser is slower than this machine, but the margin is
wide.

The two-year test fails if any day needs more than 200 attempts. Attempt
counts are deterministic, unlike timings, so the ceiling catches a generator
that has become slow without ever failing at random. The daily puzzles of both
levels from 2026-11-11 were also identical on the VM, in JavaScript and in
WebAssembly.

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

For example, the Normal puzzle of 2026-11-11 and its solution:

```text
3..5..2.2.    3==5==2.2.
.1.......1    |1.|....║1
....1.2.4.    ||.|1-2-4|
2.........    2|.|....||
.4.7.4..4.    |4=7=4==4|
2...3.1..3    2|.║3-1.|3
.3.3......    |3.3║...|║
2...3.3.3.    2║.|3-3=3║
.2........    |2.|.....║
1..3.4.3.3    1..3=4=3-3
```

## Playing

The home screen lists today's Normal and Hard puzzles. The app reads the date
once when it starts, so a new day's puzzles appear on the next launch and an
open game is never replaced. Each level's puzzle is generated when first
opened, which takes a few milliseconds, and the game stays in memory for the
session: leaving a puzzle and coming back resumes it. The puzzles have their
own routes, `#/bridges/normal` and `#/bridges/hard`, so the browser's back
button returns home. Progress does not yet survive a reload.

### Building bridges

- **Drag** from an island toward a neighbor and let go to move the bridges
  between them one step through the cycle one, two, none. The drag only has
  to point the way: once it has moved about half a cell, its main direction
  picks the nearest island that way, and a faint preview shows the result
  while the finger is still down. Dragging back to the island cancels. A drag
  may start up to three quarters of a cell from an island's center, which
  helps on a phone where a finger hides the island.
- **Tap** a bridge to move it through the same cycle. Tapping the empty gap
  between two facing islands builds the first bridge, unless two possible
  bridges cross right there, where the tap is ambiguous and does nothing. A
  tap where a bridge lies always changes that bridge. Tapping an island does
  nothing.
- **Keys**: the board is a single tab stop. The arrow keys move a focus ring
  to the neighbor a bridge would reach, or else to the nearest island that
  way. Shift with an arrow moves the bridges in that direction through the
  cycle. Ctrl+Z or Cmd+Z undoes.
- **Mouse**: hovering a gap or a bridge previews what a click would make, and
  hovering an island shows faint dashes to each neighbor it can still bridge
  to. The same dashes show from a pressed island and from the island with
  keyboard focus.

Drag and tap share one cycle, so there is one rule to learn, and removing a
double bridge needs no separate gesture. A new bridge grows out of the
island a drag started at, or from its middle after a tap, in about 150 ms;
removed bridges fade.

A bridge that would cross another is never placed. While dragging, the
attempt shows as a red dashed line and the bridges in its way turn red. On
release those bridges shake briefly, the status line says that bridges
cannot cross, and phones that support it give a short vibration. Placing a
bridge gives a lighter tick.

### Feedback

- An island needing more bridges is an outlined ring. A met island is filled
  with the primary color. An overfull island gets a red ring, a red number
  and a soft red halo. Fill, outline and halo differ as well as color.
- Bridges on a loop turn red over a soft red band.
- The status line counts complete islands, for example `12 of 30 islands
  complete`. When something is wrong it names it in words instead: a loop,
  islands with too many bridges, or every number met while the islands are
  not all linked.
- When a move solves the puzzle, light spreads along the bridges from that
  move, each island lifting once as it passes, and after about a second a
  panel says `Solved` with buttons to start over or return home. The board
  then takes no more moves. With reduced motion, the board skips the wave and
  the shake.

### Undo and start over

Undo has no limit. Start over clears every bridge as a single move, so Undo
brings them back, and it needs no confirmation dialog. After a solve, Undo is
hidden and Start over remains.

### Accessibility

Each island has a label with its number, row and column, its progress and
its bridges by direction, for example `Island 4, row 2, column 3. 2 of 4
bridges. 1 up, 1 to the right`. The board has a label with its size, and the
status line is a polite live region. Nothing depends on color alone: island
states differ in shape, loops have a band, and the status line names every
problem in words. The colors are the theme's own pairs in light and dark
mode.

### Still to come

- Saving: progress saves automatically and opening the same puzzle again
  restores it. A saved game needs the level, the seed key, the puzzle itself
  and the arrangement; whether it is solved follows from those. The undo
  history and the session date could be saved too.
- An optional quiet timer.
- No accounts, ads or hints in version 1.
- The interaction has been tried in Chrome with phone emulation. It still
  needs a session on a real phone.
