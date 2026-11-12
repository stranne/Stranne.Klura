# Logjam

Logjam is the working name of the third Klura puzzle, a sliding-block
planning puzzle chosen to train planning moves in the right order and holding
in mind what the board does not show, as [Mental gym](mental-gym.md)
describes. The best-known version of the genre is a commercial board game.
Klura uses none of its name, theme or levels, and its own puzzles, visuals
and wording.

The proposed theme is timber floating, the way logs were once driven down
Swedish rivers: logs have jammed in the river, and the player frees them one
slide at a time until the marked log can float out through a gap in the
boom. The name, the theme, the levels and how moves are counted are still to
be decided.

So far only the Flutter-free logic exists: the board, its moves, the solver,
the generator and a text notation. There is no screen, game state or save
format yet.

## Rules

1. The board is a grid of 6 × 6 cells holding logs two or three cells long,
   each lying along a row or a column.
2. A log slides only along its own length, any distance, as long as no other
   log is in its way. It never turns or leaves the board.
3. One log is marked. It lies along the row with the exit, on the right edge
   of the board, and the puzzle is solved when it reaches the exit.

One move slides one log any distance. Every move can be undone, so no
position is a dead end. Any moves that bring the marked log to the exit
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
first search. After a solve the app is meant to say `Solved in N moves ·
fewest possible M`, which gives a replay a goal without showing the way.

A move slides a log any distance, which matches a drag on the screen. Counted
one cell at a time instead, the sample puzzles below need 1.0 to 1.6 times as
many moves. Whether fewest moves matches how hard a board feels is unknown.
A long forced sequence may be easier than a short one that starts with a
move away from the exit, so the levels need playtesting.

## Code

The logic lives in `lib/puzzles/logjam/logic/` and does not depend on
Flutter.

| File | Responsibility |
| --- | --- |
| `logjam_board.dart` | `LogjamPiece`, `LogjamMove` and `LogjamBoard`: the grid with its logs where they lie, the legal moves and whether the marked log has reached the exit |
| `logjam_solver.dart` | `solveLogjam`, one shortest solution, and `exploreLogjam`, every position reachable from a board with the fewest moves each needs |
| `logjam_generator.dart` | `LogjamLevel`, `LogjamConfig`, `generateLogjam` and the daily entry point |
| `logjam_text.dart` | `formatLogjam` and `parseLogjam`: a text notation for tests |

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

## Still to come

- The name, the theme, the levels and whether a move counts per slide or per
  cell.
- A Hard level of 20 moves or more needs another way to make puzzles than
  generating them on the device in the moment. One is a set of puzzles that
  Klura's own generator finds ahead of time, shipped with the app and picked
  by the day's seed.
- The game state, the save format and the screen. Klura's third puzzle is the
  point to reconsider screen-reader play, with a board designed for it from
  the start.
