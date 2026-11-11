import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_rules.dart';
import 'package:klura/puzzles/bridges/logic/bridges_solver.dart';
import 'package:klura/puzzles/bridges/logic/bridges_text.dart';
import 'package:test/test.dart';

void main() {
  group('daily puzzle', () {
    test('uses a seed key for each level and the local date', () {
      final date = DateTime(2026, 11, 11, 23, 30);

      expect(
        bridgesDailySeedKey(BridgesLevel.normal, date),
        'bridges-normal:v2:2026-11-11',
      );
      expect(
        bridgesDailySeedKey(BridgesLevel.hard, date),
        'bridges-hard:v2:2026-11-11',
      );
    });

    test('is generated from its seed key and level', () {
      final generated = generateDailyBridges(
        BridgesLevel.hard,
        DateTime(2026, 11, 11),
      );

      expect(generated.seedKey, 'bridges-hard:v2:2026-11-11');
      expect(
        generated.puzzle,
        generateBridges(generated.seedKey, BridgesLevel.hard.config).puzzle,
      );
    });

    test('is the same every time for the same date', () {
      final date = DateTime(2027, 3, 2);

      final first = generateDailyBridges(BridgesLevel.normal, date);
      final second = generateDailyBridges(BridgesLevel.normal, date);

      expect(second.puzzle, first.puzzle);
      expect(second.solution, first.solution);
      expect(second.attempts, first.attempts);
    });

    // Every daily puzzle for about two years, from the first day Klura
    // offers. Each must be valid, unique and suit its level. The attempt
    // ceiling keeps generation cheap: attempts are deterministic, unlike
    // timings, and the worst day needed fewer than 100 when it was set.
    for (final level in BridgesLevel.values) {
      test('is valid, unique and ${level.name} for every day of two years', () {
        const attemptCeiling = 200;
        final config = level.config;
        final failures = <String>[];

        for (var day = 0; day < 731; day++) {
          final date = DateTime.utc(2026, 11, 11 + day);
          final generated = generateDailyBridges(level, date);
          final puzzle = generated.puzzle;
          final check = checkBridges(puzzle, generated.solution);
          final solutions = solveBridges(puzzle);

          final problems = [
            if (puzzle.width != config.width || puzzle.height != config.height)
              'size ${puzzle.width}x${puzzle.height}',
            if (puzzle.islands.length != config.islandCount)
              '${puzzle.islands.length} islands',
            if (check.crossings.isNotEmpty) 'crossing bridges',
            if (!check.isSolved) 'a solution that breaks the rules',
            if (solutions.length != 1) '${solutions.length} solutions',
            if (solutions.isNotEmpty && solutions.first != generated.solution)
              'a different solution from the solver',
            if (!config.accepts(gradeBridges(puzzle)))
              'a grade outside the level',
            if (generated.attempts > attemptCeiling)
              '${generated.attempts} attempts',
          ];
          if (problems.isNotEmpty) {
            failures.add(
              '${generated.seedKey} has ${problems.join(', ')}:\n'
              '${formatBridges(puzzle, generated.solution)}',
            );
          }
        }

        expect(failures, isEmpty, reason: failures.join('\n'));
      });
    }
  });

  group('BridgesLevel', () {
    test('makes hard puzzles larger and harder than normal ones', () {
      final normal = BridgesLevel.normal.config;
      final hard = BridgesLevel.hard.config;

      expect(hard.islandCount, greaterThan(normal.islandCount));
      expect(hard.minReasoning.index, greaterThan(normal.maxReasoning.index));
      expect(hard.minOpenAfterBasic, greaterThan(0));
    });
  });

  group('generateBridges', () {
    test('builds puzzles of a custom size and grade', () {
      const config = BridgesConfig(
        width: 6,
        height: 7,
        islandCount: 10,
        minReasoning: BridgesReasoning.advanced,
      );

      for (final key in ['small:1', 'small:2', 'small:3']) {
        final generated = generateBridges(key, config);

        expect(generated.puzzle.width, 6);
        expect(generated.puzzle.height, 7);
        expect(generated.puzzle.islands, hasLength(10));
        expect(
          generated.grade.reasoning.index,
          greaterThanOrEqualTo(BridgesReasoning.advanced.index),
        );
        expect(solveBridges(generated.puzzle), [generated.solution]);
      }
    });

    test('counts its attempts', () {
      final generated = generateBridges('key', BridgesLevel.normal.config);

      expect(generated.attempts, greaterThanOrEqualTo(1));
    });

    group('rejects', () {
      final cases = {
        'fewer than two islands': const BridgesConfig(
          width: 5,
          height: 5,
          islandCount: 1,
        ),
        'more islands than fit apart': const BridgesConfig(
          width: 3,
          height: 3,
          islandCount: 6,
        ),
        'an empty grid': const BridgesConfig(
          width: 0,
          height: 5,
          islandCount: 2,
        ),
        'puzzles that need search': const BridgesConfig(
          width: 5,
          height: 5,
          islandCount: 4,
          maxReasoning: BridgesReasoning.search,
        ),
        'a reasoning range that is empty': const BridgesConfig(
          width: 5,
          height: 5,
          islandCount: 4,
          minReasoning: BridgesReasoning.lookahead,
          maxReasoning: BridgesReasoning.advanced,
        ),
      };

      for (final MapEntry(key: description, value: config) in cases.entries) {
        test(description, () {
          expect(() => generateBridges('key', config), throwsArgumentError);
        });
      }
    });
  });

  // These boards, drawn with their solutions, pin down the exact output of
  // the generator, so a change that would alter an existing daily puzzle
  // cannot slip through unnoticed.
  group('snapshot', () {
    final snapshots = {
      (BridgesLevel.normal, DateTime(2026, 11, 11)): '''
3==5==2.2.
|1.|....║1
||.|1-2-4|
2|.|....||
|4=7=4==4|
2|.║3-1.|3
|3.3║...|║
2║.|3-3=3║
|2.|.....║
1..3=4=3-3
''',
      (BridgesLevel.normal, DateTime(2028, 2, 29)): '''
3=3-2--2-2
|.......1|
|2-3-3=3||
2|.|1-3|||
||.3-1║1|3
|1.|..║.|║
2--5--4.|2
...║2.|.|.
.1-3║.|.|.
2=4=6=4-2.
''',
      (BridgesLevel.hard, DateTime(2026, 11, 11)): '''
3==3.2-1.2
|.2|.|...║
3.║|.4---5
║.║1.║1-2║
3.6==6-1|4
|.║..|1-3║
|.3..3..|3
|.|..║..||
2.|2=5..2|
|.2-1|..|3
2----3--2║
.1--2-2--3
''',
      (BridgesLevel.hard, DateTime(2028, 2, 29)): '''
3-2-3-2--1
║...|.....
4--1|2-2-2
|...||...|
|2--2|.1-4
3|1--4==2║
║3==2....║
4--3=4=3-5
|........║
|.1-3==3-4
3==3--2-1|
.2==3----2
''',
    };

    for (final MapEntry(key: (level, date), value: expected)
        in snapshots.entries) {
      final key = bridgesDailySeedKey(level, date);

      test(key, () {
        final generated = generateDailyBridges(level, date);

        expect(
          formatBridges(generated.puzzle, generated.solution),
          expected,
          reason:
              'The generator now builds a different puzzle for $key. If the '
              'change is intentional, increase bridgesGeneratorVersion so '
              'saved games never refer to a puzzle that has silently '
              'changed, then update these snapshots.',
        );
      });
    }
  });
}
