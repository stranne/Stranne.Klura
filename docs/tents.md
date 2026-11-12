# Tents

Tents is the second Klura puzzle. It belongs to the genre known as Tents, or
Tents and Trees. Klura uses its own puzzles, visuals and wording; it does not
copy puzzles or visuals from any published version, and it avoids the names
that published apps use.

## Rules

1. Each tree has a tent of its own directly above, below, left or right of
   it, and each tent belongs to one such tree.
2. Tents never touch each other, not even diagonally.
3. The numbers beside the grid give the number of tents in each row and
   column.

There are as many tents as trees. Which tree a tent belongs to is never
fixed: a board is solved when some pairing of trees and tents meets rule 1.

## Daily puzzle

Each day has one puzzle per level, generated on the device by
`generateDailyTents(level, localDate)` from the seed key
`dailySeedKey(puzzleId: 'tents-<level>', generatorVersion:
tentsGeneratorVersion, date: localDate)`, for example
`tents-normal:v1:2026-11-12`. Generation uses only `SeededRandom`. Increase
`tentsGeneratorVersion` whenever a change would alter the puzzle for an
existing key; the puzzle itself is saved together with the player's
progress.

| Level | Grid | Tents | Reasoning | Open after basic |
| --- | --- | --- | --- | --- |
| Normal | 8 × 8 | 12 | Advanced | At least 10 |
| Hard | 10 × 10 | 20 | Lookahead | Any |

One tent for every five cells is the usual density of the genre. Each cell is
something the player taps, unlike in Bridges, so cells matter more. With the
numbers and a small margin beside the grid, a 390-pixel-wide phone leaves
about 41 pixels per cell on Normal and 34 on Hard, below the 44 to 48 pixels
usually advised for touch. The levels are a first guess and need
playtesting.

## Difficulty

`gradeTents` measures two things from an empty board, as `gradeBridges`
does.

- **Reasoning**, the least of these that solves the puzzle:
  1. *Basic*: one rule at a time. No tent goes on a cell away from the trees
     or beside a tent. A row or column with all its tents has no more, and
     one with just enough open cells has a tent on each. A tree without a
     tent beside it and with one open cell beside it has its tent there.
  2. *Advanced*: rules combined. A stretch of n open cells in a line holds
     at most (n + 1) / 2 tents, so when the stretches can hold no more than
     the line needs, an odd stretch has a tent on every other cell and a
     stretch of two rules out the cells beside both of its cells. Pairing
     works out which tree each tent belongs to: a tent with a single tree
     beside it that has no other tent belongs to it, a tree with a single
     cell beside it that could still hold its tent gets that tent, and an
     open cell whose trees all have their tents holds none.
  3. *Lookahead*: trying a tent or grass on one cell, following its
     consequences and finding that it breaks a rule.
  4. *Search*: deeper trial and error, or no single solution.
- **Open after basic**: how many cells beside a tree basic reasoning leaves
  undecided.

Any grade below search proves that the puzzle has exactly one solution,
because every deduction holds for every solution. Normal asks for advanced
reasoning with at least 10 open cells, which leaves out boards that the
basic rules alone fill in. Those are common: of the first 8 × 8 puzzles
that reasoning solved for 400 test keys, 251 needed only basic rules.

## Code

The logic lives in `lib/puzzles/tents/logic/` and does not depend on
Flutter. The screen that plays it lives beside it in `lib/puzzles/tents/`.
It shares the timer, controller base, daily games, storage, solve history
and puzzle screen with Bridges, as the [README](../README.md#layout)
describes.

| File | Responsibility |
| --- | --- |
| `tents_puzzle.dart` | `TentsPuzzle`: the grid, its trees and the number of tents in each row and column |
| `tents_marks.dart` | `TentsMark` and `TentsMarks`: the player's tents and grass as an immutable value |
| `pairing.dart` | `countPairs`: the most trees and tents that can be paired, by augmenting paths; `findUnpaired`: the tents that some such pairing leaves out |
| `tents_rules.dart` | `checkTents`: judges marks against the rules |
| `tents_solver.dart` | `solveTents`, which finds solutions up to a limit, and `gradeTents` |
| `tents_generator.dart` | `TentsLevel`, `TentsConfig`, `generateTents` and the daily entry point |
| `tents_text.dart` | `formatTents` and `parseTents`: a text notation for tests |
| `tents_game.dart` | `TentsGame`: a game in progress, with its moves, undo history and rules check |
| `tents_save.dart` | `TentsSave` and its JSON save format |
| `tents_storage.dart` | `TentsStorage`: the shared `DailyStorage` for Tents |

| File in `lib/puzzles/tents/` | Responsibility |
| --- | --- |
| `tents_controller.dart` | `TentsController`: the shared `PuzzleController` for a `TentsGame`, with its moves |
| `tents_daily_games.dart` | `TentsDailyGames`: the shared `DailyGames` for Tents |
| `tents_screen.dart` | The game screen: the shared `PuzzleScreen` with the board, the problems the status line names and how to play |
| `tents_board.dart` | The board widget: layout, gestures, keyboard, row and column numbers and semantics |
| `tents_board_painter.dart` | Paints the grid, trees, tents, grass, marks for broken rules, previews and the solve |
| `tents_board_geometry.dart` | Places cells and numbers in pixels and finds the cell under a pointer |

## Rules check

The game accepts any tents that meet the rules rather than comparing with a
stored solution, so a generator mistake can never reject a correct answer.
`checkTents` reports each row and column as under, met or over its number,
every pair of touching tents, the tents with no tree beside them, and
whether every tent and every tree can have a partner of its own. Grass plays
no part. Marks are solved when every line is met, no tents touch and the
trees and tents pair up completely.

When the tents cannot all have a tree of their own, `checkTents` also names
the tents that have to share one and the trees they share: the tents beside
a tree that some largest pairing leaves out. Each such tent belongs to a
group with fewer trees beside it than tents, and any tent of the group
could be the one left over, so the whole group is named. This includes a
pair of tents beside one lone tree as well as a longer chain, such as three
tents around two trees. The group is the same whichever largest pairing the
search finds, so moving an unrelated tent never changes it, and a tent that
keeps a tree of its own however the others pair up is never in it.

The checks judge only the tents that are placed, never what the empty cells
still need. A tree whose cells are all grass or beside other tents is not
flagged: finding that is part of solving, and grass is only a note.

## Solver

`solveTents` searches depth first over the cells beside a tree, the only
cells that can hold a tent. Each is open, a tent or empty. Before every
branch, propagation applies the basic and advanced rules of
[Difficulty](#difficulty) until nothing changes, and stops a branch where a
rule is broken: a line with too many tents or too little room, touching
tents, a tree without a possible tent or a tent without a possible tree.
A branch also stops when augmenting paths show that the trees and tents
can no longer pair up.

The search branches on an open cell beside the tree with the fewest open
cells, trying a tent first. It stops at the requested limit; a limit of 2
tells a unique puzzle from one with several solutions. The solver never
sees the generator's solution. A test compares it with a brute force search
over the rules check on 400 small random boards.

`gradeTents` reuses the same propagation, first with the basic rules only,
then with all of them, and finally with lookahead, which tries a tent and
then grass on each open cell in turn.

## Generator

`generateTents` builds a solution first and then makes sure that only it
fits. Each attempt:

1. Places the tents one at a time, each on a random free cell that touches
   no tent, with its tree on a random free cell directly beside it, chosen
   together among every such pair. The attempt fails if no pair remains.
2. Numbers the rows and columns from the tents.
3. Grades the puzzle and keeps it only if the grade is below search and
   suits the level. The solver then confirms that the tents are the single
   solution.

Attempt n draws from `SeededRandom.fromKey('<seed key>#n')`, up to 1000
attempts. Random boards usually have a single solution: with every grade
below search accepted, 398 of 400 test keys found a puzzle within four
attempts on 8 × 8, and 393 of 400 on 10 × 10.

## Performance

`dart run tool/benchmark_tents.dart` generates the 731 daily puzzles of each
level from 2026-11-12; the script's documentation also shows how to run it
compiled to JavaScript under Node.js. On 2026-11-12, on the development
machine (Windows on ARM):

| | Normal, VM | Normal, Node.js | Hard, VM | Hard, Node.js |
| --- | --- | --- | --- | --- |
| First puzzle, cold | 36 ms | 20 ms | 1.4 ms | 1 ms |
| Mean | 0.8 ms | 1.5 ms | 1.5 ms | 3.5 ms |
| 95th percentile | 2.1 ms | 4 ms | 4.2 ms | 10 ms |
| Worst | 6.1 ms | 9 ms | 12 ms | 24 ms |

Hard runs after Normal in the same process, so its first puzzle is not
cold. Normal puzzles need 6.6 attempts on average and 40 at worst
(2028-04-06); Hard puzzles need 7.7 on average and 55 at worst (2027-08-27).

The two-year test fails if any day needs more than 150 attempts. The daily
puzzles of both levels were identical on the VM, in JavaScript and in
WebAssembly.

## Text notation

Tests draw boards as text with `formatTents` and `parseTents`. The first
line holds the column numbers after two spaces. Each further line is a row:
its number, a space and one character per cell.

| Character | Cell |
| --- | --- |
| `T` | A tree |
| `^` | A tent |
| `-` | Grass |
| `.` | Empty |

For example, the Normal puzzle of 2026-11-12 and its solution:

```text
  13121112    13121112
2 ........  2 .^.^....
1 .TTT..T.  1 .TTT..T^
3 .T.T....  3 ^T^T^...
1 ...T..T.  1 ...T..T^
2 T.......  2 T^.^....
1 ........  1 ......^.
1 ..T...T.  1 .^T...T.
1 ....T...  1 ....T^..
```

## Playing

The home screen lists today's Normal and Hard puzzles below Bridges, with
how far each has come. They have their own routes, `#/tents/normal` and
`#/tents/hard`. Generation, saving, the move to a new day, undo, start over,
the timer, sound and the solved panel work as for Bridges; see
[Playing](bridges.md#playing).

### Placing tents and grass

- **Tap** a cell to move it through grass, a tent and empty. Grass comes
  first, so a cell on its way to a tent passes a harmless note rather than
  a tent that may break a rule for a moment. Tapping a tree does nothing.
- **Drag** along a row or column to put grass on every empty cell on the
  way, as one move. The drag keeps to the line it starts along until the
  other direction clearly leads, and never touches trees or tents. A drag
  that starts on grass clears grass instead. Cells the drag would change
  show a faint preview while the finger is down. A press that moves less
  than a third of a cell counts as a tap.
- **Keys**: the board is a single tab stop. The arrow keys move a focus ring
  between cells, and Space or Enter changes the cell under it. Ctrl+Z or
  Cmd+Z undoes.
- **Mouse**: hovering a cell shows faintly what a click would leave there.

Grass is only the player's note. The rules check ignores it, and no cell is
marked automatically.

### Feedback

- A row or column number fades once its tents are all placed, and turns red
  inside a red ring when it has too many.
- Touching tents turn red over a soft red band, and a tent with no tree
  beside it turns red over a soft red ring. Tents that have to share a tree
  turn red over a band that runs through the trees they share. The bands
  form one shape, so they stay as soft where they meet.
- The status line stays empty while nothing is wrong. Otherwise it names
  each problem in words: tents that touch, tents without a tree, tents that
  would have to share a tree, and rows or columns with too many tents.
- When a move solves the puzzle, a wave spreads from that tent and lifts
  each tree and tent once. With reduced motion, the board skips it.
- Each move makes a soft sound, as [for Bridges](bridges.md#sound): a faint
  brush for grass, one longer brush for a line of grass, a brighter pluck
  for a tent and a lower, falling note when a tent or a line of grass goes.
  The move that solves the puzzle chimes instead.

### Accessibility

Each cell has a label with its row, column and content, and any problem, for
example `Row 2, column 4, tent, touches another tent`. Tents that have to
share a tree say `has to share a tree`, and their trees say `shared by too
many tents`. Free cells are
buttons that change the cell. Each number has a label with the tents placed,
for example `Column 4: 2 tents, 2 placed, complete`, and the board has one
with its size, its trees and the tents placed. Nothing depends on color
alone: problems have bands, rings and words, and trees, tents and grass have
different shapes. The tents use the theme's primary color. The trees use a
calm green and brown chosen for each brightness, the only colors outside the
theme.

## Saving

Progress saves as for Bridges, under keys of its own:

| Key | Value |
| --- | --- |
| `klura.tents.<level>.<date>` | The game at that level on that day, for example `klura.tents.normal.2026-11-12` |
| `klura.tents.history` | The days each level was solved, with the time the first solve took, in the [history format](bridges.md#save-format) shared with Bridges |

A game is a JSON object with a `format` number, now 1, written and read by
`tents_save.dart`:

```json
{
  "format": 1,
  "level": "normal",
  "date": "2026-11-12",
  "seedKey": "tents-normal:v1:2026-11-12",
  "puzzle": {
    "width": 4,
    "height": 3,
    "trees": [[2, 0], [2, 2]],
    "rows": [1, 0, 1],
    "columns": [0, 0, 0, 2]
  },
  "tents": [[3, 0]],
  "grass": [[0, 0], [0, 1], [0, 2]],
  "playedMs": 252345,
  "solved": false
}
```

| Field | Meaning |
| --- | --- |
| `level`, `date` | The level and the local calendar date of the puzzle |
| `seedKey` | The key the puzzle was generated from, as a record only |
| `puzzle` | The grid size, each tree as column and row in reading order, and the number of tents in each row and column |
| `tents`, `grass` | The player's marks, each as column and row in reading order |
| `playedMs` | The time played in milliseconds, which stops at the first solve |
| `solved` | Whether the game was ever solved; a start over clears the board but not this |

A game that cannot be read counts as missing, as for Bridges: text that is
not JSON, a missing or mistyped field, another format version, a date that
does not exist, a side longer than 40 cells, a cell named twice or with
both a tent and grass, or trees, numbers and marks that break the rules of
the puzzle models.

## Still to come

- The levels and their grades need playtesting, as does the touch size of
  Hard on a small phone.
- The interaction has been tried in Chrome with phone emulation. It still
  needs a session on a real phone.
