import 'package:klura/puzzles/tall_tales/logic/tall_tales_puzzle.dart';
import 'package:test/test.dart';

void main() {
  // Fishers 0, 1 and 2, with the speaker at 0 and those named at 1 and 2.
  // Each case lists the bit sets of truth-tellers that make it true, among
  // the fishers the claim depends on.
  group('TallTalesStatement.isTrue', () {
    const alva = 1;
    const bo = 2;
    const cajsa = 4;
    final cases = <TallTalesStatement, Set<int>>{
      TallTalesStatement(TallTalesClaim.truthful, const [1]): {bo},
      TallTalesStatement(TallTalesClaim.tallTales, const [1]): {0},
      TallTalesStatement(TallTalesClaim.alike, const [1, 2]): {0, bo | cajsa},
      TallTalesStatement(TallTalesClaim.notAlike, const [1, 2]): {bo, cajsa},
      TallTalesStatement(TallTalesClaim.bothTruthful, const [1, 2]): {
        bo | cajsa,
      },
      TallTalesStatement(TallTalesClaim.bothTallTales, const [1, 2]): {0},
      TallTalesStatement(TallTalesClaim.eitherTruthful, const [1, 2]): {
        bo,
        cajsa,
        bo | cajsa,
      },
      TallTalesStatement(TallTalesClaim.ifTruthful, const [1, 2]): {
        0,
        cajsa,
        bo | cajsa,
      },
      TallTalesStatement(TallTalesClaim.alikeMe, const [1]): {0, alva | bo},
      TallTalesStatement(TallTalesClaim.notAlikeMe, const [1]): {alva, bo},
      TallTalesStatement(TallTalesClaim.bothTallTalesMe, const [1]): {0},
      TallTalesStatement(TallTalesClaim.eitherTallTalesMe, const [1]): {
        0,
        alva,
        bo,
      },
    };

    for (final MapEntry(key: statement, value: trueFor) in cases.entries) {
      test('${statement.claim.name} holds exactly when it should', () {
        final dependsOn = statement.claim.isAboutSpeaker
            ? alva | bo
            : statement.named.length == 1
            ? bo
            : bo | cajsa;
        for (var truthful = 0; truthful < 8; truthful++) {
          final relevant = truthful & dependsOn;
          expect(
            statement.isTrue(0, truthful, 3),
            trueFor.contains(relevant),
            reason: 'truthful $truthful',
          );
        }
      });
    }

    test('oneOfThreeTruthful holds for exactly one of the three', () {
      final statement = TallTalesStatement(
        TallTalesClaim.oneOfThreeTruthful,
        const [1, 2, 3],
      );

      expect(statement.isTrue(0, 0x2, 4), isTrue);
      expect(statement.isTrue(0, 0x8, 4), isTrue);
      expect(statement.isTrue(0, 0x9, 4), isTrue);
      expect(statement.isTrue(0, 0x0, 4), isFalse);
      expect(statement.isTrue(0, 0x6, 4), isFalse);
      expect(statement.isTrue(0, 0xE, 4), isFalse);
    });

    test('counts every fisher, the speaker included', () {
      final truthful = TallTalesStatement.count(
        TallTalesClaim.countTruthful,
        2,
      );
      final tallTales = TallTalesStatement.count(
        TallTalesClaim.countTallTales,
        2,
      );

      expect(truthful.isTrue(0, 0x3, 4), isTrue);
      expect(truthful.isTrue(0, 0x7, 4), isFalse);
      expect(tallTales.isTrue(0, 0x3, 4), isTrue);
      expect(tallTales.isTrue(0, 0x1, 4), isFalse);
    });
  });

  group('TallTalesStatement', () {
    test('rejects the wrong number of fishers or a fisher twice', () {
      expect(
        () => TallTalesStatement(TallTalesClaim.truthful, const [1, 2]),
        throwsArgumentError,
      );
      expect(
        () => TallTalesStatement(TallTalesClaim.alike, const [1]),
        throwsArgumentError,
      );
      expect(
        () => TallTalesStatement(TallTalesClaim.alike, const [1, 1]),
        throwsArgumentError,
      );
    });

    test('keeps counts apart from claims that name fishers', () {
      expect(
        () => TallTalesStatement(TallTalesClaim.countTruthful, const []),
        throwsArgumentError,
      );
      expect(
        () => TallTalesStatement.count(TallTalesClaim.truthful, 1),
        throwsArgumentError,
      );
      expect(
        () => TallTalesStatement.count(TallTalesClaim.countTruthful, 0),
        throwsArgumentError,
      );
    });

    test('is equal to a statement of the same claim and fishers', () {
      final statement = TallTalesStatement(TallTalesClaim.ifTruthful, const [
        1,
        2,
      ]);

      expect(
        statement,
        TallTalesStatement(TallTalesClaim.ifTruthful, const [1, 2]),
      );
      expect(
        statement.hashCode,
        TallTalesStatement(TallTalesClaim.ifTruthful, const [1, 2]).hashCode,
      );
      expect(
        statement,
        isNot(TallTalesStatement(TallTalesClaim.ifTruthful, const [2, 1])),
      );
      expect(
        TallTalesStatement.count(TallTalesClaim.countTruthful, 2),
        isNot(TallTalesStatement.count(TallTalesClaim.countTallTales, 2)),
      );
    });
  });

  group('TallTalesPuzzle', () {
    // Alva: Bo tells the truth. Bo: Cajsa and I are not alike. Cajsa:
    // Exactly one of us tells the truth.
    final puzzle = TallTalesPuzzle([
      TallTalesStatement(TallTalesClaim.truthful, const [1]),
      TallTalesStatement(TallTalesClaim.notAlikeMe, const [2]),
      TallTalesStatement.count(TallTalesClaim.countTruthful, 1),
    ]);

    test('needs three to eight fishers', () {
      final statement = TallTalesStatement(TallTalesClaim.truthful, const [1]);

      expect(
        () => TallTalesPuzzle([
          statement,
          TallTalesStatement(TallTalesClaim.truthful, const [0]),
        ]),
        throwsArgumentError,
      );
      expect(TallTalesPuzzle.maxFishers, 8);
      expect(
        () => TallTalesPuzzle([
          for (var fisher = 0; fisher < 9; fisher++)
            TallTalesStatement(TallTalesClaim.truthful, [(fisher + 1) % 9]),
        ]),
        throwsArgumentError,
      );
    });

    test('rejects a statement that names its speaker or a stranger', () {
      final other = TallTalesStatement(TallTalesClaim.truthful, const [0]);

      expect(
        () => TallTalesPuzzle([
          TallTalesStatement(TallTalesClaim.truthful, const [0]),
          other,
          other,
        ]),
        throwsArgumentError,
      );
      expect(
        () => TallTalesPuzzle([
          TallTalesStatement(TallTalesClaim.truthful, const [3]),
          other,
          other,
        ]),
        throwsArgumentError,
      );
    });

    test('rejects a count of every fisher', () {
      final other = TallTalesStatement(TallTalesClaim.truthful, const [0]);

      expect(
        () => TallTalesPuzzle([
          TallTalesStatement.count(TallTalesClaim.countTallTales, 3),
          other,
          other,
        ]),
        throwsArgumentError,
      );
    });

    test('judges each statement against its speaker', () {
      // Only Bo tells the truth: Alva's statement is true from a teller of
      // tall tales, Bo is unlike Cajsa as Bo says, and Cajsa's count of one
      // is true from a teller of tall tales.
      expect(puzzle.fitsSpeaker(0, 0x2), isFalse);
      expect(puzzle.fitsSpeaker(1, 0x2), isTrue);
      expect(puzzle.fitsSpeaker(2, 0x2), isFalse);
      expect(puzzle.fits(0x2), isFalse);
      // Alva and Bo tell the truth and Cajsa tall tales, with a false count.
      expect(puzzle.fits(0x3), isTrue);
    });

    test('depends on the speaker and the fishers named', () {
      expect(puzzle.dependsOn(0), [0, 1]);
      expect(puzzle.dependsOn(1), [1, 2]);
      expect(puzzle.dependsOn(2), [0, 1, 2]);
    });

    test('is equal to a puzzle of the same statements', () {
      final same = TallTalesPuzzle([...puzzle.statements]);

      expect(same, puzzle);
      expect(same.hashCode, puzzle.hashCode);
      expect(
        TallTalesPuzzle([...puzzle.statements.reversed]),
        isNot(puzzle),
      );
    });
  });

  group('possibleStatements', () {
    test('never names the speaker and names symmetric claims in order', () {
      final statements = possibleStatements(2, 5);

      for (final statement in statements) {
        expect(statement.named, isNot(contains(2)));
        if (statement.claim.isSymmetric) {
          expect(statement.named, orderedEquals([...statement.named]..sort()));
        }
      }
      expect(statements.toSet(), hasLength(statements.length));
    });

    test('offers each claim with every choice of fishers or count', () {
      final statements = possibleStatements(0, 5);
      int countOf(TallTalesClaim claim) =>
          statements.where((statement) => statement.claim == claim).length;

      expect(countOf(TallTalesClaim.truthful), 4);
      expect(countOf(TallTalesClaim.alikeMe), 4);
      expect(countOf(TallTalesClaim.alike), 6);
      expect(countOf(TallTalesClaim.ifTruthful), 12);
      expect(countOf(TallTalesClaim.oneOfThreeTruthful), 4);
      expect(countOf(TallTalesClaim.countTruthful), 4);
      expect(countOf(TallTalesClaim.countTallTales), 4);
    });

    test('makes statements every puzzle accepts', () {
      for (final statement in possibleStatements(3, 8)) {
        final others = [
          for (var fisher = 0; fisher < 8; fisher++)
            if (fisher == 3)
              statement
            else
              TallTalesStatement(TallTalesClaim.truthful, const [3]),
        ];
        expect(() => TallTalesPuzzle(others), returnsNormally);
      }
    });
  });
}
