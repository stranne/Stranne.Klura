import 'package:klura/core/seeded_random.dart';
import 'package:klura/puzzles/logjam/logic/logjam_board.dart';
import 'package:klura/puzzles/logjam/logic/logjam_solver.dart';
import 'package:klura/puzzles/logjam/logic/logjam_text.dart';
import 'package:test/test.dart';

void main() {
  group('solveLogjam', () {
    test('needs no moves for a solved board', () {
      expect(
        solveLogjam(
          parseLogjam('''
A..
A**>
'''),
        ),
        isEmpty,
      );
    });

    test('slides the marked piece out when its way is clear', () {
      expect(
        solveLogjam(
          parseLogjam('''
**..>
....
'''),
        ),
        const [LogjamMove(piece: 0, to: 2)],
      );
    });

    test('finds the order the pieces have to move in', () {
      // A can only leave the exit row downwards, and B is in its way until
      // it slides left.
      final board = parseLogjam('''
...A
**.A>
.BBB
....
''');

      expect(solveLogjam(board), const [
        LogjamMove(piece: 2, to: 0),
        LogjamMove(piece: 1, to: 2),
        LogjamMove(piece: 0, to: 2),
      ]);
    });

    test('finds no solution when a piece can never leave the exit row', () {
      // A is two cells long on a board three cells high, so it always
      // covers the middle row.
      final board = parseLogjam('''
...A
**.A>
....
''');

      expect(solveLogjam(board), isNull);
    });
  });

  group('exploreLogjam', () {
    final board = parseLogjam('''
...A
**.A>
.BBB
....
''');

    test('starts from the board it explores', () {
      final cluster = exploreLogjam(board)!;

      expect(cluster.boardAt(0), board);
      expect(cluster.fewestMovesAt(0), 3);
    });

    test('finds the position that needs the most moves', () {
      final cluster = exploreLogjam(board)!;

      expect(cluster.mostMoves, isNotNull);
      expect(solveLogjam(cluster.farthest!), hasLength(cluster.mostMoves));
      for (var index = 0; index < cluster.size; index++) {
        expect(
          cluster.fewestMovesAt(index),
          lessThanOrEqualTo(cluster.mostMoves!),
        );
      }
    });

    test('has no farthest position when none is solved', () {
      final cluster = exploreLogjam(
        parseLogjam('''
...A
**.A>
....
'''),
      )!;

      expect(cluster.solvedCount, 0);
      expect(cluster.mostMoves, isNull);
      expect(cluster.farthest, isNull);
      expect(cluster.fewestMovesAt(0), isNull);
    });

    test('gives up beyond the most positions allowed', () {
      final size = exploreLogjam(board)!.size;

      expect(exploreLogjam(board, maxPositions: size), isNotNull);
      expect(exploreLogjam(board, maxPositions: size - 1), isNull);
    });

    test('rejects a limit below one', () {
      expect(() => exploreLogjam(board, maxPositions: 0), throwsRangeError);
    });

    test('rejects an index outside the cluster', () {
      final cluster = exploreLogjam(board)!;

      expect(() => cluster.boardAt(cluster.size), throwsRangeError);
      expect(() => cluster.fewestMovesAt(-1), throwsRangeError);
    });
  });

  test('agree with a brute force search on small random boards', () {
    final random = SeededRandom(2026);
    final startsSeen = <String>{};

    for (var round = 0; round < 200; round++) {
      final board = _randomBoard(random);
      _expectAgreement(board, _bruteForceDistances(_everyPlacement(board)));

      startsSeen.add(switch (_bruteForceDistances(_reachable(board)!)[board]) {
        null => 'unsolvable',
        0 => 'solved',
        1 || 2 => 'short',
        _ => 'long',
      });
    }

    expect(
      startsSeen,
      {'unsolvable', 'solved', 'short', 'long'},
      reason: 'The boards should cover every case',
    );
  });

  // A 6 by 6 board with more than ten pieces packs each position into two
  // words, which the small boards above never need.
  test('agree with a brute force search on crowded 6 by 6 boards', () {
    final random = SeededRandom(2027);
    var checked = 0;
    var mostMoves = 0;

    while (checked < 12) {
      final board = _crowdedBoard(random);
      final reachable = _reachable(board, limit: 1500);
      if (reachable == null) {
        continue;
      }
      final distances = _bruteForceDistances(reachable);
      _expectAgreement(board, distances);
      checked++;
      for (final moves in distances.values.whereType<int>()) {
        mostMoves = moves > mostMoves ? moves : mostMoves;
      }
    }

    expect(mostMoves, greaterThanOrEqualTo(5), reason: 'Some should be deep');
  });
}

/// Checks the solver and the cluster against [distances], the brute force
/// fewest moves of every position reachable from [board] and maybe more.
void _expectAgreement(LogjamBoard board, Map<LogjamBoard, int?> distances) {
  final reason = 'For\n${formatLogjam(board)}';

  final solution = solveLogjam(board);
  expect(solution?.length, distances[board], reason: reason);
  if (solution != null) {
    var position = board;
    for (final move in solution) {
      position = position.apply(move);
    }
    expect(position.isSolved, isTrue, reason: reason);
  }

  final cluster = exploreLogjam(board)!;
  final explored = {
    for (var index = 0; index < cluster.size; index++)
      cluster.boardAt(index): cluster.fewestMovesAt(index),
  };
  expect(explored.keys.toSet(), _reachable(board), reason: reason);
  expect(explored.length, cluster.size, reason: reason);
  for (final MapEntry(key: position, value: moves) in explored.entries) {
    expect(moves, distances[position], reason: '$reason at\n$position');
  }
  final solvable = explored.values.whereType<int>();
  expect(
    cluster.mostMoves,
    solvable.isEmpty ? isNull : solvable.reduce((a, b) => a > b ? a : b),
    reason: reason,
  );
  expect(
    cluster.solvedCount,
    explored.keys.where((position) => position.isSolved).length,
    reason: reason,
  );
}

/// A board of 3 to 5 columns and 2 to 5 rows with the marked piece and up to
/// four others, placed wherever they fit.
LogjamBoard _randomBoard(SeededRandom random) {
  final width = 3 + random.nextInt(3);
  final height = 2 + random.nextInt(4);
  final pieces = [
    LogjamPiece.horizontal(
      random.nextInt(width - 1),
      random.nextInt(height),
      2,
    ),
  ];
  final count = 1 + random.nextInt(5);
  for (var tries = 0; tries < 40 && pieces.length < count; tries++) {
    final length = random.nextChance(0.3) ? 3 : 2;
    final piece = random.nextChance(0.5)
        ? LogjamPiece.horizontal(
            random.nextInt(width - length + 1),
            random.nextInt(height),
            length,
          )
        : LogjamPiece.vertical(
            random.nextInt(width),
            random.nextInt(height),
            length,
          );
    final fits = piece.cells.every(
      (cell) =>
          cell.isWithin(width, height) &&
          pieces.every((other) => !other.covers(cell)),
    );
    if (fits) {
      pieces.add(piece);
    }
  }
  return LogjamBoard(width: width, height: height, pieces: pieces);
}

/// A 6 by 6 board with the marked piece on the third row and 11 to 14
/// other pieces, placed wherever they fit.
LogjamBoard _crowdedBoard(SeededRandom random) {
  final pieces = [LogjamPiece.horizontal(random.nextInt(5), 2, 2)];
  final count = 12 + random.nextInt(4);
  for (var tries = 0; tries < 400 && pieces.length < count; tries++) {
    final length = random.nextChance(0.3) ? 3 : 2;
    final piece = random.nextChance(0.5)
        ? LogjamPiece.horizontal(
            random.nextInt(7 - length),
            random.nextInt(6),
            length,
          )
        : LogjamPiece.vertical(
            random.nextInt(6),
            random.nextInt(7 - length),
            length,
          );
    // A piece along the exit row would only block the marked piece for good.
    final alongExitRow = piece.isHorizontal && piece.y == 2;
    final free = piece.cells.every(
      (cell) => pieces.every((other) => !other.covers(cell)),
    );
    if (free && !alongExitRow) {
      pieces.add(piece);
    }
  }
  return LogjamBoard(width: 6, height: 6, pieces: pieces);
}

/// Every placement of [board]'s pieces, reachable or not.
List<LogjamBoard> _everyPlacement(LogjamBoard board) {
  final positions = <LogjamBoard>[];
  void place(List<LogjamPiece> placed) {
    if (placed.length == board.pieces.length) {
      positions.add(
        LogjamBoard(width: board.width, height: board.height, pieces: placed),
      );
      return;
    }
    final piece = board.pieces[placed.length];
    final line = piece.isHorizontal ? board.width : board.height;
    for (var offset = 0; offset <= line - piece.length; offset++) {
      final moved = piece.slidTo(offset);
      if (placed.every((other) => !moved.cells.any(other.covers))) {
        place([...placed, moved]);
      }
    }
  }

  place([]);
  return positions;
}

/// The fewest moves from each of [positions] to a solved position, or
/// `null` where none leads there.
///
/// [positions] must hold every position one move from each of them. Each
/// distance is lowered to one more than a neighbor's until nothing changes,
/// using only the moves the board allows.
Map<LogjamBoard, int?> _bruteForceDistances(Iterable<LogjamBoard> positions) {
  final distances = <LogjamBoard, int?>{
    for (final position in positions) position: position.isSolved ? 0 : null,
  };
  var changed = true;
  while (changed) {
    changed = false;
    for (final position in distances.keys) {
      for (final move in position.moves) {
        final next = distances[position.apply(move)];
        final current = distances[position];
        if (next != null && (current == null || next + 1 < current)) {
          distances[position] = next + 1;
          changed = true;
        }
      }
    }
  }
  return distances;
}

/// Every position reachable from [board], found depth first, or `null` if
/// there are more than [limit].
Set<LogjamBoard>? _reachable(LogjamBoard board, {int limit = 1 << 30}) {
  final seen = {board};
  final pending = [board];
  while (pending.isNotEmpty) {
    if (seen.length > limit) {
      return null;
    }
    final position = pending.removeLast();
    for (final move in position.moves) {
      final next = position.apply(move);
      if (seen.add(next)) {
        pending.add(next);
      }
    }
  }
  return seen;
}
