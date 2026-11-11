import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_rules.dart';
import 'package:klura/puzzles/bridges/logic/bridges_solver.dart';
import 'package:klura/puzzles/bridges/logic/bridges_text.dart';
import 'package:test/test.dart';

void main() {
  group('daily puzzle', () {
    test('uses the daily seed key for the local date', () {
      final date = DateTime(2026, 11, 11, 23, 30);

      final generated = generateDailyBridges(date);

      expect(bridgesDailySeedKey(date), 'bridges:v1:2026-11-11');
      expect(generated.seedKey, 'bridges:v1:2026-11-11');
      expect(generated.puzzle, generateBridges(generated.seedKey).puzzle);
    });

    test('is the same every time for the same date', () {
      final first = generateDailyBridges(DateTime(2027, 3, 2));
      final second = generateDailyBridges(DateTime(2027, 3, 2));

      expect(second.puzzle, first.puzzle);
      expect(second.solution, first.solution);
      expect(second.attempts, first.attempts);
    });

    // Every daily puzzle for about two years, from the first day Klura
    // offers. Each must be valid, unique and the configured size.
    test('is valid and unique for every day of two years', () {
      final failures = <String>[];
      const config = BridgesConfig.daily;

      for (var day = 0; day < 731; day++) {
        final date = DateTime.utc(2026, 11, 11 + day);
        final generated = generateDailyBridges(date);
        final puzzle = generated.puzzle;
        final board = formatBridges(puzzle, generated.solution);
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
        ];
        if (problems.isNotEmpty) {
          failures.add(
            '${generated.seedKey} has ${problems.join(', ')}:\n$board',
          );
        }
      }

      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  });

  group('generateBridges', () {
    test('builds puzzles of a custom size', () {
      const config = BridgesConfig(width: 5, height: 6, islandCount: 7);

      for (final key in ['small:1', 'small:2', 'small:3']) {
        final generated = generateBridges(key, config: config);

        expect(generated.puzzle.width, 5);
        expect(generated.puzzle.height, 6);
        expect(generated.puzzle.islands, hasLength(7));
        expect(solveBridges(generated.puzzle), [generated.solution]);
      }
    });

    test('counts its attempts', () {
      final generated = generateBridges('bridges:v1:2026-11-11');

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
      };

      for (final MapEntry(key: description, value: config) in cases.entries) {
        test(description, () {
          expect(
            () => generateBridges('key', config: config),
            throwsArgumentError,
          );
        });
      }
    });
  });

  // These boards, drawn with their solutions, pin down the exact output of
  // the generator, so a change that would alter an existing daily puzzle
  // cannot slip through unnoticed.
  group('snapshot', () {
    final snapshots = {
      DateTime(2026, 11, 11): '''
2-3==2.
|2====3
3===4.|
....║.|
2--1║.2
|...║.|
|1--4.2
|...|.|
2---4=3
''',
      DateTime(2027, 6, 21): '''
2-3---3
|.|...║
|2|...║
3║2--1║
║4----5
║|..1.║
4|..|.║
║1..|.║
4=2.2-3
''',
      DateTime(2028, 2, 29): '''
3==6=2.
|..║...
|..║1-2
2..5-2|
|..║.||
|2.║.||
|║.2.|2
|3---2|
3==3--2
''',
    };

    for (final MapEntry(key: date, value: expected) in snapshots.entries) {
      final key = bridgesDailySeedKey(date);

      test(key, () {
        final generated = generateDailyBridges(date);

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
