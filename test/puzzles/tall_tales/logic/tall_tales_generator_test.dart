import 'package:klura/puzzles/tall_tales/logic/tall_tales_generator.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_marks.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_puzzle.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_rules.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_solver.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_text.dart';
import 'package:test/test.dart';

void main() {
  group('daily puzzle', () {
    test('uses a seed key for each level and the local date', () {
      final date = DateTime(2026, 11, 13, 23, 30);

      expect(
        tallTalesDailySeedKey(TallTalesLevel.normal, date),
        'tall-tales-normal:v1:2026-11-13',
      );
      expect(
        tallTalesDailySeedKey(TallTalesLevel.hard, date),
        'tall-tales-hard:v1:2026-11-13',
      );
    });

    test('is generated from its seed key and level', () {
      final generated = generateDailyTallTales(
        TallTalesLevel.hard,
        DateTime(2026, 11, 13),
      );

      expect(generated.seedKey, 'tall-tales-hard:v1:2026-11-13');
      expect(
        generated.puzzle,
        generateTallTales(
          generated.seedKey,
          TallTalesLevel.hard.config,
        ).puzzle,
      );
    });

    test('is the same every time for the same date', () {
      final date = DateTime(2027, 3, 2);

      final first = generateDailyTallTales(TallTalesLevel.normal, date);
      final second = generateDailyTallTales(TallTalesLevel.normal, date);

      expect(second.puzzle, first.puzzle);
      expect(second.solution, first.solution);
      expect(second.attempts, first.attempts);
    });

    // Every daily puzzle for about two years, from the first day Tall Tales
    // is offered. Each must be valid, unique and suit its level. The attempt
    // ceiling keeps generation cheap: attempts are deterministic, unlike
    // timings, and the worst day needed 129 when it was set.
    for (final level in TallTalesLevel.values) {
      test('is valid, unique and ${level.name} for every day of two years', () {
        const attemptCeiling = 200;
        final config = level.config;
        final failures = <String>[];

        for (var day = 0; day < 731; day++) {
          final date = DateTime.utc(2026, 11, 13 + day);
          final generated = generateDailyTallTales(level, date);
          final puzzle = generated.puzzle;
          final solution = generated.solution;
          final statements = puzzle.statements;
          final truthCount = solution.marks
              .where((mark) => mark == TallTalesMark.truth)
              .length;

          final problems = [
            if (puzzle.fisherCount != config.fishers)
              '${puzzle.fisherCount} fishers',
            if (truthCount < 2 || truthCount > config.fishers - 2)
              '$truthCount truth-tellers',
            if (!checkTallTales(puzzle, solution).isSolved)
              'a solution that breaks a statement',
            if (solveTallTales(puzzle) case final solutions
                when solutions.length != 1 || solutions.single != solution)
              '${solutions.length} solutions',
            if (!config.accepts(gradeTallTales(puzzle)))
              'a grade outside the level',
            if (statements.where((s) => s.claim.isAboutSpeaker).length > 2)
              'too many statements about the speaker',
            if (statements.where((s) => s.claim.isCount).length > 2)
              'too many counts',
            if (statements.toSet().length != statements.length)
              'a statement made twice',
            if (generated.attempts > attemptCeiling)
              '${generated.attempts} attempts',
          ];
          if (problems.isNotEmpty) {
            failures.add(
              '${generated.seedKey} has ${problems.join(', ')}:\n'
              '${formatTallTales(puzzle, solution)}',
            );
          }
        }

        expect(failures, isEmpty, reason: failures.join('\n'));
      });
    }
  });

  group('TallTalesLevel', () {
    test('makes hard puzzles larger and harder than normal ones', () {
      final normal = TallTalesLevel.normal.config;
      final hard = TallTalesLevel.hard.config;

      expect(hard.fishers, greaterThan(normal.fishers));
      expect(hard.minReasoning.index, greaterThan(normal.maxReasoning.index));
      expect(hard.minSuppositions, greaterThan(0));
    });

    test('gives normal puzzles links to find and fishers to think about', () {
      final normal = TallTalesLevel.normal.config;

      expect(normal.minReasoning, TallTalesReasoning.advanced);
      expect(normal.minOpenAfterBasic, greaterThan(0));
    });
  });

  group('generateTallTales', () {
    test('builds puzzles of a custom size and grade', () {
      const config = TallTalesConfig(
        fishers: 5,
        minReasoning: TallTalesReasoning.lookahead,
      );

      for (final key in ['small:1', 'small:2', 'small:3']) {
        final generated = generateTallTales(key, config);

        expect(generated.puzzle.fisherCount, 5);
        expect(generated.grade.reasoning, TallTalesReasoning.lookahead);
        expect(solveTallTales(generated.puzzle), [generated.solution]);
      }
    });

    test('counts its attempts', () {
      final generated = generateTallTales(
        'key',
        TallTalesLevel.normal.config,
      );

      expect(generated.attempts, greaterThanOrEqualTo(1));
    });

    test('never repeats a count in other words', () {
      for (var index = 0; index < 200; index++) {
        final generated = generateTallTales(
          'counts:$index',
          const TallTalesConfig(fishers: 8),
        );
        final truthCounts = [
          for (final statement in generated.puzzle.statements)
            if (statement.claim == TallTalesClaim.countTruthful)
              statement.count
            else if (statement.claim == TallTalesClaim.countTallTales)
              8 - statement.count,
        ];

        expect(
          truthCounts.toSet(),
          hasLength(truthCounts.length),
          reason: formatTallTales(generated.puzzle),
        );
      }
    });

    group('rejects', () {
      final cases = {
        'too few fishers for two of each kind': const TallTalesConfig(
          fishers: 3,
        ),
        'more fishers than names': const TallTalesConfig(fishers: 9),
        'puzzles that need search': const TallTalesConfig(
          fishers: 6,
          maxReasoning: TallTalesReasoning.search,
        ),
        'a reasoning range that is empty': const TallTalesConfig(
          fishers: 6,
          minReasoning: TallTalesReasoning.lookahead,
          maxReasoning: TallTalesReasoning.advanced,
        ),
      };

      for (final MapEntry(key: description, value: config) in cases.entries) {
        test(description, () {
          expect(() => generateTallTales('key', config), throwsArgumentError);
        });
      }
    });
  });

  // These puzzles, written with their solutions, pin down the exact output
  // of the generator, so a change that would alter an existing daily puzzle
  // cannot slip through unnoticed.
  group('snapshot', () {
    final snapshots = {
      (TallTalesLevel.normal, DateTime(2026, 11, 13)): '''
- Alva: Bo and Ebba are not alike.
- Bo: Cajsa and Ebba are not alike.
- Cajsa: Ebba tells the truth.
+ Dag: At least one of Bo and Greta tells the truth.
- Ebba: Exactly one of Alva, Bo and Cajsa tells the truth.
+ Frej: If Bo tells the truth, so does Alva.
+ Greta: Frej tells the truth.
''',
      (TallTalesLevel.normal, DateTime(2028, 2, 29)): '''
+ Alva: Cajsa and Frej are not alike.
- Bo: Alva and Frej are not alike.
- Cajsa: Ebba tells tall tales.
+ Dag: At least one of Ebba and Greta tells the truth.
+ Ebba: Exactly four of us tell the truth.
+ Frej: Alva tells the truth.
- Greta: Alva tells tall tales.
''',
      (TallTalesLevel.hard, DateTime(2026, 11, 13)): '''
- Alva: Bo and Hugo both tell the truth.
+ Bo: Exactly one of Dag, Ebba and Frej tells the truth.
- Cajsa: Alva and Bo are alike.
- Dag: Bo and Greta are alike.
+ Ebba: Exactly six of us tell tall tales.
- Frej: Exactly six of us tell the truth.
- Greta: Cajsa and Dag both tell the truth.
- Hugo: Bo and Frej are alike.
''',
      (TallTalesLevel.hard, DateTime(2028, 2, 29)): '''
- Alva: Frej and Greta both tell tall tales.
+ Bo: At least one of Alva and Dag tells the truth.
+ Cajsa: Exactly one of Alva, Bo and Greta tells the truth.
+ Dag: Exactly two of us tell tall tales.
+ Ebba: Frej and Hugo are alike.
+ Frej: At least one of Bo and Cajsa tells the truth.
- Greta: Cajsa and Ebba are not alike.
+ Hugo: Dag and Greta are not alike.
''',
    };

    for (final MapEntry(key: (level, date), value: expected)
        in snapshots.entries) {
      final key = tallTalesDailySeedKey(level, date);

      test(key, () {
        final generated = generateDailyTallTales(level, date);

        expect(
          formatTallTales(generated.puzzle, generated.solution),
          expected,
          reason:
              'The generator now builds a different puzzle for $key. If the '
              'change is intentional, increase tallTalesGeneratorVersion so '
              'saved games never refer to a puzzle that has silently '
              'changed, then update these snapshots.',
        );
      });
    }
  });
}
