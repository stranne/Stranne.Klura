import 'package:klura/puzzles/tall_tales/logic/tall_tales_marks.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_puzzle.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_text.dart';
import 'package:test/test.dart';

void main() {
  const marked = '''
+ Alva: Bo tells the truth.
. Bo: Cajsa and I are not alike.
- Cajsa: At least one of Alva and me tells tall tales.
''';

  test('reads each fisher, their mark and their statement', () {
    final (puzzle, marks) = parseTallTales(marked);

    expect(
      puzzle,
      TallTalesPuzzle([
        TallTalesStatement(TallTalesClaim.truthful, const [1]),
        TallTalesStatement(TallTalesClaim.notAlikeMe, const [2]),
        TallTalesStatement(TallTalesClaim.eitherTallTalesMe, const [0]),
      ]),
    );
    expect(
      marks,
      TallTalesMarks(const [
        TallTalesMark.truth,
        null,
        TallTalesMark.tallTales,
      ]),
    );
  });

  test('writes a puzzle with its marks as it reads it', () {
    final (puzzle, marks) = parseTallTales(marked);

    expect(formatTallTales(puzzle, marks), marked);
  });

  test('leaves the marks out of a puzzle without them', () {
    final (puzzle, marks) = parseTallTales('''
      Alva: Exactly two of us tell the truth.

      Bo: If Cajsa tells the truth, so does Alva.
      Cajsa: Alva and Bo are alike.
''');

    expect(marks, TallTalesMarks.empty(3));
    expect(formatTallTales(puzzle), '''
Alva: Exactly two of us tell the truth.
Bo: If Cajsa tells the truth, so does Alva.
Cajsa: Alva and Bo are alike.
''');
  });

  group('rejects', () {
    final cases = {
      'a line without a statement': '''
Alva: Bo tells the truth.
Bo
Cajsa: Alva tells the truth.
''',
      'fishers out of order': '''
Bo: Alva tells the truth.
Alva: Bo tells the truth.
Cajsa: Alva tells the truth.
''',
      'a statement no one can make': '''
Alva: Bo tells the truth.
Bo: Alva tells fibs.
Cajsa: Alva tells the truth.
''',
      'a fisher named out of order in a symmetric claim': '''
Alva: Cajsa and Bo are alike.
Bo: Alva tells the truth.
Cajsa: Alva tells the truth.
''',
      'a statement that names its speaker': '''
Alva: Alva tells the truth.
Bo: Alva tells the truth.
Cajsa: Alva tells the truth.
''',
      'a fisher who is not on the jetty': '''
Alva: Dag tells the truth.
Bo: Alva tells the truth.
Cajsa: Alva tells the truth.
''',
      'an unknown mark': '''
* Alva: Bo tells the truth.
Bo: Alva tells the truth.
Cajsa: Alva tells the truth.
''',
    };

    for (final MapEntry(key: description, value: text) in cases.entries) {
      test(description, () {
        expect(() => parseTallTales(text), throwsFormatException);
      });
    }

    test('too few fishers', () {
      expect(
        () => parseTallTales('Alva: Bo tells the truth.\n'),
        throwsArgumentError,
      );
    });

    test('marks for another number of fishers', () {
      final (puzzle, _) = parseTallTales(marked);

      expect(
        () => formatTallTales(puzzle, TallTalesMarks.empty(4)),
        throwsArgumentError,
      );
    });
  });
}
