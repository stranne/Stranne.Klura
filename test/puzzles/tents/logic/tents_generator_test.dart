import 'package:klura/puzzles/tents/logic/tents_generator.dart';
import 'package:klura/puzzles/tents/logic/tents_rules.dart';
import 'package:klura/puzzles/tents/logic/tents_solver.dart';
import 'package:klura/puzzles/tents/logic/tents_text.dart';
import 'package:test/test.dart';

void main() {
  group('daily puzzle', () {
    test('uses a seed key for each level and the local date', () {
      final date = DateTime(2026, 11, 12, 23, 30);

      expect(
        tentsDailySeedKey(TentsLevel.normal, date),
        'tents-normal:v1:2026-11-12',
      );
      expect(
        tentsDailySeedKey(TentsLevel.hard, date),
        'tents-hard:v1:2026-11-12',
      );
    });

    test('is generated from its seed key and level', () {
      final generated = generateDailyTents(
        TentsLevel.hard,
        DateTime(2026, 11, 12),
      );

      expect(generated.seedKey, 'tents-hard:v1:2026-11-12');
      expect(
        generated.puzzle,
        generateTents(generated.seedKey, TentsLevel.hard.config).puzzle,
      );
    });

    test('is the same every time for the same date', () {
      final date = DateTime(2027, 3, 2);

      final first = generateDailyTents(TentsLevel.normal, date);
      final second = generateDailyTents(TentsLevel.normal, date);

      expect(second.puzzle, first.puzzle);
      expect(second.solution, first.solution);
      expect(second.attempts, first.attempts);
    });

    // Every daily puzzle for about two years, from the first day Tents is
    // offered. Each must be valid, unique and suit its level. The attempt
    // ceiling keeps generation cheap: attempts are deterministic, unlike
    // timings, and the worst day needed fewer than 70 when it was set.
    for (final level in TentsLevel.values) {
      test('is valid, unique and ${level.name} for every day of two years', () {
        const attemptCeiling = 150;
        final config = level.config;
        final failures = <String>[];

        for (var day = 0; day < 731; day++) {
          final date = DateTime.utc(2026, 11, 12 + day);
          final generated = generateDailyTents(level, date);
          final puzzle = generated.puzzle;
          final check = checkTents(puzzle, generated.solution);
          final solutions = solveTents(puzzle);

          final problems = [
            if (puzzle.width != config.width || puzzle.height != config.height)
              'size ${puzzle.width}x${puzzle.height}',
            if (puzzle.trees.length != config.tentCount)
              '${puzzle.trees.length} trees',
            if (!check.isSolved) 'a solution that breaks the rules',
            if (solutions.length != 1) '${solutions.length} solutions',
            if (solutions.isNotEmpty && solutions.first != generated.solution)
              'a different solution from the solver',
            if (!config.accepts(gradeTents(puzzle)))
              'a grade outside the level',
            if (generated.attempts > attemptCeiling)
              '${generated.attempts} attempts',
          ];
          if (problems.isNotEmpty) {
            failures.add(
              '${generated.seedKey} has ${problems.join(', ')}:\n'
              '${formatTents(puzzle, generated.solution)}',
            );
          }
        }

        expect(failures, isEmpty, reason: failures.join('\n'));
      });
    }
  });

  group('TentsLevel', () {
    test('makes hard puzzles larger and harder than normal ones', () {
      final normal = TentsLevel.normal.config;
      final hard = TentsLevel.hard.config;

      expect(
        hard.width * hard.height,
        greaterThan(normal.width * normal.height),
      );
      expect(hard.tentCount, greaterThan(normal.tentCount));
      expect(hard.minReasoning.index, greaterThan(normal.maxReasoning.index));
    });

    test('gives normal puzzles enough to think about', () {
      final normal = TentsLevel.normal.config;

      expect(normal.minReasoning, TentsReasoning.advanced);
      expect(normal.minOpenAfterBasic, greaterThan(0));
    });
  });

  group('generateTents', () {
    test('builds puzzles of a custom size and grade', () {
      const config = TentsConfig(
        width: 7,
        height: 5,
        tentCount: 7,
        minReasoning: TentsReasoning.advanced,
      );

      for (final key in ['small:1', 'small:2', 'small:3']) {
        final generated = generateTents(key, config);

        expect(generated.puzzle.width, 7);
        expect(generated.puzzle.height, 5);
        expect(generated.puzzle.trees, hasLength(7));
        expect(
          generated.grade.reasoning.index,
          greaterThanOrEqualTo(TentsReasoning.advanced.index),
        );
        expect(solveTents(generated.puzzle), [generated.solution]);
      }
    });

    test('counts its attempts', () {
      final generated = generateTents('key', TentsLevel.normal.config);

      expect(generated.attempts, greaterThanOrEqualTo(1));
    });

    group('rejects', () {
      final cases = {
        'no tents': const TentsConfig(width: 5, height: 5, tentCount: 0),
        'more tents than fit apart': const TentsConfig(
          width: 4,
          height: 4,
          tentCount: 5,
        ),
        'an empty grid': const TentsConfig(
          width: 0,
          height: 5,
          tentCount: 1,
        ),
        'a grid too small for a tent and its tree': const TentsConfig(
          width: 1,
          height: 2,
          tentCount: 1,
        ),
        'puzzles that need search': const TentsConfig(
          width: 5,
          height: 5,
          tentCount: 4,
          maxReasoning: TentsReasoning.search,
        ),
        'a reasoning range that is empty': const TentsConfig(
          width: 5,
          height: 5,
          tentCount: 4,
          minReasoning: TentsReasoning.lookahead,
          maxReasoning: TentsReasoning.advanced,
        ),
      };

      for (final MapEntry(key: description, value: config) in cases.entries) {
        test(description, () {
          expect(() => generateTents('key', config), throwsArgumentError);
        });
      }
    });
  });

  // These boards, drawn with their solutions, pin down the exact output of
  // the generator, so a change that would alter an existing daily puzzle
  // cannot slip through unnoticed.
  group('snapshot', () {
    final snapshots = {
      (TentsLevel.normal, DateTime(2026, 11, 12)): '''
  13121112
2 .^.^....
1 .TTT..T^
3 ^T^T^...
1 ...T..T^
2 T^.^....
1 ......^.
1 .^T...T.
1 ....T^..
''',
      (TentsLevel.normal, DateTime(2028, 2, 29)): '''
  21213030
2 ^T^.T...
2 T...^.^.
1 ..^T..T.
3 ^..T^.^T
0 T.......
1 ...^....
2 .^TT.T^.
1 ...T^...
''',
      (TentsLevel.hard, DateTime(2026, 11, 12)): '''
  3131313122
0 T...T....T
5 ^.^T^T^..^
0 ..........
3 ..^T^T.^T.
2 ^T.......^
1 .....T^..T
2 .^.^....T.
2 TT.T.^..^.
1 ^....TT...
4 .T^.^T^T^.
''',
      (TentsLevel.hard, DateTime(2028, 2, 29)): '''
  1313212223
1 .T......^.
3 .^T^.T^.T.
1 ....T...^.
2 ..^.^.T.T.
2 ^TT.T.^..T
2 ....^....^
2 T^.T...^TT
2 ...^.....^
3 .^...^.^T.
2 .TT^.T..T^
''',
    };

    for (final MapEntry(key: (level, date), value: expected)
        in snapshots.entries) {
      final key = tentsDailySeedKey(level, date);

      test(key, () {
        final generated = generateDailyTents(level, date);

        expect(
          formatTents(generated.puzzle, generated.solution),
          expected,
          reason:
              'The generator now builds a different puzzle for $key. If the '
              'change is intentional, increase tentsGeneratorVersion so '
              'saved games never refer to a puzzle that has silently '
              'changed, then update these snapshots.',
        );
      });
    }
  });
}
