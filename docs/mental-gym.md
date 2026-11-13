# Mental gym

Klura aims to be a small daily mental gym: a few minutes of thinking that the
player does unaided, spread over different skills, the way a gym has machines
for different muscles. This document lists what each puzzle trains, the rule
a new puzzle must meet, the candidates considered so far and what research
says about the effect. Read it before proposing or adding a puzzle.

## What each puzzle trains

● marks a main skill of the puzzle, ◐ a skill it also uses and – one it does
not use. The marks are a design judgment from the rules and the solving
techniques in each puzzle's document, not a measurement.

| Area | Skill | Bridges | Tents | Logjam | Tall Tales |
| --- | --- | --- | --- | --- | --- |
| Deduction | Ruling out what cannot be true | ● | ● | ◐ | ◐ |
| Deduction | Seeing how the whole board hangs together | ● | ◐ | ◐ | ◐ |
| Deduction | Counting against a target | ◐ | ● | – | ◐ |
| Deduction | Following a guess to a contradiction | ◐ | ◐ | – | ● |
| Numbers | Arithmetic: sums and combinations | – | – | – | – |
| Planning | Planning moves in the right order | – | – | ● | – |
| Planning | Holding in mind what the board does not show | – | – | ● | ◐ |
| Space | Turning shapes in your head | – | – | – | – |
| Critical thinking | Finding your own mistakes | ◐ | ◐ | – | ● |
| Critical thinking | Testing guesses against hidden information | – | – | – | – |
| Critical thinking | Judging which statements can be true together | – | – | – | ● |
| Language | Words and meaning | – | – | – | – |

What each skill means here:

- **Ruling out what cannot be true**: deciding a cell or connection from the
  rules, as in the basic and advanced reasoning of
  [Bridges](bridges.md#difficulty) and [Tents](tents.md#difficulty).
- **Seeing how the whole board hangs together**: reasoning about the board as
  one structure, such as the connected islands without loops of Bridges, the
  pairing of trees and tents, a chain of pieces blocking each other, or
  fishers linked as alike across several statements.
- **Counting against a target**: comparing what is placed with a number, such
  as an island's number or a row's tents.
- **Following a guess to a contradiction**: the lookahead that Hard levels
  require, trying one move and finding that it breaks a rule. In Tall Tales
  it is the main move of Hard: supposing what one fisher is and following
  it through the statements.
- **Arithmetic**: adding numbers and finding which combinations reach a sum.
- **Planning moves in the right order**: finding which move has to come
  first, when the board changes with every move.
- **Holding in mind what the board does not show**: picturing the board a
  few moves ahead, rather than reading facts off the board in front of you.
- **Turning shapes in your head**: rotating and flipping shapes to see where
  they fit.
- **Finding your own mistakes**: noticing that something earlier was wrong
  and tracing back to it.
- **Testing guesses against hidden information**: choosing what to try next
  so that the answer tells you the most.
- **Judging which statements can be true together**: working out which claims
  hold when some contradict others, as in [Tall Tales](tall-tales.md).
- **Words and meaning**: vocabulary, spelling and meaning.

Critical thinking is not one skill, so the table splits it into the parts a
puzzle can demand. Judging real claims also needs knowledge of the subject,
which no puzzle trains.

Bridges and Tents mark a broken rule at once: a loop, an overfull island,
touching tents. That takes over part of finding mistakes. A move that breaks
no rule but is still wrong is left for the player to find, so the row is ◐.
A level that marks less would train it more, at some cost to calm. That is
undecided.

Tall Tales judges nothing while the player marks the fishers, and once
every fisher is marked says only whether every statement fits. Its first version marked
broken statements at once, and in the first playtest that let the player
solve it by changing whichever fisher a red statement named: with two kinds
per fisher, the mark all but gave the fix away. Finding the mistake is now
the player's, so the row is ●.

## Choosing a new puzzle

- A new puzzle's main skill must be one that no existing puzzle has as a main
  skill. A puzzle that mainly rules things out on a grid, such as Kakuro,
  Nonograms or Slitherlink, would be a third puzzle for the skill Bridges and
  Tents already train, however good it is.
- Add a column when a puzzle is designed, and update it when playtesting
  shows that the puzzle trains something else.

| Candidate | Main skill | Status |
| --- | --- | --- |
| Sliding blocks: pieces slide along their own line on a small grid until a marked piece can leave | Planning moves in the right order, holding in mind what the board does not show | Built as [Logjam](logjam.md). Every move can be undone, so there is no dead end. The fewest moves gives the difficulty, and showing it after a solve gives a replay a goal. The best-known version is a commercial board game, so the name, theme and levels are Klura's own. |
| Shape packing: fit pieces into an outline | Turning shapes in your head | Later. Rotating and flipping pieces on a phone is fiddly. |
| Statement logic: a few characters make claims about each other, and exactly one choice of who tells the truth fits | Judging which statements can be true together, following a guess to a contradiction | Built as [Tall Tales](tall-tales.md). The generator checks every choice of up to eight fishers, and a grader that reasons as a person does sets the levels. The wording stays short and plain, from fifteen kinds of claim. |
| Code-breaking: guess a hidden code and learn from each score | Testing guesses against hidden information | Passed over for now. Luck decides part of the result, there is one secret a day, and it is close to Wordle. Giving all the guesses and scores up front turns it into ruling out again. |
| Word puzzles | Words and meaning | Passed over for now. They need a choice of language and a licensed word list, and generated word puzzles are hard to make good. |
| Kakuro, Nonograms, Slitherlink and similar grid puzzles | Ruling out what cannot be true | Passed over. The main skill is already trained. Kakuro also trains arithmetic, but only as a side skill. |

## Principles

- **Breadth.** Each puzzle adds a skill, as [Choosing a new
  puzzle](#choosing-a-new-puzzle) requires.
- **Challenge that keeps up.** Fixed levels get easier as the player
  improves. Prefer a harder level, or a new puzzle with new rules to learn,
  over more of the same.
- **Never do the player's thinking.** The rules check judges the board
  instead of revealing the answer, and nothing is marked automatically. If a
  hint is ever added, it points to where a deduction is and never makes the
  move.
- **An invitation, not a duty.** There is [no streak](bridges.md#no-streak)
  and no time pressure, so a few minutes a day stay calm.
- **No health claims.** Klura is thinking the player does unaided. The app
  and its documents never claim that it improves memory or thinking, or that
  it slows decline or protects against dementia.

## What research says

As of 2026-11-12, from the abstracts and summaries of these studies:

- Practice improves the practiced task. Evidence that the gains reach closely
  related tasks is weaker, and evidence that they reach everyday thinking is
  slight ([Simons et al., 2016](https://doi.org/10.1177/1529100616661983)).
- Meta-analyses find close to no effect of cognitive training on general
  cognition ([Sala and Gobet, 2019](https://eprints.lse.ac.uk/102168)). Some
  researchers dispute this.
- In the ACTIVE trial, speed training kept up with later booster sessions was
  followed by fewer dementia diagnoses over 20 years, with a hazard ratio of
  0.75 (95 % CI 0.59 to 0.95). Without boosters it was 1.01, and memory and
  reasoning training showed no main effect ([Coe et al.,
  2026](https://pure.johnshopkins.edu/en/publications/impact-of-cognitive-training-on-claims-based-diagnosed-dementia-o/)).
  A reanalysis finds that no single result holds after correcting for the
  number of comparisons, while all the training types lean the same way
  ([Dickens, 2026](https://pmc.ncbi.nlm.nih.gov/articles/PMC13284741/)).
  Klura does not push speed: the result is disputed, and time pressure would
  cost calm.
- Adults over 50 who often do number puzzles score better on cognitive
  tests, but the study compares people at one point in time, so the cause is
  unknown ([Brooker et al., 2019](https://pubmed.ncbi.nlm.nih.gov/30746778/)).
- In a small trial of people with mild cognitive impairment, crosswords did
  better than computerized brain games over 78 weeks. It had no group without
  training ([Devanand et al.,
  2022](https://columbiapsychiatry.org/news/crossword-puzzles-superior-computer-video-games-slowing-memory-loss-older-adults-mild-cognitive-impairment)).
- Other things have stronger evidence. A two-year trial of exercise, diet,
  mental stimulation and social contact improved cognition modestly ([U.S.
  POINTER, 2025](https://alz.org/us-pointer/study-results)), and the 14
  modifiable risk factors for dementia of the [2024 Lancet
  Commission](https://doi.org/10.1016/S0140-6736(24)01296-0) do not include
  puzzles.
- Older adults who learned a demanding new skill, about 15 hours a week for
  three months, improved their memory more than those in social or passive
  activities ([Park et al., 2014](https://pubmed.ncbi.nlm.nih.gov/24214244/)).
- Surveys link heavy use of AI, or high trust in it, with less critical
  thinking ([Gerlich, 2025](https://doi.org/10.3390/soc15010006); [Lee et al.,
  2025](https://doi.org/10.1145/3706598.3713778)), and a small preprint found
  lower brain engagement while people wrote with an AI assistant ([Kosmyna et
  al., 2025](https://arxiv.org/abs/2506.08872)). These are early, correlational
  or small. None shows a lasting decline, and none shows that puzzles make up
  for one.
- The US Federal Trade Commission fined the maker of Lumosity in 2016 for
  claiming that its games delay decline and dementia
  ([FTC](https://www.ftc.gov/news-events/press-releases/2016/01/lumosity-pay-2-million-settle-ftc-deceptive-advertising-charges)).

So daily play makes a player better at the puzzles themselves, and maybe at
similar ones. Whether it improves thinking in general is unproven. What Klura
can honestly offer is a few minutes a day of effortful thinking that the
player does unaided, over a spread of skills, with new rules to learn now and
then.
