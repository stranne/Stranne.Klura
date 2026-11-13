import 'package:klura/puzzles/tall_tales/logic/tall_tales_puzzle.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_wording.dart';
import 'package:test/test.dart';

void main() {
  group('statementText', () {
    final cases = {
      TallTalesStatement(TallTalesClaim.truthful, const [1]):
          'Bo tells the truth.',
      TallTalesStatement(TallTalesClaim.tallTales, const [1]):
          'Bo tells tall tales.',
      TallTalesStatement(TallTalesClaim.alike, const [1, 3]):
          'Bo and Dag are alike.',
      TallTalesStatement(TallTalesClaim.notAlike, const [1, 3]):
          'Bo and Dag are not alike.',
      TallTalesStatement(TallTalesClaim.bothTruthful, const [1, 3]):
          'Bo and Dag both tell the truth.',
      TallTalesStatement(TallTalesClaim.bothTallTales, const [1, 3]):
          'Bo and Dag both tell tall tales.',
      TallTalesStatement(TallTalesClaim.eitherTruthful, const [1, 3]):
          'At least one of Bo and Dag tells the truth.',
      TallTalesStatement(TallTalesClaim.ifTruthful, const [3, 1]):
          'If Dag tells the truth, so does Bo.',
      TallTalesStatement(TallTalesClaim.oneOfThreeTruthful, const [1, 3, 7]):
          'Exactly one of Bo, Dag and Hugo tells the truth.',
      TallTalesStatement.count(TallTalesClaim.countTruthful, 1):
          'Exactly one of us tells the truth.',
      TallTalesStatement.count(TallTalesClaim.countTruthful, 3):
          'Exactly three of us tell the truth.',
      TallTalesStatement.count(TallTalesClaim.countTallTales, 1):
          'Exactly one of us tells tall tales.',
      TallTalesStatement.count(TallTalesClaim.countTallTales, 7):
          'Exactly seven of us tell tall tales.',
      TallTalesStatement(TallTalesClaim.alikeMe, const [1]):
          'Bo and I are alike.',
      TallTalesStatement(TallTalesClaim.notAlikeMe, const [1]):
          'Bo and I are not alike.',
      TallTalesStatement(TallTalesClaim.bothTallTalesMe, const [1]):
          'Bo and I both tell tall tales.',
      TallTalesStatement(TallTalesClaim.eitherTallTalesMe, const [1]):
          'At least one of Bo and me tells tall tales.',
    };

    test('words every claim', () {
      expect(
        cases.keys.map((statement) => statement.claim).toSet(),
        TallTalesClaim.values.toSet(),
      );
    });

    for (final MapEntry(key: statement, value: text) in cases.entries) {
      test(text, () {
        expect(statementText(statement), text);
      });
    }

    test('gives every statement among eight fishers its own words', () {
      for (var speaker = 0; speaker < 8; speaker++) {
        final texts = possibleStatements(speaker, 8).map(statementText);

        expect(texts.toSet(), hasLength(texts.length));
      }
    });
  });

  group('statementParts', () {
    test('keeps each named fisher apart from the words', () {
      expect(
        statementParts(
          TallTalesStatement(TallTalesClaim.ifTruthful, const [3, 1]),
        ),
        const [
          StatementWords('If '),
          StatementName(3),
          StatementWords(' tells the truth, so does '),
          StatementName(1),
          StatementWords('.'),
        ],
      );
    });

    test('names each fisher once for each time the statement does', () {
      for (final statement in possibleStatements(0, 8)) {
        final named = [
          for (final part in statementParts(statement))
            if (part case StatementName(:final fisher)) fisher,
        ];

        expect(named, statement.named, reason: statementText(statement));
      }
    });

    test('knows the name of each fisher', () {
      expect(const StatementName(0).name, 'Alva');
      expect(const StatementName(7).name, 'Hugo');
    });
  });
}
