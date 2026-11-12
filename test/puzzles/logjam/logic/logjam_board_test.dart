import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/logjam/logic/logjam_board.dart';
import 'package:klura/puzzles/logjam/logic/logjam_text.dart';
import 'package:test/test.dart';

void main() {
  group('LogjamPiece', () {
    test('covers its cells along a row', () {
      const piece = LogjamPiece.horizontal(1, 2, 3);

      expect(piece.cells, const [
        Position(1, 2),
        Position(2, 2),
        Position(3, 2),
      ]);
      expect(piece.offset, 1);
      expect(piece.line, 2);
      expect(piece.covers(const Position(3, 2)), isTrue);
      expect(piece.covers(const Position(4, 2)), isFalse);
      expect(piece.covers(const Position(1, 3)), isFalse);
    });

    test('covers its cells along a column', () {
      const piece = LogjamPiece.vertical(4, 0, 2);

      expect(piece.cells, const [Position(4, 0), Position(4, 1)]);
      expect(piece.offset, 0);
      expect(piece.line, 4);
      expect(piece.covers(const Position(4, 1)), isTrue);
      expect(piece.covers(const Position(4, 2)), isFalse);
    });

    test('slides along its own line only', () {
      expect(
        const LogjamPiece.horizontal(1, 2, 3).slidTo(3),
        const LogjamPiece.horizontal(3, 2, 3),
      );
      expect(
        const LogjamPiece.vertical(4, 0, 2).slidTo(2),
        const LogjamPiece.vertical(4, 2, 2),
      );
    });

    test('equals a piece with the same cells and axis', () {
      expect(
        const LogjamPiece.horizontal(0, 0, 2),
        const LogjamPiece.horizontal(0, 0, 2),
      );
      expect(
        const LogjamPiece.horizontal(0, 0, 2),
        isNot(const LogjamPiece.vertical(0, 0, 2)),
      );
    });
  });

  group('LogjamBoard', () {
    final board = parseLogjam('''
A..B.
A**B.>
C..B.
CDD..
''');

    test('names the piece on each cell', () {
      expect(board.pieceAt(const Position(1, 1)), 0);
      expect(board.pieceAt(const Position(0, 0)), 1);
      expect(board.pieceAt(const Position(3, 2)), 2);
      expect(board.pieceAt(const Position(2, 3)), 4);
      expect(board.pieceAt(const Position(4, 0)), isNull);
      expect(board.pieceAt(const Position(5, 0)), isNull);
      expect(board.pieceAt(const Position(0, -1)), isNull);
    });

    test('has its exit on the marked piece row', () {
      expect(board.marked, const LogjamPiece.horizontal(1, 1, 2));
      expect(board.exitRow, 1);
    });

    test('is solved once the marked piece reaches the exit', () {
      expect(board.isSolved, isFalse);
      expect(
        parseLogjam('''
...
.**>
''').isSolved,
        isTrue,
      );
    });

    test('finds how far each piece can slide', () {
      // The marked piece is boxed in by A and B.
      expect(board.lowestOffset(0), 1);
      expect(board.highestOffset(0), 1);
      // B is at the top and can slide down one cell, to the bottom.
      expect(board.lowestOffset(2), 0);
      expect(board.highestOffset(2), 1);
      // D slides right as far as the edge.
      expect(board.lowestOffset(4), 1);
      expect(board.highestOffset(4), 3);
      // A slides nowhere: the edge is above and C below.
      expect(board.lowestOffset(1), 0);
      expect(board.highestOffset(1), 0);
    });

    test('lists every legal move', () {
      expect(board.moves, const [
        LogjamMove(piece: 2, to: 1),
        LogjamMove(piece: 4, to: 2),
        LogjamMove(piece: 4, to: 3),
      ]);
    });

    test('applies a legal move and keeps the other pieces', () {
      final moved = board.apply(const LogjamMove(piece: 4, to: 3));

      expect(formatLogjam(moved), '''
A..B.
A**B.>
C..B.
C..DD
''');
      expect(moved.pieces.skip(1).take(3), board.pieces.skip(1).take(3));
      expect(formatLogjam(board), contains('CDD..'));
    });

    test('slides a piece any distance in one move', () {
      final start = parseLogjam('''
**...>
.....
''');

      final moved = start.apply(const LogjamMove(piece: 0, to: 3));

      expect(moved.isSolved, isTrue);
    });

    group('rejects a move', () {
      final cases = {
        'to where the piece already is': const LogjamMove(piece: 4, to: 1),
        'through another piece': const LogjamMove(piece: 0, to: 3),
        'off the board': const LogjamMove(piece: 4, to: 4),
        'of a piece that does not exist': const LogjamMove(piece: 5, to: 0),
        'of a negative piece': const LogjamMove(piece: -1, to: 0),
      };

      for (final MapEntry(key: description, value: move) in cases.entries) {
        test(description, () {
          expect(board.canMove(move), isFalse);
          expect(() => board.apply(move), throwsArgumentError);
        });
      }
    });

    test('equals a board with the same pieces in the same order', () {
      final again = parseLogjam(formatLogjam(board));

      expect(again, board);
      expect(again.hashCode, board.hashCode);
      expect(
        LogjamBoard(
          width: 5,
          height: 4,
          pieces: [board.pieces[0], board.pieces[2], board.pieces[1]],
        ),
        isNot(board),
      );
    });

    group('rejects', () {
      const marked = LogjamPiece.horizontal(0, 1, 2);
      final cases = <String, LogjamBoard Function()>{
        'a side below 2': () =>
            LogjamBoard(width: 1, height: 3, pieces: const [marked]),
        'a side above the limit': () => LogjamBoard(
          width: LogjamBoard.maxSide + 1,
          height: 3,
          pieces: const [marked],
        ),
        'no pieces': () => LogjamBoard(width: 3, height: 3, pieces: const []),
        'a vertical marked piece': () => LogjamBoard(
          width: 3,
          height: 3,
          pieces: const [LogjamPiece.vertical(0, 0, 2)],
        ),
        'a piece of one cell': () => LogjamBoard(
          width: 4,
          height: 3,
          pieces: const [marked, LogjamPiece.vertical(3, 0, 1)],
        ),
        'a piece of four cells': () => LogjamBoard(
          width: 4,
          height: 4,
          pieces: const [marked, LogjamPiece.vertical(3, 0, 4)],
        ),
        'a piece outside the grid': () => LogjamBoard(
          width: 3,
          height: 3,
          pieces: const [marked, LogjamPiece.vertical(2, 2, 2)],
        ),
        'pieces that share a cell': () => LogjamBoard(
          width: 3,
          height: 3,
          pieces: const [marked, LogjamPiece.vertical(1, 0, 2)],
        ),
      };

      for (final MapEntry(key: description, value: create) in cases.entries) {
        test(description, () {
          expect(create, throwsArgumentError);
        });
      }
    });
  });
}
