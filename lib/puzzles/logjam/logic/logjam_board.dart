import 'package:klura/core/grid.dart';
import 'package:meta/meta.dart';

/// A log: a straight piece of two or three cells that slides only along its
/// own length.
@immutable
final class LogjamPiece {
  /// Creates a piece of [length] cells whose left cell is ([x], [y]).
  const LogjamPiece.horizontal(this.x, this.y, this.length)
    : isHorizontal = true;

  /// Creates a piece of [length] cells whose top cell is ([x], [y]).
  const LogjamPiece.vertical(this.x, this.y, this.length)
    : isHorizontal = false;

  /// The shortest piece.
  static const int minLength = 2;

  /// The longest piece.
  static const int maxLength = 3;

  /// The column of the piece's left or top cell.
  final int x;

  /// The row of the piece's left or top cell.
  final int y;

  /// The number of cells the piece covers.
  final int length;

  /// Whether the piece lies along a row, so it slides left and right.
  /// Otherwise it lies along a column and slides up and down.
  final bool isHorizontal;

  /// Where the piece is along its line: the column of its left cell if it is
  /// horizontal, the row of its top cell if it is vertical.
  int get offset => isHorizontal ? x : y;

  /// The row of a horizontal piece or the column of a vertical one, which a
  /// slide never changes.
  int get line => isHorizontal ? y : x;

  /// The cells the piece covers, from its left or top cell.
  Iterable<Position> get cells => [
    for (var index = 0; index < length; index++)
      if (isHorizontal) Position(x + index, y) else Position(x, y + index),
  ];

  /// Whether the piece covers [cell].
  bool covers(Position cell) => isHorizontal
      ? cell.y == y && cell.x >= x && cell.x < x + length
      : cell.x == x && cell.y >= y && cell.y < y + length;

  /// The same piece slid along its line to [offset].
  LogjamPiece slidTo(int offset) => isHorizontal
      ? LogjamPiece.horizontal(offset, y, length)
      : LogjamPiece.vertical(x, offset, length);

  @override
  bool operator ==(Object other) =>
      other is LogjamPiece &&
      other.x == x &&
      other.y == y &&
      other.length == length &&
      other.isHorizontal == isHorizontal;

  @override
  int get hashCode => Object.hash(x, y, length, isHorizontal);

  @override
  String toString() =>
      '${isHorizontal ? 'horizontal' : 'vertical'}($x, $y, $length)';
}

/// One move: a piece slid along its line to a new offset, any distance.
@immutable
final class LogjamMove {
  const LogjamMove({required this.piece, required this.to});

  /// The index of the piece in [LogjamBoard.pieces].
  final int piece;

  /// The piece's offset after the move, as in [LogjamPiece.offset].
  final int to;

  @override
  bool operator ==(Object other) =>
      other is LogjamMove && other.piece == piece && other.to == to;

  @override
  int get hashCode => Object.hash(piece, to);

  @override
  String toString() => 'LogjamMove($piece to $to)';
}

/// A Logjam board: a grid with its pieces where they lie now.
///
/// The first piece is the marked one. It lies along a row, and the exit is
/// on the right edge of that row: the board is solved once the marked piece
/// reaches it. The order of the pieces never changes, so an index names the
/// same piece in every position a game passes through. A puzzle is the
/// board it starts from; the game judges the player's position with
/// [isSolved], never by comparing with a stored solution.
@immutable
final class LogjamBoard {
  /// Creates a board of [width] by [height] cells holding [pieces], the
  /// marked piece first.
  ///
  /// Throws an [ArgumentError] if a side is outside 2 to [maxSide], there
  /// are no pieces, the marked piece is vertical, or a piece is not 2 or 3
  /// cells long, lies outside the grid or shares a cell with another.
  factory LogjamBoard({
    required int width,
    required int height,
    required List<LogjamPiece> pieces,
  }) {
    RangeError.checkValueInInterval(width, 2, maxSide, 'width');
    RangeError.checkValueInInterval(height, 2, maxSide, 'height');
    if (pieces.isEmpty) {
      throw ArgumentError.value(pieces, 'pieces', 'Needs the marked piece');
    }
    if (!pieces.first.isHorizontal) {
      throw ArgumentError.value(
        pieces.first,
        'pieces',
        'The marked piece must lie along a row',
      );
    }

    final cells = List.filled(width * height, 0);
    for (final (index, piece) in pieces.indexed) {
      if (piece.length < LogjamPiece.minLength ||
          piece.length > LogjamPiece.maxLength) {
        throw ArgumentError.value(piece, 'pieces', 'Must be 2 or 3 cells long');
      }
      for (final cell in piece.cells) {
        if (!cell.isWithin(width, height)) {
          throw ArgumentError.value(piece, 'pieces', 'Lies outside the grid');
        }
        final slot = cell.y * width + cell.x;
        if (cells[slot] != 0) {
          throw ArgumentError.value(piece, 'pieces', 'Shares a cell');
        }
        cells[slot] = index + 1;
      }
    }

    return LogjamBoard._(width, height, List.unmodifiable(pieces), cells);
  }

  const LogjamBoard._(this.width, this.height, this.pieces, this._cells);

  /// The longest side a board may have.
  static const int maxSide = 12;

  final int width;
  final int height;

  /// The pieces, the marked piece first.
  final List<LogjamPiece> pieces;

  /// The index of the piece on each cell plus one, or 0 for an empty cell,
  /// in reading order.
  final List<int> _cells;

  /// The piece that has to leave through the exit.
  LogjamPiece get marked => pieces.first;

  /// The row with the exit on its right edge.
  int get exitRow => marked.y;

  /// Whether the marked piece has reached the exit.
  bool get isSolved => marked.x + marked.length == width;

  /// Whether [cell] lies on the board.
  bool contains(Position cell) => cell.isWithin(width, height);

  /// The index of the piece on [cell], or `null` if the cell is empty or off
  /// the board.
  int? pieceAt(Position cell) {
    if (!contains(cell)) {
      return null;
    }
    final value = _cells[cell.y * width + cell.x];
    return value == 0 ? null : value - 1;
  }

  /// The lowest offset [piece] can slide to from where it lies.
  int lowestOffset(int piece) {
    final current = pieces[piece];
    var offset = current.offset;
    while (offset > 0 && _isFree(current, offset - 1)) {
      offset--;
    }
    return offset;
  }

  /// The highest offset [piece] can slide to from where it lies.
  int highestOffset(int piece) {
    final current = pieces[piece];
    final last = _lineLength(current) - current.length;
    var offset = current.offset;
    while (offset < last && _isFree(current, offset + current.length)) {
      offset++;
    }
    return offset;
  }

  /// Whether [move] is legal: its piece slides to another offset without
  /// leaving the board or passing over another piece.
  bool canMove(LogjamMove move) {
    if (move.piece < 0 || move.piece >= pieces.length) {
      return false;
    }
    return move.to != pieces[move.piece].offset &&
        move.to >= lowestOffset(move.piece) &&
        move.to <= highestOffset(move.piece);
  }

  /// The board after [move].
  ///
  /// Throws an [ArgumentError] if the move is not legal.
  LogjamBoard apply(LogjamMove move) {
    if (!canMove(move)) {
      throw ArgumentError.value(move, 'move', 'Is not legal on this board');
    }
    final moved = pieces[move.piece].slidTo(move.to);
    final cells = List.of(_cells);
    for (final cell in pieces[move.piece].cells) {
      cells[cell.y * width + cell.x] = 0;
    }
    for (final cell in moved.cells) {
      cells[cell.y * width + cell.x] = move.piece + 1;
    }
    return LogjamBoard._(
      width,
      height,
      List.unmodifiable([
        for (final (index, piece) in pieces.indexed)
          if (index == move.piece) moved else piece,
      ]),
      cells,
    );
  }

  /// Every legal move, piece by piece, each from its lowest offset to its
  /// highest.
  Iterable<LogjamMove> get moves => [
    for (var piece = 0; piece < pieces.length; piece++)
      for (var to = lowestOffset(piece); to <= highestOffset(piece); to++)
        if (to != pieces[piece].offset) LogjamMove(piece: piece, to: to),
  ];

  /// The number of cells along the line [piece] slides on.
  int _lineLength(LogjamPiece piece) => piece.isHorizontal ? width : height;

  /// Whether the cell at [offset] along [piece]'s line is empty.
  bool _isFree(LogjamPiece piece, int offset) =>
      _cells[piece.isHorizontal
          ? piece.y * width + offset
          : offset * width + piece.x] ==
      0;

  @override
  bool operator ==(Object other) =>
      other is LogjamBoard &&
      other.width == width &&
      other.height == height &&
      _listEquals(other.pieces, pieces);

  @override
  int get hashCode => Object.hash(width, height, Object.hashAll(pieces));

  @override
  String toString() => 'LogjamBoard(${width}x$height, $pieces)';
}

bool _listEquals<T>(List<T> first, List<T> second) {
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}
