import 'package:klura/puzzles/tall_tales/logic/tall_tales_marks.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_rules.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_text.dart';
import 'package:test/test.dart';

void main() {
  /// The status of each statement of [text], drawn as `o` for open, `+` for
  /// fits and `x` for broken.
  String statusesOf(String text) {
    final (puzzle, marks) = parseTallTales(text);
    return checkTallTales(puzzle, marks).statuses
        .map(
          (status) => switch (status) {
            StatementStatus.open => 'o',
            StatementStatus.fits => '+',
            StatementStatus.broken => 'x',
          },
        )
        .join();
  }

  test('leaves every statement open without marks', () {
    expect(
      statusesOf('''
Alva: Bo and I are not alike.
Bo: Cajsa tells the truth.
Cajsa: Alva tells tall tales.
'''),
      'ooo',
    );
  });

  test('judges a statement once everyone it depends on is marked', () {
    expect(
      statusesOf('''
+ Alva: Bo and I are not alike.
- Bo: Cajsa tells the truth.
. Cajsa: Alva tells tall tales.
'''),
      '+oo',
    );
  });

  test('breaks a statement that is false from a truth-teller', () {
    expect(
      statusesOf('''
+ Alva: Bo and I are not alike.
+ Bo: Cajsa tells the truth.
. Cajsa: Alva tells tall tales.
'''),
      'xoo',
    );
  });

  test('breaks a statement that is true from a teller of tall tales, or false from a truth-teller', () {
    expect(
      statusesOf('''
- Alva: Bo and I are not alike.
+ Bo: Cajsa tells the truth.
- Cajsa: Alva tells tall tales.
'''),
      'xxx',
    );
  });

  test('leaves a statement open even when its marks already break it', () {
    // Cajsa's count of two truth-tellers is already broken by three, but
    // Dag is unmarked.
    expect(
      statusesOf('''
+ Alva: Bo tells the truth.
+ Bo: Alva tells the truth.
+ Cajsa: Exactly two of us tell the truth.
. Dag: Alva tells the truth.
'''),
      '++oo',
    );
  });

  test('is solved when every statement fits', () {
    final (puzzle, marks) = parseTallTales('''
+ Alva: Bo and I are not alike.
- Bo: Cajsa tells the truth.
- Cajsa: Alva tells tall tales.
''');

    final check = checkTallTales(puzzle, marks);

    expect(check.isSolved, isTrue);
    expect(check.broken, isEmpty);
  });

  test('lists the broken statements in the order the fishers sit', () {
    final (puzzle, marks) = parseTallTales('''
- Alva: Bo and I are not alike.
+ Bo: Cajsa tells the truth.
- Cajsa: Alva tells tall tales.
''');

    final check = checkTallTales(puzzle, marks);

    expect(check.broken, [0, 1, 2]);
    expect(check.isSolved, isFalse);
  });

  test('rejects marks for another number of fishers', () {
    final (puzzle, _) = parseTallTales('''
Alva: Bo and I are not alike.
Bo: Cajsa tells the truth.
Cajsa: Alva tells tall tales.
''');

    expect(
      () => checkTallTales(puzzle, TallTalesMarks.empty(4)),
      throwsArgumentError,
    );
  });
}
