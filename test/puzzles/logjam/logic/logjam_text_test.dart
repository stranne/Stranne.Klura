import 'package:klura/puzzles/logjam/logic/logjam_board.dart';
import 'package:klura/puzzles/logjam/logic/logjam_text.dart';
import 'package:test/test.dart';

void main() {
  test('draws the marked piece, the other pieces and the exit', () {
    final board = LogjamBoard(
      width: 4,
      height: 3,
      pieces: const [
        LogjamPiece.horizontal(1, 1, 2),
        LogjamPiece.vertical(0, 0, 2),
        LogjamPiece.horizontal(0, 2, 3),
      ],
    );

    expect(formatLogjam(board), '''
A...
A**.>
BBB.
''');
  });

  test('reads a board back as it was drawn', () {
    const text = '''
AAB..C
..B..C
D**E.C>
D..EFF
GGHE..
..H.II
''';

    final board = parseLogjam(text);

    expect(board.width, 6);
    expect(board.height, 6);
    expect(board.pieces, hasLength(10));
    expect(board.marked, const LogjamPiece.horizontal(1, 2, 2));
    expect(board.pieces[5], const LogjamPiece.vertical(3, 2, 3));
    expect(formatLogjam(board), text);
  });

  test('keeps the order of the pieces by their letters', () {
    final board = parseLogjam('''
B.
B.
A.
A.
**>
''');

    expect(board.pieces[1], const LogjamPiece.vertical(0, 2, 2));
    expect(board.pieces[2], const LogjamPiece.vertical(0, 0, 2));
  });

  test('ignores blank lines around the board and spaces around rows', () {
    final board = parseLogjam('''

    A..
    A**>

''');

    expect(formatLogjam(board), '''
A..
A**>
''');
  });

  test('refuses a board with more pieces than letters', () {
    final board = LogjamBoard(
      width: 12,
      height: 12,
      pieces: [
        const LogjamPiece.horizontal(0, 0, 2),
        for (var x = 0; x < 12; x++) LogjamPiece.vertical(x, 1, 2),
        for (var x = 0; x < 12; x++) LogjamPiece.vertical(x, 3, 2),
        for (var x = 0; x < 3; x++) LogjamPiece.vertical(x, 5, 2),
      ],
    );

    expect(() => formatLogjam(board), throwsArgumentError);
  });

  group('rejects text', () {
    final cases = {
      'that is empty': '\n\n',
      'without an exit': '''
A..
A**
''',
      'with two exits': '''
A..>
A**>
''',
      'with the exit on another row': '''
A..>
A**
''',
      'with rows of different lengths': '''
A...
A**>
''',
      'with an unknown cell': '''
A.x
A**>
''',
      'without the marked piece': '''
A..
A..>
''',
      'with a bent piece': '''
AA.
A**>
''',
      'with a piece of one cell': '''
A..
B**>
''',
      'with a piece of four cells': '''
A...
A**.>
A...
A...
''',
      'with a gap in the letters': '''
B..
B**>
''',
      'with a lowercase letter': '''
a..
a**>
''',
    };

    for (final MapEntry(key: description, value: text) in cases.entries) {
      test(description, () {
        expect(() => parseLogjam(text), throwsFormatException);
      });
    }

    test('with a vertical marked piece', () {
      expect(
        () => parseLogjam('''
*..>
*..
'''),
        throwsArgumentError,
      );
    });
  });
}
