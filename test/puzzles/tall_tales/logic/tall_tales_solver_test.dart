import 'package:klura/core/seeded_random.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_marks.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_puzzle.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_solver.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_text.dart';
import 'package:test/test.dart';

void main() {
  // Alva's statement settles Bo, and then each statement the next fisher.
  const basic = '''
+ Alva: Bo and I are not alike.
- Bo: Cajsa tells the truth.
- Cajsa: Alva tells tall tales.
''';

  // No statement settles anyone on its own, but Alva's makes Alva and Bo
  // alike, which makes Cajsa's false.
  const advanced = '''
- Alva: Bo tells the truth.
- Bo: Cajsa tells the truth.
- Cajsa: Alva and Bo are not alike.
''';

  // Links settle no one either, but supposing that Alva tells tall tales
  // breaks a statement.
  const lookahead = '''
+ Alva: Bo and Cajsa both tell tall tales.
- Bo: Alva and Cajsa are alike.
- Cajsa: If Dag tells the truth, so does Bo.
+ Dag: If Bo tells the truth, so does Alva.
''';

  const twoSuppositions = '''
- Alva: Bo and Cajsa both tell tall tales.
- Bo: Cajsa and Ebba both tell tall tales.
+ Cajsa: Dag and Ebba are not alike.
- Dag: If Cajsa tells the truth, so does Bo.
+ Ebba: Bo and Cajsa are not alike.
''';

  // Everyone vouches for the next fisher, so all may tell the truth or all
  // tall tales.
  const twoSolutions = '''
Alva: Bo tells the truth.
Bo: Cajsa tells the truth.
Cajsa: Alva tells the truth.
''';

  // Alva's statement makes Alva a teller of tall tales and Bo a
  // truth-teller, who then says Alva tells the truth.
  const noSolution = '''
Alva: Bo and I both tell tall tales.
Bo: Alva tells the truth.
Cajsa: Alva tells the truth.
''';

  group('solveTallTales', () {
    for (final text in [basic, advanced, lookahead, twoSuppositions]) {
      test('finds the single solution of ${text.split('\n').first}', () {
        final (puzzle, solution) = parseTallTales(text);

        expect(solveTallTales(puzzle), [solution]);
      });
    }

    test('finds up to the limit of solutions', () {
      final (puzzle, _) = parseTallTales(twoSolutions);

      expect(solveTallTales(puzzle), [
        TallTalesMarks.fromTruthful(3, 0x0),
        TallTalesMarks.fromTruthful(3, 0x7),
      ]);
      expect(solveTallTales(puzzle, limit: 1), hasLength(1));
      expect(() => solveTallTales(puzzle, limit: 0), throwsRangeError);
    });

    test('finds none for a puzzle no marking fits', () {
      final (puzzle, _) = parseTallTales(noSolution);

      expect(solveTallTales(puzzle), isEmpty);
    });
  });

  group('gradeTallTales', () {
    final cases = {
      basic: (TallTalesReasoning.basic, 0, 0),
      advanced: (TallTalesReasoning.advanced, 0, 3),
      lookahead: (TallTalesReasoning.lookahead, 1, 4),
      twoSuppositions: (TallTalesReasoning.lookahead, 2, 5),
      twoSolutions: (TallTalesReasoning.search, 0, 3),
      noSolution: (TallTalesReasoning.search, 0, 3),
    };

    for (final MapEntry(key: text, value: (reasoning, suppositions, open))
        in cases.entries) {
      test('grades ${text.split('\n').first} as ${reasoning.name}', () {
        final (puzzle, _) = parseTallTales(text);

        final grade = gradeTallTales(puzzle);

        expect(grade.reasoning, reasoning);
        expect(grade.suppositions, suppositions);
        expect(grade.openAfterBasic, open);
      });
    }

    // Puzzles of random statements, with any number of solutions, test that
    // every deduction holds: a grade below search must mean exactly one
    // solution.
    test('proves a single solution whenever it solves a puzzle', () {
      var graded = 0;
      for (var index = 0; index < 400; index++) {
        final random = SeededRandom.fromKey('grade-check#$index');
        final fishers = 3 + random.nextInt(6);
        final puzzle = TallTalesPuzzle([
          for (var speaker = 0; speaker < fishers; speaker++)
            _pick(possibleStatements(speaker, fishers), random),
        ]);

        final grade = gradeTallTales(puzzle);
        final solutions = solveTallTales(puzzle);

        if (grade.reasoning != TallTalesReasoning.search) {
          graded++;
          expect(solutions, hasLength(1), reason: formatTallTales(puzzle));
        }
      }
      expect(graded, greaterThan(50));
    });
  });
}

T _pick<T>(List<T> items, SeededRandom random) =>
    items[random.nextInt(items.length)];
