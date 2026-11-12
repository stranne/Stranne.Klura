import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/bridges/logic/bridge_arrangement.dart';
import 'package:klura/puzzles/bridges/logic/bridges_puzzle.dart';
import 'package:klura/puzzles/bridges/logic/bridges_text.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';
import 'package:test/test.dart';

void main() {
  group('parseBridges', () {
    test('reads islands and bridges', () {
      final (:puzzle, :arrangement) = parseBridges('''
3=2.1
|....
2---1
''');

      expect(
        puzzle,
        BridgesPuzzle(
          width: 5,
          height: 3,
          islands: const [
            Island(Position(0, 0), 3),
            Island(Position(2, 0), 2),
            Island(Position(4, 0), 1),
            Island(Position(0, 2), 2),
            Island(Position(4, 2), 1),
          ],
        ),
      );
      expect(
        arrangement,
        BridgeArrangement({
          Connection(const Position(0, 0), const Position(2, 0)): 2,
          Connection(const Position(0, 0), const Position(0, 2)): 1,
          Connection(const Position(0, 2), const Position(4, 2)): 1,
        }),
      );
    });

    test('reads double vertical bridges and crossings', () {
      final (:puzzle, :arrangement) = parseBridges('''
..2..
..║..
1-╫-1
..║..
2=╬=2
..║..
..2..
''');

      expect(puzzle.islands, hasLength(6));
      expect(arrangement.bridges, {
        Connection(const Position(2, 0), const Position(2, 6)): 2,
        Connection(const Position(0, 2), const Position(4, 2)): 1,
        Connection(const Position(0, 4), const Position(4, 4)): 2,
      });
    });

    test('ignores indentation and blank lines around the board', () {
      final (:puzzle, :arrangement) = parseBridges('''

        1-1

      ''');

      expect(puzzle.width, 3);
      expect(puzzle.height, 1);
      expect(arrangement.connections, hasLength(1));
    });

    group('rejects', () {
      final cases = {
        'an empty board': '\n  \n',
        'an unknown character': '1x1',
        'rows of different lengths': '1.1\n..\n',
        'a bridge that ends in water': '1-.',
        'a bridge that leaves the board': '..|\n..1\n',
        'a bridge of mixed counts': '1-=1',
        'a crossing with mixed counts': '.2.\n1┼1\n.║.\n.2.\n',
      };

      for (final MapEntry(key: description, value: text) in cases.entries) {
        test(description, () {
          expect(() => parseBridges(text), throwsFormatException);
        });
      }
    });
  });

  group('formatBridges', () {
    final fixtures = {
      'a puzzle without bridges': '''
.2.3.
.....
2.1.1
''',
      'single and double bridges': '''
3=2.1
|....
2---1
''',
      'crossings of every kind': '''
..2...2..
..|...║..
1-┼-1.║..
..|...║..
..|.1-╫-1
..|...║..
2=╪=2.║..
..|...║..
..2...2..
..║......
2=╬=2....
..║......
..2......
''',
    };

    for (final MapEntry(key: description, value: text) in fixtures.entries) {
      test('round-trips $description', () {
        final (:puzzle, :arrangement) = parseBridges(text);

        expect(formatBridges(puzzle, arrangement), text);
      });
    }

    test('draws only the islands when given no bridges', () {
      final (:puzzle, arrangement: _) = parseBridges('3=2\n|..\n1..\n');

      expect(formatBridges(puzzle), '3.2\n...\n1..\n');
    });

    test('rejects bridges the puzzle does not offer', () {
      final (:puzzle, arrangement: _) = parseBridges('1.1.1');
      final overIsland = BridgeArrangement({
        Connection(const Position(0, 0), const Position(4, 0)): 1,
      });

      expect(() => formatBridges(puzzle, overIsland), throwsArgumentError);
    });
  });
}
