# Logjam

Logjam is the third Klura puzzle, a sliding-block planning puzzle chosen to
train planning moves in the right order and holding in mind what the board
does not show, as [Mental gym](mental-gym.md) describes. The best-known
version of the genre is a commercial board game, and a well-known app draws
its pieces as wooden blocks. Klura uses none of their names, themes, looks
or levels: no cars or traffic and no wooden blocks, but its own puzzles,
visuals and wording.

The theme is timber floating, the way logs were once driven down Swedish
rivers: logs have jammed in the river, and the player frees them one slide
at a time until the marked log can float out through a gap in the boom.

## Rules

1. The board is a grid of 6 × 6 cells holding logs two or three cells long,
   each lying along a row or a column.
2. A log slides only along its own length, any distance, as long as no other
   log is in its way. It never turns or leaves the board.
3. One log is marked. It lies along the row with the exit, on the right edge
   of the board, and the puzzle is solved when it reaches the exit.

One move slides one log any distance, and slides of the same log one after
another count as one move, as [Moves](#moves) explains. Every move can be
undone, so no position is a dead end. Any moves that bring the marked log to the exit
solve the puzzle; the game checks the rules rather than compare with a
stored solution.

## Daily puzzle

Each day has one puzzle per level, generated on the device by
`generateDailyLogjam(level, localDate)` from the seed key
`dailySeedKey(puzzleId: 'logjam-<level>', generatorVersion:
logjamGeneratorVersion, date: localDate)`, for example
`logjam-normal:v1:2026-11-12`. Generation uses only `SeededRandom`. Increase
`logjamGeneratorVersion` whenever a change would alter the puzzle for an
existing key.

| Level | Grid | Logs | Fewest moves |
| --- | --- | --- | --- |
| Normal | 6 × 6 | 14 to 16 | 7 to 9 |
| Hard | 6 × 6 | 14 to 16 | 10 to 14 |

The exit is on the third row. The levels are provisional: they are the most
that generating on the device affords, as [Generator](#generator) and
[Performance](#performance) show, and they need playtesting.

## Difficulty

A puzzle's difficulty is the fewest moves that solve it, found by a breadth
first search. After a solve the app says `Solved in N moves · fewest
possible M`, which gives a replay a goal without showing the way.

A move slides a log any distance, which matches a drag on the screen. Counted
one cell at a time instead, the sample puzzles below need 1.0 to 1.6 times as
many moves. Whether fewest moves matches how hard a board feels is unknown.
A long forced sequence may be easier than a short one that starts with a
move away from the exit, so the levels need playtesting.

## Code

The logic lives in `lib/puzzles/logjam/logic/` and does not depend on
Flutter. The screen that plays it lives beside it in `lib/puzzles/logjam/`.
It shares the timer, controller base, daily games, storage, solve history
and puzzle screen with Bridges and Tents, as the
[README](../README.md#layout) describes.

| File | Responsibility |
| --- | --- |
| `logjam_board.dart` | `LogjamPiece`, `LogjamMove` and `LogjamBoard`: the grid with its logs where they lie, the legal moves and whether the marked log has reached the exit |
| `logjam_solver.dart` | `solveLogjam`, one shortest solution, and `exploreLogjam`, every position reachable from a board with the fewest moves each needs |
| `logjam_generator.dart` | `LogjamLevel`, `LogjamConfig`, `generateLogjam` and the daily entry point |
| `logjam_text.dart` | `formatLogjam` and `parseLogjam`: a text notation for tests |
| `logjam_game.dart` | `LogjamGame`: a game in progress, with its moves, joined as [Moves](#moves) describes, and its undo history |
| `logjam_save.dart` | `LogjamSave` and its JSON save format |
| `logjam_storage.dart` | `LogjamStorage`: the shared `DailyStorage` for Logjam |

| File in `lib/puzzles/logjam/` | Responsibility |
| --- | --- |
| `logjam_controller.dart` | `LogjamController`: the shared `PuzzleController` for a `LogjamGame`, with its slides, the fewest moves of the puzzle and the fewest of any solve |
| `logjam_daily_games.dart` | `LogjamDailyGames`: the shared `DailyGames` for Logjam |
| `logjam_screen.dart` | The game screen: the shared `PuzzleScreen` with the board, the count of moves, the solved message and how to play |
| `logjam_board_view.dart` | The board widget: layout, gestures, keyboard, sounds and semantics |
| `logjam_board_painter.dart` | Paints the river, the boom, the logs, the lane, where a dragged log would settle, what stops a slide, the focus and the solve |
| `logjam_board_geometry.dart` | Places cells, logs and the boom in pixels and finds the cell under a pointer |

`LogjamBoard` keeps its logs in a fixed order, the marked log first, so an
index names the same log in every position a game passes through. A puzzle is
the board it starts from.

## Solver

Every log keeps its line and length, so a position is just where each log
lies along its line. The solver packs these offsets into words of 30 bits,
three bits each on a 6 × 6 board, so a position of up to 20 logs takes two
words. Positions live in an open-addressing hash table of 32-bit integer
arrays. The words stay below 2^30 and every product in the hash below 2^53,
so the arithmetic is exact in JavaScript too, and the order the search finds
positions in never depends on the hash.

`solveLogjam` searches breadth first from the board until the marked log
reaches the exit, and returns the moves of the shortest way. `exploreLogjam`
finds every position reachable from a board, up to a limit, and then
searches breadth first from all the solved ones at once. Moves can be
undone, so that gives each position the fewest moves it needs. It also names
the position that needs the most: the first of them that search reaches.

Two tests compare both with a brute force search that uses only the moves
`LogjamBoard` allows: on 200 small random boards it lists every placement of
the logs, and on crowded 6 × 6 boards, whose positions take two words, every
reachable position. It then lowers each distance to one more than a
neighbor's until nothing changes.

## Generator

`generateLogjam` follows the idea of searching backwards from the solved
positions. Each attempt:

1. Places the marked log on the exit row at random, then 13 to 15 other logs
   one at a time, each three cells long with a 40 % chance, on a random free
   place. No other log lies along the exit row: to the right of the marked
   log it would block it for good.
2. Explores every position the logs can reach, giving up beyond 2,000.
3. Takes the position farthest from every solved one, the one that needs the
   most moves, and keeps it if that number suits the level. The solver then
   confirms the number from that position.

Attempt n draws from `SeededRandom.fromKey('<seed key>#n')`, up to 2,000
attempts. The logs after the marked one are put in the reading order of
their first cells, so their letters in the text notation read from the top
left.

Random boards rarely need many moves. Of 4,000 random boards with a solvable
start, which took 3.1 random boards each, the farthest position needed:

| At least | 6 | 8 | 10 | 12 | 14 | 16 | 18 | 20 | 25 | 30 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Share | 41 % | 24 % | 13 % | 5.5 % | 2.2 % | 0.85 % | 0.38 % | 0.20 % | 0.03 % | 0 |

At about 0.23 ms per random board on the VM, a level that asks for 16 moves
or more takes too long on a phone, and 20 moves takes hundreds of
milliseconds even here. These were tried without changing that picture:

- Fewer logs, 8 to 13: deep puzzles get a little commoner, but the
  positions to explore grow to thousands, so each attempt costs several
  times more and a deep puzzle costs as much or more.
- Vertical logs placed across the exit row first, with the marked log at the
  left: deep puzzles cost about half as much, still over 100 ms for 20
  moves, and short ones cost more.
- Rocks, cells no log can enter: no cheaper deep puzzles.
- Starting with the marked log at the exit, so every cluster is solvable:
  fewer deep puzzles, since it favors clusters with many solved positions.
- Hill climbing, which adds, removes or moves a log in the farthest
  position and keeps the change unless the puzzle gets shorter: a median of
  195 ms per 20-move puzzle and up to seconds.

## Performance

`dart run tool/benchmark_logjam.dart` generates the 731 daily puzzles of each
level from 2026-11-12; the script's documentation shows how to run it
compiled to JavaScript under Node.js, and `survey` makes it count the moves
of random boards instead. On 2026-11-12, on the development machine (Windows
on ARM):

| | Normal, VM | Normal, Node.js | Normal, Wasm | Hard, VM | Hard, Node.js | Hard, Wasm |
| --- | --- | --- | --- | --- | --- | --- |
| First puzzle, cold | 20 ms | 11 ms | 6 ms | 8.8 ms | 14 ms | 6.4 ms |
| Mean | 3.3 ms | 5 ms | 2.7 ms | 5.7 ms | 9 ms | 4.4 ms |
| 95th percentile | 9.5 ms | 15 ms | 7.8 ms | 16 ms | 25 ms | 14 ms |
| Worst | 22 ms | 34 ms | 18 ms | 44 ms | 51 ms | 24 ms |

Hard runs after Normal in the same process, so its first puzzle is not cold.
Normal puzzles need 17 attempts on average and 114 at worst (2027-01-07);
Hard puzzles need 28 on average and 179 at worst (2027-06-25). The positions
reachable from a puzzle number 367 at the median for Normal and 573 for
Hard.

The two-year test fails if any day needs more than 300 attempts. It also
compares a digest of every puzzle's text with a fixed value, and since the
Flutter-free tests run on the VM, in JavaScript and in WebAssembly, that
shows all three generate the same puzzles.

## Text notation

Tests draw boards as text with `formatLogjam` and `parseLogjam`, one line per
row and one character per cell, with `>` after the row that has the exit:

| Character | Cell |
| --- | --- |
| `*` | The marked log |
| `A` to `Z` | The other logs, in the order of the board's logs |
| `.` | Empty |

The cells of a log form a straight run of two or three, which also shows
which way it slides. For example, the Hard puzzle of 2026-11-12, which needs
13 moves:

```text
.AABBB
.CC.DE
FG**DE>
FGHHDI
JK.LLI
JKMMNN
```

## Samples

Five puzzles of different lengths to play on paper, each with one shortest
solution. The first three come from the generator's usual 14 to 16 logs;
the 18- and 22-move ones had to be searched for with 12 to 14 logs, which
took 0.2 and 4.4 seconds.

7 moves, or 10 one cell at a time:

```text
..AAAB
CCDDEB
**F.EG>
HHFIIG
JJFKKG
.LL.MM
```

A left 1, E up 1, L left 1, F down 1, M left 1, G down 1, * right 4.

10 moves, or 14 one cell at a time:

```text
ABBB.C
ADDD.C
EFG**C>
EFG.HH
IJKKLL
IJ.MMM
```

B right 1, D right 1, F up 2, H left 1, J up 2, K left 1, L left 1, M left 1,
C down 3, * right 1.

14 moves, or 15 one cell at a time:

```text
ABCCDD
AB.EFF
A**EGH>
IIIEGH
..JJ.K
LLLMMK
```

G down 1, J left 1, E down 1, F left 1, H up 1, K up 1, M right 1, E down 1,
* right 1, B down 1, C left 1, D left 1, H up 1, * right 2.

18 moves, or 27 one cell at a time:

```text
.AA..B
CCDDDB
E**.FG>
E.HIFG
..HIJJ
...KKK
```

A left 1, E down 1, * left 1, H up 1, I up 1, J left 3, F down 1, I down 1,
K left 1, G down 2, B down 2, D right 1, H up 2, * right 3, H down 2,
D left 1, B up 2, * right 1.

22 moves, or 35 one cell at a time:

```text
A...BB
ACDD.E
FCG**E>
FHGIIE
FHJKLL
MMJK..
```

B left 1, C up 1, D right 1, E up 1, G up 2, * left 2, I right 1, J up 1,
K up 1, M right 4, H down 1, J down 1, K down 1, I left 3, K up 2, L left 1,
M left 1, E down 3, B right 1, D right 1, K up 2, * right 3.

## Playing

The home screen lists today's Normal and Hard puzzles after Bridges and
Tents, beside them where the screen is wide enough. Each level shows its
grid and the range of fewest moves its puzzles need, such as `6 × 6 · 7 to
9 moves`, and how far today's game has come. The routes are
`#/logjam/normal` and `#/logjam/hard`. Generation, saving, the move to a new
day, undo, start over and the timer work as for Bridges; see
[Playing](bridges.md#playing).

### The river

Seen from above, the board is the water. Logs float on it with their bark
and a cut end facing the light, about two thirds of a cell thick, so the
water shows between them. Faint dots where cells meet keep the cells
countable without a grid. A boom closes the right edge but for a gap at the
end of the exit row, and the current runs out through it. The marked log is
painted in the theme's primary color and carries three chevrons toward the
exit, so it differs by shape as well as color.

### Moving logs

- **Drag** a log along its length. A drag can start anywhere on the log's
  cells, which are wider than the log looks. The log follows the finger
  along its own line only, as far as the water is clear, lifted a little
  over a soft band that shows how far it can go and a dashed outline where
  it would settle. On release it settles in the nearest cell. A drag that
  ends where it began is no move and makes no sound. A press that moves
  less than a third of a cell counts as a tap.
- **Tap** a log to show for a moment how far it can slide. A tap never moves
  a log, since every move counts.
- **Keys**: the board is a single tab stop, and as in Bridges an arrow key
  pressed while anything else has the focus gives it to the board, only
  showing the focus ring, first on the marked log. The arrow keys move the
  ring to the nearest log that way, measured from the nearest cells, and
  Shift with an arrow along the log slides it one cell; across it, nothing
  happens. The ring has an arrowhead at each end the log can slide toward.
  Ctrl+Z or Cmd+Z undoes.
- **Mouse**: the pointer turns into an open hand over a log and a closed one
  while dragging.

### Moves

A move slides one log any distance. A slide of the log that the last move
slid joins that move, and a log slid back to where that move began takes
the move back. So sliding a log in several drags, or one cell at a time with
the keys, counts as one move, as the solver counts it, and no solve counts
fewer moves than the fewest possible. The count stands between Undo and
Start over and covers the moves since the start or the last start over.
Undo takes back a joined move whole. Start over puts every log back as one
step that Undo takes back.

After a solve the panel says `Solved in 15 moves · fewest possible 13`, or
`Solved in 13 moves · the fewest possible` when they match. The time stays
in the clock in the app bar. The first solve's time is the day's result, as
for the other puzzles, and the fewest moves of any solve that day are kept,
so a replay after a start over can lower them. The home screen shows both,
for example `Solved · 4:12` above `13 moves`.

### Feedback

- A log pushed against another, or against the bank, stops flush with it. A
  stop bar in the error color marks where it stopped, hatching marks the end
  of the log in its way, and a low knock sounds; the marks fade after a
  moment. Pushed by a key, the log also gives a small nudge. A drag knocks
  only when pushed a quarter of a cell past the stop, so a drag that just
  overshoots stays quiet.
- Being stopped is no mistake, so the status line stays empty apart from the
  note after a start over.
- When a move solves the puzzle, the marked log drifts out through the gap
  and fades, rings spread from the gap and a wave from it lifts each log
  once. The solved board shows the river without the marked log.
- A slide makes a soft wooden tock with a faint wash of water, a fourth
  lower for a log of three cells. A log pushed against another knocks with
  the knock of a blocked bridge, and the move that solves the puzzle chimes
  as the log floats out. Undo, start over, moving the focus and a drag
  released where it began stay silent.

### Accessibility

Nothing depends on color alone: the marked log has chevrons, and a stopped
slide has a stop bar and hatching. With reduced motion a dragged log still
follows the finger, which is direct control, but it does not lift, it
settles at once and a key push does not nudge it. A solve then skips the
drift, the rings and the wave, and the marked log stays in the gap. The
board has no text, so larger text changes only the count and the buttons,
which stack where there is no room, and the solved message, whose detail
moves below its title.

The board has a label with its size, its logs, where the gap is and where
the marked log lies. Each log has a label with its length, where it lies and
how far it can slide each way, for example `Marked log, 2 cells, row 3,
columns 3 to 4, can slide 2 right`. A screen reader cannot move logs yet;
see [Still to come](#still-to-come).

The logs share the brown of the tree trunks in Tents, slightly lightened or
darkened for their larger areas, since logs are the one place wood is
literal. The water, boom, marked log and marks use the theme's colors.

## Saving

Progress saves as for Bridges, under keys of its own:

| Key | Value |
| --- | --- |
| `klura.logjam.<level>.<date>` | The game at that level on that day, for example `klura.logjam.normal.2026-11-12` |
| `klura.logjam.history` | The days each level was solved, with the time the first solve took, in the [history format](bridges.md#save-format) shared with Bridges |

A game is a JSON object with a `format` number, now 1, written and read by
`logjam_save.dart`:

```json
{
  "format": 1,
  "level": "normal",
  "date": "2026-11-12",
  "seedKey": "logjam-normal:v1:2026-11-12",
  "puzzle": {
    "width": 4,
    "height": 4,
    "logs": [[1, 1, 2, "row"], [0, 0, 2, "column"], [3, 1, 2, "column"]]
  },
  "fewestMoves": 2,
  "moves": [[2, 2], [0, 2]],
  "bestMoves": 2,
  "playedMs": 252345,
  "solved": true
}
```

| Field | Meaning |
| --- | --- |
| `level`, `date` | The level and the local calendar date of the puzzle |
| `seedKey` | The key the puzzle was generated from, as a record only |
| `puzzle` | The grid size and each log as the column and row of its left or top cell, its length and whether it lies along a row or a column, the marked log first |
| `fewestMoves` | The fewest moves that solve the puzzle, from the generator |
| `moves` | The player's moves since the start or the last start over, each as the index of its log and the offset it slid to, as in `LogjamMove`. The board follows from them, and undo reaches back across a reload |
| `bestMoves` | The fewest moves of any solve that day, or `null` before one |
| `playedMs` | The time played in milliseconds, which stops at the first solve |
| `solved` | Whether the game was ever solved; a start over clears the moves but not this |

A game that cannot be read counts as missing, as for Bridges: text that is
not JSON, a missing or mistyped field, another format version, a date that
does not exist, logs that break the rules of the board, a move that is not
legal where it is played or comes after the solve, or a best below the
fewest moves.

## Still to come

- The levels need playtesting: whether fewest moves matches how hard a board
  feels, and whether joined slides feel fair.
- The interaction has been tried in Chrome. It still needs a session on a
  real phone.
- A Hard level of 20 moves or more needs another way to make puzzles than
  generating them on the device in the moment. One is a set of puzzles that
  Klura's own generator finds ahead of time, shipped with the app and picked
  by the day's seed.
- Screen-reader play. The board is designed for it: each log is already a
  node of its own with a label, and a move slides one log, so each node
  could take increase and decrease actions that slide it a cell, with the
  moves announced in a live region. Semantics should stay on demand,
  through Flutter's own button that turns them on, since always-on
  semantics hold back pointer presses on tappable nodes by up to 200 ms on
  the web ([flutter#130162](https://github.com/flutter/flutter/issues/130162)).
  The first step is a one-day trial of how well Flutter's web engine passes
  those actions to VoiceOver, TalkBack and NVDA.
