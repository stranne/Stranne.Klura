import 'package:klura/core/seeded_random.dart';
import 'package:klura/puzzles/logjam/logic/logjam_generator.dart';
import 'package:klura/puzzles/logjam/logic/logjam_solver.dart';
import 'package:klura/puzzles/logjam/logic/logjam_text.dart';
import 'package:test/test.dart';

void main() {
  group('daily puzzle', () {
    test('uses a seed key for each level and the local date', () {
      final date = DateTime(2026, 11, 12, 23, 30);

      expect(
        logjamDailySeedKey(LogjamLevel.normal, date),
        'logjam-normal:v1:2026-11-12',
      );
      expect(
        logjamDailySeedKey(LogjamLevel.hard, date),
        'logjam-hard:v1:2026-11-12',
      );
    });

    test('is generated from its seed key and level', () {
      final generated = generateDailyLogjam(
        LogjamLevel.hard,
        DateTime(2026, 11, 12),
      );

      expect(generated.seedKey, 'logjam-hard:v1:2026-11-12');
      expect(
        generated.puzzle,
        generateLogjam(generated.seedKey, LogjamLevel.hard.config).puzzle,
      );
    });

    test('is the same every time for the same date', () {
      final date = DateTime(2027, 3, 2);

      final first = generateDailyLogjam(LogjamLevel.normal, date);
      final second = generateDailyLogjam(LogjamLevel.normal, date);

      expect(second.puzzle, first.puzzle);
      expect(second.solution, first.solution);
      expect(second.attempts, first.attempts);
    });

    // Every daily puzzle for about two years, from the first day Logjam is
    // offered. Each must be valid, need a number of moves that suits its
    // level, and need the most moves of any position it can reach. The
    // attempt ceiling keeps generation cheap: attempts are deterministic,
    // unlike timings, and the worst day needed 179 when it was set. The
    // digest covers every puzzle, and this test also runs compiled to
    // JavaScript and WebAssembly, so it shows that every platform builds the
    // same puzzles.
    final digests = {
      LogjamLevel.normal: 'f950a3aa',
      LogjamLevel.hard: '0b8f18ff',
    };
    for (final level in LogjamLevel.values) {
      test('is valid and ${level.name} for every day of two years', () {
        const attemptCeiling = 300;
        final config = level.config;
        final failures = <String>[];
        var digest = 0;

        for (var day = 0; day < 731; day++) {
          final date = DateTime.utc(2026, 11, 12 + day);
          final generated = generateDailyLogjam(level, date);
          final puzzle = generated.puzzle;
          final cluster = exploreLogjam(
            puzzle,
            maxPositions: config.maxPositions,
          );
          var position = puzzle;
          for (final move in generated.solution) {
            position = position.canMove(move) ? position.apply(move) : position;
          }

          final problems = [
            if (puzzle.width != config.width || puzzle.height != config.height)
              'size ${puzzle.width}x${puzzle.height}',
            if (puzzle.exitRow != config.exitRow) 'exit row ${puzzle.exitRow}',
            if (puzzle.pieces.length > config.maxPieces)
              '${puzzle.pieces.length} pieces',
            if (!config.accepts(generated.fewestMoves))
              '${generated.fewestMoves} moves',
            if (!position.isSolved) 'a solution that does not solve it',
            if (solveLogjam(puzzle)?.length != generated.fewestMoves)
              'a different number of moves from the solver',
            if (cluster?.mostMoves != generated.fewestMoves)
              'a reachable position that needs more moves',
            if (cluster?.size != generated.positions)
              'a different number of positions',
            if (generated.attempts > attemptCeiling)
              '${generated.attempts} attempts',
          ];
          if (problems.isNotEmpty) {
            failures.add(
              '${generated.seedKey} has ${problems.join(', ')}:\n'
              '${formatLogjam(puzzle)}',
            );
          }
          digest = SeededRandom.hashKey('$digest ${formatLogjam(puzzle)}');
        }

        expect(failures, isEmpty, reason: failures.join('\n'));
        expect(
          digest.toRadixString(16).padLeft(8, '0'),
          digests[level],
          reason:
              'The generator now builds different ${level.name} puzzles. If '
              'the change is intentional, increase logjamGeneratorVersion, '
              'then update the digests and the snapshots below.',
        );
      });
    }
  });

  group('LogjamLevel', () {
    test('makes hard puzzles need more moves than normal ones', () {
      expect(
        LogjamLevel.hard.config.minMoves,
        greaterThan(LogjamLevel.normal.config.maxMoves),
      );
    });

    test('plays on a square of six cells with the exit on the third row', () {
      for (final level in LogjamLevel.values) {
        expect(level.config.width, 6);
        expect(level.config.height, 6);
        expect(level.config.exitRow, 2);
      }
    });
  });

  group('generateLogjam', () {
    test('builds puzzles of a custom size and number of moves', () {
      const config = LogjamConfig(
        width: 5,
        height: 5,
        minPieces: 6,
        maxPieces: 8,
        minMoves: 3,
        maxMoves: 6,
      );

      for (final key in ['small:1', 'small:2', 'small:3']) {
        final generated = generateLogjam(key, config);

        expect(generated.puzzle.width, 5);
        expect(generated.puzzle.height, 5);
        expect(generated.puzzle.exitRow, 2);
        expect(generated.fewestMoves, inInclusiveRange(3, 6));
        expect(solveLogjam(generated.puzzle), generated.solution);
      }
    });

    test('names the other pieces in reading order', () {
      final puzzle = generateDailyLogjam(
        LogjamLevel.normal,
        DateTime(2026, 11, 12),
      ).puzzle;
      final firstCells = [
        for (final piece in puzzle.pieces.skip(1)) piece.cells.first,
      ];

      expect(firstCells, [...firstCells]..sort());
    });

    test('counts its attempts', () {
      final generated = generateLogjam('key', LogjamLevel.normal.config);

      expect(generated.attempts, greaterThanOrEqualTo(1));
    });

    group('rejects', () {
      final cases = {
        'a board too narrow for the marked piece to move': const LogjamConfig(
          width: 2,
          minMoves: 1,
          maxMoves: 5,
        ),
        'a board one row high': const LogjamConfig(
          height: 1,
          minMoves: 1,
          maxMoves: 5,
        ),
        'a board wider than the limit': const LogjamConfig(
          width: 13,
          minMoves: 1,
          maxMoves: 5,
        ),
        'no pieces': const LogjamConfig(
          minPieces: 0,
          minMoves: 1,
          maxMoves: 5,
        ),
        'a range of pieces that is empty': const LogjamConfig(
          minPieces: 9,
          maxPieces: 8,
          minMoves: 1,
          maxMoves: 5,
        ),
        'puzzles that need no moves': const LogjamConfig(
          minMoves: 0,
          maxMoves: 5,
        ),
        'a range of moves that is empty': const LogjamConfig(
          minMoves: 6,
          maxMoves: 5,
        ),
        'a chance above one': const LogjamConfig(
          longChance: 1.5,
          minMoves: 1,
          maxMoves: 5,
        ),
        'no positions to explore': const LogjamConfig(
          minMoves: 1,
          maxMoves: 5,
          maxPositions: 0,
        ),
      };

      for (final MapEntry(key: description, value: config) in cases.entries) {
        test(description, () {
          expect(() => generateLogjam('key', config), throwsArgumentError);
        });
      }
    });
  });

  // These boards pin down the exact output of the generator, so a change
  // that would alter an existing daily puzzle cannot slip through unnoticed.
  group('snapshot', () {
    final snapshots = {
      (LogjamLevel.normal, DateTime(2026, 11, 12)): (
        8,
        '''
ABBCCC
ADEE.F
GD**HF>
GIIIHJ
GKKLHJ
MM.L.J
''',
      ),
      (LogjamLevel.normal, DateTime(2028, 2, 29)): (
        7,
        '''
ABBBCC
A.DEEE
AFD**G>
.FDHIG
.F.HIJ
KKLLLJ
''',
      ),
      (LogjamLevel.hard, DateTime(2026, 11, 12)): (
        13,
        '''
.AABBB
.CC.DE
FG**DE>
FGHHDI
JK.LLI
JKMMNN
''',
      ),
      (LogjamLevel.hard, DateTime(2028, 2, 29)): (
        10,
        '''
AAB.CC
D.BEEE
DFG**H>
IFGJJH
IFKK.H
ILLMMM
''',
      ),
    };

    for (final MapEntry(key: (level, date), value: (moves, expected))
        in snapshots.entries) {
      final key = logjamDailySeedKey(level, date);

      test(key, () {
        final generated = generateDailyLogjam(level, date);

        expect(
          formatLogjam(generated.puzzle),
          expected,
          reason:
              'The generator now builds a different puzzle for $key. If the '
              'change is intentional, increase logjamGeneratorVersion so '
              'saved games never refer to a puzzle that has silently '
              'changed, then update these snapshots.',
        );
        expect(generated.fewestMoves, moves);
      });
    }
  });
}
