# Tall Tales

Tall Tales is the fourth Klura puzzle, a statement-logic puzzle chosen to
train judging which statements can be true together and following a guess
to a contradiction, as [Mental gym](mental-gym.md) describes. The genre is
old: puzzles where some people always tell the truth and the others always
lie are best known from puzzle books that call them knights and knaves.
Klura uses none of their names, characters or puzzles. Its fishers,
statements and wording are its own.

The theme is a jetty at the end of the day, where fishers tell what they
caught. Some always tell the truth. The others always tell tall tales, the
fish stories of the one that got away.

## Rules

1. Each fisher either always tells the truth or always tells tall tales.
2. Each fisher makes one statement. A truth-teller's statement is true and a
   teller of tall tales' statement is false.
3. Exactly one way of marking every fisher makes every statement fit.
4. Two fishers are alike when both tell the truth or both tell tall tales.
   `Us` is everyone on the jetty, the speaker included.

The game checks the statements rather than compare with a stored solution;
since only one marking fits, a marking that fits is the solution.

## Daily puzzle

Each day has one puzzle per level, generated on the device by
`generateDailyTallTales(level, localDate)` from the seed key
`dailySeedKey(puzzleId: 'tall-tales-<level>', generatorVersion:
tallTalesGeneratorVersion, date: localDate)`, for example
`tall-tales-normal:v1:2026-11-13`. Generation uses only `SeededRandom`.
Increase `tallTalesGeneratorVersion` whenever a change would alter the
puzzle for an existing key; the puzzle itself is saved together with the
player's progress.

| Level | Fishers | Reasoning | Suppositions | Open after basic |
| --- | --- | --- | --- | --- |
| Normal | 7 | Advanced | None | At least 4 |
| Hard | 8 | Lookahead | At least 1 | At least 6 |

[Difficulty](#difficulty) explains the columns. There are names for eight
fishers, and in the puzzles tried, eight fit on a phone 390 pixels wide and
844 tall without scrolling at the normal text size. The levels are a first guess and
need playtesting: [Logjam](logjam.md#daily-puzzle) showed that a first guess
can be solved far faster than the few minutes Klura aims for.

## Statements

Each fisher's statement makes one of these claims, with `X`, `Y` and `Z`
for other fishers and `N` for a count:

| Claim | Words | Weight |
| --- | --- | --- |
| `truthful` | X tells the truth. | 3 |
| `tallTales` | X tells tall tales. | 3 |
| `alike` | X and Y are alike. | 2 |
| `notAlike` | X and Y are not alike. | 2 |
| `bothTruthful` | X and Y both tell the truth. | 2 |
| `bothTallTales` | X and Y both tell tall tales. | 2 |
| `eitherTruthful` | At least one of X and Y tells the truth. | 2 |
| `ifTruthful` | If X tells the truth, so does Y. | 2 |
| `oneOfThreeTruthful` | Exactly one of X, Y and Z tells the truth. | 1 |
| `countTruthful` | Exactly N of us tell the truth. | 1 |
| `countTallTales` | Exactly N of us tell tall tales. | 1 |
| `alikeMe` | X and I are alike. | 1 |
| `notAlikeMe` | X and I are not alike. | 1 |
| `bothTallTalesMe` | X and I both tell tall tales. | 1 |
| `eitherTallTalesMe` | At least one of X and me tells tall tales. | 1 |

The weight is how often the generator picks the claim, relative to the
others. Names in a claim where order makes no difference come in the order
the fishers sit, and a count is between 1 and one less than the number of
fishers. Counts are written in words, and `Exactly one of us tells` takes
the singular.

The last four claims are about the speaker too, and each settles the fisher
it names on its own, whatever the speaker is: `Bo and I are not alike` makes
Bo a teller of tall tales either way. They are the usual way into a puzzle,
and once a player knows the trick they are quick, so a puzzle has at most
two. A puzzle also has at most two counts, since each depends on every
fisher. No two fishers say the same thing, even in other words: among eight
fishers, `Exactly three of us tell the truth` says what `Exactly five of us
tell tall tales` does.

There is no statement about the speaker alone. `I tell tall tales` cannot be
said at all, and `I tell the truth` says nothing.

## Difficulty

`gradeTallTales` solves a puzzle from no marks the way a person reasons, and
measures three things:

- **Reasoning**, the least of these that solves the puzzle:
  1. *Basic*: one statement at a time. A statement settles a fisher when
     only one kind fits it, given the kinds already known.
  2. *Advanced*: also links between fishers. A statement can show that two
     fishers are alike or not alike, as `Alva: Bo tells the truth` makes
     Alva and Bo alike, and the link then carries over to other
     statements.
  3. *Lookahead*: also supposing one fisher's kind, following basic and
     advanced reasoning and finding that a statement breaks.
  4. *Search*: deeper trial and error, or no single solution.
- **Suppositions**: how many times lookahead had to suppose a fisher's
  kind.
- **Open after basic**: how many fishers basic reasoning leaves undecided,
  the fishers a player has to think about rather than read off.

Any grade below search proves that the puzzle has exactly one solution,
because every deduction holds for every solution. Of 1000 generated puzzles
of eight fishers that reasoning solves, 53 % needed only basic reasoning,
34 % advanced, 12 % one supposition and 2 % two. With seven fishers it was
56 %, 31 %, 13 % and 1 %. Normal therefore asks for links but no
supposition, and leaves out the many puzzles that one opening statement
unravels. Hard asks for at least one supposition. Asking for two would make
Hard harder at about seven times the attempts.

For example, the Normal puzzle of 2026-11-13:

```text
- Alva: Bo and Ebba are not alike.
- Bo: Cajsa and Ebba are not alike.
- Cajsa: Ebba tells the truth.
+ Dag: At least one of Bo and Greta tells the truth.
- Ebba: Exactly one of Alva, Bo and Cajsa tells the truth.
+ Frej: If Bo tells the truth, so does Alva.
+ Greta: Frej tells the truth.
```

No statement settles anyone on its own. Cajsa vouches for Ebba, so the two
are alike, which makes Bo's statement false: Bo tells tall tales. Then
Frej's statement is true, so Frej tells the truth, and so do Greta, who
vouches for Frej, and Dag. With Bo telling tall tales, Alva's statement
says that Ebba tells the truth, so Alva and Ebba are alike too. Last, if Alva,
Cajsa and Ebba all told the truth, two of Alva, Bo and Cajsa would, and
Ebba's statement would be false; so all three tell tall tales.

## Code

The logic lives in `lib/puzzles/tall_tales/logic/` and does not depend on
Flutter. The screen that plays it lives beside it in
`lib/puzzles/tall_tales/`. It shares the timer, controller base, daily
games, storage, solve history and puzzle screen with the other puzzles, as
the [README](../README.md#layout) describes.

| File | Responsibility |
| --- | --- |
| `tall_tales_puzzle.dart` | `tallTalesNames`, `TallTalesClaim`, `TallTalesStatement` and `TallTalesPuzzle`: the fishers and their statements, whether each statement is true for given kinds, and `possibleStatements`, every statement a fisher can make |
| `tall_tales_marks.dart` | `TallTalesMark` and `TallTalesMarks`: the player's marks as an immutable value |
| `tall_tales_wording.dart` | `statementParts` and `statementText`: each statement in words, with the names it holds as parts of their own |
| `tall_tales_rules.dart` | `checkTallTales`: judges marks against the statements |
| `tall_tales_solver.dart` | `solveTallTales`, which finds solutions up to a limit, and `gradeTallTales` |
| `tall_tales_generator.dart` | `TallTalesLevel`, `TallTalesConfig`, `generateTallTales` and the daily entry point |
| `tall_tales_text.dart` | `formatTallTales` and `parseTallTales`: a text notation for tests |
| `tall_tales_game.dart` | `TallTalesGame`: a game in progress, with its moves, undo history and rules check |
| `tall_tales_save.dart` | `TallTalesSave` and its JSON save format |
| `tall_tales_storage.dart` | `TallTalesStorage`: the shared `DailyStorage` for Tall Tales |

| File in `lib/puzzles/tall_tales/` | Responsibility |
| --- | --- |
| `tall_tales_controller.dart` | `TallTalesController`: the shared `PuzzleController` for a `TallTalesGame`, with its moves |
| `tall_tales_daily_games.dart` | `TallTalesDailyGames`: the shared `DailyGames` for Tall Tales |
| `tall_tales_screen.dart` | The game screen: the shared `PuzzleScreen` with the jetty, the note once every fisher is marked and how to play |
| `tall_tales_board.dart` | The jetty widget: the planks, marks, keyboard, semantics and the solve |

## Rules check

`checkTallTales` gives each statement one of three statuses. A statement is
*open* until everyone it depends on is marked: its speaker and the fishers
it names, or every fisher for a count. Then it *fits* if it is true for a
truth-teller or false for a teller of tall tales, and is *broken*
otherwise. The marks solve the puzzle when every statement fits, which
needs every fisher marked, since each statement depends on its speaker.

A statement stays open even where the marks so far already break it
whatever the rest turn out to be, such as a count of two truth-tellers with
three already marked. Judging it earlier would mean working out what the
unmarked fishers could be, which is the player's thinking. A broken
statement is a plain fact about the marks.

The screen shows none of these statuses. The first version gave a broken
statement a red edge and named it in the status line, as Bridges and Tents
mark a broken rule. In the first playtest that made the puzzle easy without
thinking: a fisher has only two kinds and a statement depends on two to
four fishers, so changing whichever fisher a red statement named soon
fixed it. Now nothing is judged while the player marks. Once every fisher
is marked and the puzzle is not solved, the status line says only `Every
fisher is marked, but not every statement fits`. It names no statement and
gives no count, since a count would let the player home in by trial.
Finding the mistake is the player's: the marks beside the names in each
statement let them check it at a glance.

## Solver

With at most eight fishers there are at most 256 markings, so
`solveTallTales` tries every one, as bit sets of truth-tellers, and keeps
those that fit. It knows nothing of how the puzzle was made, and is too
simple to get wrong.

`gradeTallTales` keeps what reasoning has found: each fisher's kind, if
known, and groups of linked fishers, each member with a flag for whether it
is alike the group's leader or not, so that knowing one member's kind gives
every member's. Applying a statement tries every way to complete the kinds
it depends on that keeps to the links among them, and keeps the ways the
statement fits. A fisher who has the same kind in every way is settled.
With links, two fishers who are alike in every way, or unlike in every way,
become linked. Basic reasoning applies the statements without links until
none settles anything more, advanced reasoning with them, and lookahead
supposes each undecided fisher's kind in turn until one supposition leads
to a broken statement.

A test grades 400 puzzles of random statements, most of which have several
solutions or none, and checks that every puzzle graded below search has
exactly one solution.

## Generator

`generateTallTales` picks the solution first and then the statements, so
every statement fits it. Each attempt:

1. Picks how many fishers tell the truth, at least two and leaving at least
   two who tell tall tales, and which ones.
2. Gives each fisher in turn a statement that is true for a truth-teller
   and false for a teller of tall tales: first a claim at random by its
   weight, among those with such a statement, then one of its statements.
   Claims about the speaker and counts drop out once a puzzle has two, and
   a statement that says what another fisher has said drops out too.
3. Grades the puzzle and keeps it only if the grade is below search and
   suits the level. The solver then confirms that the marking it was built
   from is the single solution.

Attempt n draws from `SeededRandom.fromKey('<seed key>#n')`, up to 1000
attempts. About two attempts in five give a puzzle that reasoning solves;
the level's grade decides how many more it takes.

## Performance

`dart run tool/benchmark_tall_tales.dart` generates the 731 daily puzzles of
each level from 2026-11-13; the script's documentation also shows how to run
it compiled to JavaScript under Node.js. On 2026-11-13, on the development
machine (Windows on ARM):

| | Normal, VM | Normal, Node.js | Hard, VM | Hard, Node.js |
| --- | --- | --- | --- | --- |
| First puzzle, cold | 53 ms | 27 ms | 8.8 ms | 10 ms |
| Mean | 3.9 ms | 5.7 ms | 13 ms | 20 ms |
| 95th percentile | 12 ms | 18 ms | 35 ms | 58 ms |
| Worst | 37 ms | 40 ms | 98 ms | 149 ms |

Hard runs after Normal in the same process, so its first puzzle is not
cold. Normal puzzles need 8.2 attempts on average and 59 at worst
(2028-07-29); Hard puzzles need 17 on average and 129 at worst
(2027-05-27). Most of the time goes to grading.

The two-year test fails if any day needs more than 200 attempts. The daily
puzzles of both levels were identical on the VM, in JavaScript and in
WebAssembly.

## Text notation

Tests write puzzles as text with `formatTallTales` and `parseTallTales`.
Each line is a fisher, in the order they sit: a mark, the fisher's name, a
colon and the statement as the player reads it. A puzzle without marks may
leave them out.

| Mark | Fisher |
| --- | --- |
| `+` | Tells the truth |
| `-` | Tells tall tales |
| `.` | Unmarked |

The parser finds each statement among those its speaker can make, by its
words, so the notation also checks the wording. [Difficulty](#difficulty)
has an example.

## Playing

The home screen lists today's Normal and Hard puzzles after Logjam, with
the number of fishers and how far each game has come. With four puzzles, a
wide screen shows two rows of two cards rather than a row of three and one
card alone. The routes are `#/tall-tales/normal` and `#/tall-tales/hard`.
Generation, saving, the move to a new day, undo, start over, the timer and
the solved panel work as for Bridges; see [Playing](bridges.md#playing).

### The jetty

The fishers sit on planks of a jetty over calm water, one plank each, in
the order of their names. A plank holds the fisher's name and their
statement in quotes, as in a script, with the mark on the right: a check
in the theme's primary color for the truth, a fish in a warm brown for tall
tales and a dashed ring for none, with the words `Truth` or `Tall tales`
below. Each name in a statement has the named fisher's mark beside it, a
faint ring until they are marked, so the player never has to look a mark up
and the text keeps its lines as marks come and go. The planks keep to 560
pixels, so lines stay easy to read on a large screen, and the jetty scrolls
where they do not all fit.

### Marking fishers

- **Tap** a plank to move its fisher through the truth, tall tales and
  unmarked. The whole plank is the target.
- **Keys**: the jetty is a single tab stop, and as in Bridges an arrow key
  pressed while anything else has the focus gives it to the jetty, only
  showing the focus ring, first on Alva. The up and down arrows move the
  ring, and Space or Enter changes the mark under it. Ctrl+Z or Cmd+Z
  undoes.
- **Mouse**: a plank brightens under the pointer, which turns into a hand.

### Feedback

- Nothing is judged while the player marks; see [Rules
  check](#rules-check). Once every fisher is marked and the puzzle is not
  solved, the status line says `Every fisher is marked, but not every
  statement fits`, and nothing on the jetty shows which. Clearing a mark
  takes the note away until every fisher is marked again.
- When a move solves the puzzle, a wave starts at that plank and lifts each
  plank once, a little later the farther it is. With reduced motion the
  jetty skips it.
- A truth mark plucks one clear, round note, a tall-tales mark a woodier
  note that bends up a little, like a story growing in the telling, and
  clearing a mark the lower, falling note of a removed tent. The move that
  solves the puzzle chimes instead.

### Accessibility

Each plank is a button for screen readers, with a label of its speaker,
statement and mark, for example `Bo says: Cajsa and Ebba are not alike.
Marked as telling tall tales.` Like the jetty, the label never says whether
the statement fits. A tap
action changes the mark, so the puzzle can be played with a screen reader,
with semantics turned on through Flutter's own button as for the other
puzzles. The jetty has a label with its fishers and how many are marked.
Nothing depends on color alone: the marks differ in shape and have words
below. Larger text wraps the statements onto more
lines and the jetty scrolls; the word below a mark shrinks rather than
widen its column. The water, the planks and the brown of tall tales are
chosen for each brightness; the rest uses the theme's colors.

## Saving

Progress saves as for Bridges, under keys of its own:

| Key | Value |
| --- | --- |
| `klura.tall-tales.<level>.<date>` | The game at that level on that day, for example `klura.tall-tales.normal.2026-11-13` |
| `klura.tall-tales.history` | The days each level was solved, with the time the first solve took, in the [history format](bridges.md#save-format) shared with Bridges |

A game is a JSON object with a `format` number, now 1, written and read by
`tall_tales_save.dart`:

```json
{
  "format": 1,
  "level": "normal",
  "date": "2026-11-13",
  "seedKey": "tall-tales-normal:v1:2026-11-13",
  "statements": [
    {"claim": "countTallTales", "count": 2},
    {"claim": "ifTruthful", "named": [2, 0]},
    {"claim": "alike", "named": [0, 1]}
  ],
  "marks": ["truth", null, "tallTales"],
  "playedMs": 252345,
  "solved": false
}
```

| Field | Meaning |
| --- | --- |
| `level`, `date` | The level and the local calendar date of the puzzle |
| `seedKey` | The key the puzzle was generated from, as a record only |
| `statements` | Each fisher's statement in the order they sit: its claim with the places of the fishers it names, or its count |
| `marks` | Each fisher's mark: `truth`, `tallTales` or `null` |
| `playedMs` | The time played in milliseconds, which stops at the first solve |
| `solved` | Whether the game was ever solved; a start over clears the marks but not this |

As for Tents, the undo history is not saved. A game that cannot be read
counts as missing, as for Bridges: text that is not JSON, a missing or
mistyped field, another format version, a date that does not exist, an
unknown claim or mark, marks for another number of fishers, or statements
that break the rules of the puzzle models, such as one that names its
speaker.

## Still to come

- The levels need playtesting again now that nothing is judged while the
  player marks: whether advanced reasoning on seven fishers and one
  supposition on eight give a few minutes of thinking, whether the wording
  reads easily, and whether the grade matches how hard a puzzle feels. If
  Hard is too quick, it can ask for two suppositions.
- A player who cannot find the mistake has no help but undo and start over.
  If a hint is ever added, it should point to a deduction, as [Mental
  gym](mental-gym.md#principles) asks, never to a broken statement.
- The interaction has been tried in Chrome. It still needs a session on a
  real phone and with a screen reader.
- The fishers have names only. Simple figures of their own could give the
  jetty more life, if they do not crowd the statements.
- The slowest Hard day takes 149 ms in JavaScript on the development
  machine and may take a few times that on a slow phone. If that shows,
  the grader can stop at the first supposition the level needs.
