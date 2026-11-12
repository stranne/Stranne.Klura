import 'dart:math' as math;
import 'dart:typed_data';

import 'package:klura/puzzles/logjam/logic/logjam_board.dart';

/// One shortest way to solve [board], or `null` if no moves solve it.
///
/// A move slides one piece any distance, so the length of the list is the
/// fewest moves the board needs. A solved board needs none. The search is
/// breadth first over the positions reachable from [board].
List<LogjamMove>? solveLogjam(LogjamBoard board) {
  if (board.isSolved) {
    return const [];
  }
  final space = _Space(board);
  final parents = _IntList()..add(-1);
  final movedPieces = _IntList()..add(-1);
  final movedTo = _IntList()..add(-1);

  for (var index = 0; index < space.count; index++) {
    final neighbors = space.expand(index);
    for (var next = 0; next < neighbors; next++) {
      final known = space.count;
      final reached = space.addNeighbor(next);
      if (reached != known) {
        continue;
      }
      parents.add(index);
      movedPieces.add(space.neighborPiece(next));
      movedTo.add(space.neighborTo(next));
      if (space.isSolved(reached)) {
        final moves = <LogjamMove>[];
        for (var step = reached; step != 0; step = parents[step]) {
          moves.add(LogjamMove(piece: movedPieces[step], to: movedTo[step]));
        }
        return moves.reversed.toList(growable: false);
      }
    }
  }
  return null;
}

/// Every position reachable from [board], with the fewest moves each needs,
/// or `null` if there are more than [maxPositions] of them.
///
/// Moves can always be undone, so the positions form one connected cluster:
/// any of them can reach any other, and exploring from any of them finds
/// the same cluster.
LogjamCluster? exploreLogjam(LogjamBoard board, {int maxPositions = 1 << 20}) {
  RangeError.checkValueInInterval(maxPositions, 1, 1 << 24, 'maxPositions');
  final space = _Space(board);
  final edgeStarts = _IntList();
  final edges = _IntList();

  for (var index = 0; index < space.count; index++) {
    edgeStarts.add(edges.length);
    final neighbors = space.expand(index);
    for (var next = 0; next < neighbors; next++) {
      edges.add(space.addNeighbor(next));
    }
    if (space.count > maxPositions) {
      return null;
    }
  }
  edgeStarts.add(edges.length);

  // Breadth first from every solved position at once gives each position
  // its distance to the nearest one. Moves are reversible, so following them
  // backwards is the same as following them forwards.
  final size = space.count;
  final distances = Int32List(size)..fillRange(0, size, -1);
  final queue = Int32List(size);
  var tail = 0;
  for (var index = 0; index < size; index++) {
    if (space.isSolved(index)) {
      distances[index] = 0;
      queue[tail++] = index;
    }
  }
  final solvedCount = tail;
  for (var head = 0; head < tail; head++) {
    final index = queue[head];
    final distance = distances[index] + 1;
    for (var edge = edgeStarts[index]; edge < edgeStarts[index + 1]; edge++) {
      final next = edges[edge];
      if (distances[next] < 0) {
        distances[next] = distance;
        queue[tail++] = next;
      }
    }
  }

  // The queue holds the solvable positions by distance, so the farthest
  // come last. Keep the first of them the search reached.
  var farthest = -1;
  if (tail > 0) {
    var first = tail - 1;
    while (first > 0 &&
        distances[queue[first - 1]] == distances[queue[tail - 1]]) {
      first--;
    }
    farthest = queue[first];
  }
  return LogjamCluster._(space, distances, solvedCount, farthest);
}

/// The positions reachable from a board, each with the fewest moves that
/// solve it.
final class LogjamCluster {
  LogjamCluster._(
    this._space,
    this._distances,
    this.solvedCount,
    this._farthestIndex,
  );

  final _Space _space;
  final Int32List _distances;
  final int _farthestIndex;

  /// The number of positions that are solved.
  final int solvedCount;

  /// The number of positions, the starting board included.
  int get size => _space.count;

  /// The position at [index], where 0 is the board explored from and the
  /// others follow in the order the search found them.
  LogjamBoard boardAt(int index) {
    RangeError.checkValidIndex(index, this, 'index', size);
    return _space.boardAt(index);
  }

  /// The fewest moves that solve the position at [index], or `null` if none
  /// do.
  int? fewestMovesAt(int index) {
    RangeError.checkValidIndex(index, this, 'index', size);
    final distance = _distances[index];
    return distance < 0 ? null : distance;
  }

  /// The most moves any position needs, or `null` if no position is solved.
  int? get mostMoves => _farthestIndex < 0 ? null : _distances[_farthestIndex];

  /// A position that needs [mostMoves], or `null` if no position is solved.
  ///
  /// Several positions may need that many. This is the first of them that a
  /// search outwards from the solved positions reaches, so the choice is the
  /// same on every platform.
  LogjamBoard? get farthest =>
      _farthestIndex < 0 ? null : _space.boardAt(_farthestIndex);
}

/// The positions of one board's pieces, each packed into a few 30-bit words
/// so it is cheap to store, hash and compare.
///
/// The pieces keep their lines and lengths in every position, so a position
/// is just each piece's offset. Words stay below 2^30 and every product in
/// the hash stays below 2^53, so the arithmetic is exact in JavaScript as
/// well as on the VM and in WebAssembly. The order positions are found in
/// never depends on the hash, only on the order of the moves.
final class _Space {
  factory _Space(LogjamBoard board) {
    final pieces = board.pieces;
    final width = board.width;
    final maxOffset = math.max(width, board.height) - LogjamPiece.minLength;
    final bits = math.max(1, maxOffset.bitLength);
    final perWord = _wordBits ~/ bits;
    final words = (pieces.length + perWord - 1) ~/ perWord;
    final lastOffsets = [
      for (final piece in pieces)
        (piece.isHorizontal ? width : board.height) - piece.length,
    ];

    final space = _Space._(
      board,
      words,
      (1 << bits) - 1,
      Int32List.fromList([
        for (var index = 0; index < pieces.length; index++) index ~/ perWord,
      ]),
      Int32List.fromList([
        for (var index = 0; index < pieces.length; index++)
          index % perWord * bits,
      ]),
      Int32List.fromList(lastOffsets),
      Int32List.fromList([
        for (final piece in pieces)
          if (piece.isHorizontal) piece.y * width else piece.x,
      ]),
      Int32List.fromList([
        for (final piece in pieces)
          if (piece.isHorizontal) 1 else width,
      ]),
      math.max(1, lastOffsets.fold(0, (sum, last) => sum + last)),
    );

    final start = Int32List(words);
    for (final (index, piece) in pieces.indexed) {
      start[space._wordOf[index]] += piece.offset << space._shiftOf[index];
    }
    space._add(start, 0);
    return space;
  }

  _Space._(
    this._board,
    this._words,
    this._mask,
    this._wordOf,
    this._shiftOf,
    this._lastOffsetOf,
    this._baseOf,
    this._stepOf,
    int maxNeighbors,
  ) : _lengthOf = Int32List.fromList([
        for (final piece in _board.pieces) piece.length,
      ]),
      _offsets = Int32List(_board.pieces.length),
      _occupied = Int32List(_board.width * _board.height),
      _neighbors = Int32List(maxNeighbors * _words),
      _neighborPieces = Int32List(maxNeighbors),
      _neighborTo = Int32List(maxNeighbors),
      _keys = Int32List(_words * 64),
      _table = Int32List(128);

  /// The bits of each word in use, so every word stays below 2^30.
  static const int _wordBits = 30;

  static const int _hashMask = 0x3FFFFFFF;

  final LogjamBoard _board;

  /// The words that hold one position.
  final int _words;

  /// The mask for one piece's offset.
  final int _mask;

  /// For each piece, the word that holds its offset and where in the word.
  final Int32List _wordOf;
  final Int32List _shiftOf;

  /// For each piece, its highest offset and its length.
  final Int32List _lastOffsetOf;
  final Int32List _lengthOf;

  /// For each piece, the index of the cell at offset 0 of its line, and how
  /// far apart its cells are: 1 along a row, the width along a column.
  final Int32List _baseOf;
  final Int32List _stepOf;

  /// The offsets of the position being expanded.
  final Int32List _offsets;

  /// The cells of the position being expanded hold [_stamp].
  final Int32List _occupied;
  int _stamp = 0;

  /// The positions one move from the position last expanded, and the move
  /// that reaches each.
  final Int32List _neighbors;
  final Int32List _neighborPieces;
  final Int32List _neighborTo;

  /// The words of every position found, in the order they were found.
  Int32List _keys;

  /// An open-addressing hash table of position indexes plus one, with 0 for
  /// an empty slot.
  Int32List _table;

  /// The number of positions found.
  int count = 0;

  /// Whether the marked piece has reached the exit in position [index].
  bool isSolved(int index) =>
      (_keys[index * _words] & _mask) == _lastOffsetOf[0];

  /// The position at [index] as a board.
  LogjamBoard boardAt(int index) {
    final base = index * _words;
    return LogjamBoard(
      width: _board.width,
      height: _board.height,
      pieces: [
        for (final (piece, start) in _board.pieces.indexed)
          start.slidTo(
            (_keys[base + _wordOf[piece]] >>> _shiftOf[piece]) & _mask,
          ),
      ],
    );
  }

  /// Finds every position one move from position [index] and returns how
  /// many there are. Read them with [addNeighbor], [neighborPiece] and
  /// [neighborTo] before the next call.
  int expand(int index) {
    final base = index * _words;
    final pieceCount = _offsets.length;
    final stamp = ++_stamp;
    for (var piece = 0; piece < pieceCount; piece++) {
      final offset = (_keys[base + _wordOf[piece]] >>> _shiftOf[piece]) & _mask;
      _offsets[piece] = offset;
      final step = _stepOf[piece];
      final first = _baseOf[piece] + offset * step;
      final end = first + _lengthOf[piece] * step;
      for (var cell = first; cell < end; cell += step) {
        _occupied[cell] = stamp;
      }
    }

    var found = 0;
    for (var piece = 0; piece < pieceCount; piece++) {
      final from = _offsets[piece];
      final head = _baseOf[piece];
      final step = _stepOf[piece];
      for (
        var to = from - 1;
        to >= 0 && _occupied[head + to * step] != stamp;
        to--
      ) {
        _record(found++, base, piece, from, to);
      }
      final tail = head + (_lengthOf[piece] - 1) * step;
      for (
        var to = from + 1;
        to <= _lastOffsetOf[piece] && _occupied[tail + to * step] != stamp;
        to++
      ) {
        _record(found++, base, piece, from, to);
      }
    }
    return found;
  }

  /// Adds neighbor [next] of the last expanded position if it is new, and
  /// returns its index either way.
  int addNeighbor(int next) => _add(_neighbors, next * _words);

  /// The piece that moves to reach neighbor [next].
  int neighborPiece(int next) => _neighborPieces[next];

  /// The offset that piece moves to.
  int neighborTo(int next) => _neighborTo[next];

  void _record(int next, int base, int piece, int from, int to) {
    final start = next * _words;
    for (var word = 0; word < _words; word++) {
      _neighbors[start + word] = _keys[base + word];
    }
    _neighbors[start + _wordOf[piece]] += (to - from) << _shiftOf[piece];
    _neighborPieces[next] = piece;
    _neighborTo[next] = to;
  }

  /// Adds the position held in [source] from [start] if it is new, and
  /// returns its index either way.
  int _add(Int32List source, int start) {
    if ((count + 1) * 2 > _table.length) {
      _growTable();
    }
    final slotMask = _table.length - 1;
    var slot = _hash(source, start) & slotMask;
    while (true) {
      final entry = _table[slot];
      if (entry == 0) {
        break;
      }
      if (_equals(entry - 1, source, start)) {
        return entry - 1;
      }
      slot = (slot + 1) & slotMask;
    }

    if ((count + 1) * _words > _keys.length) {
      _keys = Int32List(_keys.length * 2)..setRange(0, count * _words, _keys);
    }
    final base = count * _words;
    for (var word = 0; word < _words; word++) {
      _keys[base + word] = source[start + word];
    }
    _table[slot] = ++count;
    return count - 1;
  }

  bool _equals(int index, Int32List source, int start) {
    final base = index * _words;
    for (var word = 0; word < _words; word++) {
      if (_keys[base + word] != source[start + word]) {
        return false;
      }
    }
    return true;
  }

  void _growTable() {
    _table = Int32List(_table.length * 2);
    final slotMask = _table.length - 1;
    for (var index = 0; index < count; index++) {
      var slot = _hash(_keys, index * _words) & slotMask;
      while (_table[slot] != 0) {
        slot = (slot + 1) & slotMask;
      }
      _table[slot] = index + 1;
    }
  }

  int _hash(Int32List source, int start) {
    var hash = 0;
    for (var word = 0; word < _words; word++) {
      hash = _mix(hash ^ source[start + word]);
    }
    return hash;
  }

  /// Spreads the bits of a value below 2^30. Each multiplier is below 2^18,
  /// so no product reaches 2^53.
  static int _mix(int value) {
    var hash = ((value ^ (value >>> 15)) * 0x2C1B3) & _hashMask;
    hash = ((hash ^ (hash >>> 13)) * 0x297A3) & _hashMask;
    return hash ^ (hash >>> 16);
  }
}

/// A growable list of integers backed by an [Int32List].
final class _IntList {
  Int32List _items = Int32List(64);
  int length = 0;

  int operator [](int index) => _items[index];

  void add(int value) {
    if (length == _items.length) {
      _items = Int32List(_items.length * 2)..setRange(0, length, _items);
    }
    _items[length++] = value;
  }
}
