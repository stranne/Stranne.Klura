import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/bridges/logic/bridges_puzzle.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';
import 'package:test/test.dart';

void main() {
  // . 2 . 3 . 1
  // . . . . . .
  // . 1 . 4 . .
  // . . . . . .
  // 2 . . 2 . .
  final puzzle = BridgesPuzzle(
    width: 6,
    height: 5,
    islands: const [
      Island(Position(3, 4), 2),
      Island(Position(1, 0), 2),
      Island(Position(3, 2), 4),
      Island(Position(5, 0), 1),
      Island(Position(0, 4), 2),
      Island(Position(3, 0), 3),
      Island(Position(1, 2), 1),
    ],
  );

  test('keeps the islands in reading order', () {
    expect(puzzle.islands.map((island) => island.position), const [
      Position(1, 0),
      Position(3, 0),
      Position(5, 0),
      Position(1, 2),
      Position(3, 2),
      Position(0, 4),
      Position(3, 4),
    ]);
  });

  test('finds the island at a position', () {
    expect(
      puzzle.islandAt(const Position(3, 2)),
      const Island(Position(3, 2), 4),
    );
    expect(puzzle.islandAt(const Position(2, 2)), isNull);
  });

  test('knows which positions lie on the board', () {
    expect(puzzle.contains(const Position(5, 4)), isTrue);
    expect(puzzle.contains(const Position(6, 0)), isFalse);
    expect(puzzle.contains(const Position(0, -1)), isFalse);
  });

  group('neighbor', () {
    final cases = [
      (const Position(3, 2), Direction.up, const Position(3, 0)),
      (const Position(3, 2), Direction.down, const Position(3, 4)),
      (const Position(3, 2), Direction.left, const Position(1, 2)),
      (const Position(3, 2), Direction.right, null),
      (const Position(1, 0), Direction.right, const Position(3, 0)),
      (const Position(0, 4), Direction.up, null),
      (const Position(2, 4), Direction.left, const Position(0, 4)),
    ];

    for (final (from, direction, expected) in cases) {
      test('from $from ${direction.name} is ${expected ?? 'none'}', () {
        expect(puzzle.neighbor(from, direction)?.position, expected);
      });
    }
  });

  test('lists every connection between neighboring islands', () {
    expect(puzzle.connections, [
      Connection(const Position(1, 0), const Position(3, 0)),
      Connection(const Position(1, 0), const Position(1, 2)),
      Connection(const Position(3, 0), const Position(5, 0)),
      Connection(const Position(3, 0), const Position(3, 2)),
      Connection(const Position(1, 2), const Position(3, 2)),
      Connection(const Position(3, 2), const Position(3, 4)),
      Connection(const Position(0, 4), const Position(3, 4)),
    ]);
  });

  test('knows whether it offers a connection', () {
    final offered = Connection(const Position(3, 4), const Position(3, 2));
    final overIsland = Connection(const Position(3, 0), const Position(3, 4));

    expect(puzzle.hasConnection(offered), isTrue);
    expect(puzzle.hasConnection(overIsland), isFalse);
  });

  test('detects connections that pass over an island', () {
    final overIsland = Connection(const Position(3, 0), const Position(3, 4));
    final clear = Connection(const Position(0, 1), const Position(5, 1));

    expect(puzzle.passesOverIsland(overIsland), isTrue);
    expect(puzzle.passesOverIsland(clear), isFalse);
  });

  test('equals a puzzle with the same islands in any order', () {
    final same = BridgesPuzzle(
      width: 6,
      height: 5,
      islands: puzzle.islands.reversed,
    );

    expect(same, puzzle);
    expect(same.hashCode, puzzle.hashCode);
  });

  group('rejects', () {
    final cases = [
      ('an empty grid', 0, 3, const [Island(Position(0, 0), 1)]),
      ('an island outside the grid', 3, 3, const [Island(Position(3, 0), 1)]),
      (
        'two islands on one cell',
        5,
        1,
        const [
          Island(Position(0, 0), 1),
          Island(Position(0, 0), 2),
        ],
      ),
      ('an island needing no bridges', 3, 1, const [Island(Position(0, 0), 0)]),
      (
        'an island needing nine bridges',
        3,
        3,
        const [
          Island(Position(1, 1), 9),
        ],
      ),
      (
        'islands side by side',
        3,
        1,
        const [
          Island(Position(0, 0), 1),
          Island(Position(1, 0), 1),
        ],
      ),
    ];

    for (final (description, width, height, islands) in cases) {
      test(description, () {
        expect(
          () => BridgesPuzzle(width: width, height: height, islands: islands),
          throwsArgumentError,
        );
      });
    }
  });
}
