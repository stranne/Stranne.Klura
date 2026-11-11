import 'package:klura/puzzles/bridges/logic/geometry.dart';
import 'package:test/test.dart';

void main() {
  group('Position', () {
    test('steps one cell in each direction', () {
      const position = Position(2, 3);

      final steps = {
        for (final direction in Direction.values)
          direction: position.step(direction),
      };

      expect(steps, {
        Direction.up: const Position(2, 2),
        Direction.right: const Position(3, 3),
        Direction.down: const Position(2, 4),
        Direction.left: const Position(1, 3),
      });
    });

    test('knows whether it lies on a grid', () {
      expect(const Position(0, 0).isWithin(3, 2), isTrue);
      expect(const Position(2, 1).isWithin(3, 2), isTrue);
      expect(const Position(3, 1).isWithin(3, 2), isFalse);
      expect(const Position(1, 2).isWithin(3, 2), isFalse);
      expect(const Position(-1, 0).isWithin(3, 2), isFalse);
    });

    test('orders positions by row, then by column', () {
      final positions = [
        const Position(1, 1),
        const Position(0, 2),
        const Position(2, 0),
        const Position(0, 1),
      ]..sort();

      expect(positions, const [
        Position(2, 0),
        Position(0, 1),
        Position(1, 1),
        Position(0, 2),
      ]);
    });
  });

  group('Direction', () {
    test('knows its opposite and orientation', () {
      expect(Direction.up.opposite, Direction.down);
      expect(Direction.left.opposite, Direction.right);
      expect(Direction.left.isHorizontal, isTrue);
      expect(Direction.down.isHorizontal, isFalse);
    });
  });

  group('Connection', () {
    test('orders its ends in reading order', () {
      final horizontal = Connection(const Position(4, 1), const Position(1, 1));
      final vertical = Connection(const Position(2, 5), const Position(2, 0));

      expect(horizontal.start, const Position(1, 1));
      expect(horizontal.end, const Position(4, 1));
      expect(horizontal.isHorizontal, isTrue);
      expect(vertical.start, const Position(2, 0));
      expect(vertical.end, const Position(2, 5));
      expect(vertical.isHorizontal, isFalse);
    });

    test('equals the same connection created from the other end', () {
      final forward = Connection(const Position(0, 0), const Position(3, 0));
      final backward = Connection(const Position(3, 0), const Position(0, 0));

      expect(forward, backward);
      expect(forward.hashCode, backward.hashCode);
    });

    test('rejects ends that are equal or not in a line', () {
      expect(
        () => Connection(const Position(1, 1), const Position(1, 1)),
        throwsArgumentError,
      );
      expect(
        () => Connection(const Position(0, 0), const Position(2, 1)),
        throwsArgumentError,
      );
    });

    test('lists the cells between its ends', () {
      final horizontal = Connection(const Position(0, 2), const Position(3, 2));
      final vertical = Connection(const Position(1, 0), const Position(1, 2));

      expect(horizontal.cellsBetween, const [Position(1, 2), Position(2, 2)]);
      expect(vertical.cellsBetween, const [Position(1, 1)]);
    });

    test('touches only its ends', () {
      final connection = Connection(const Position(0, 0), const Position(2, 0));

      expect(connection.touches(const Position(0, 0)), isTrue);
      expect(connection.touches(const Position(2, 0)), isTrue);
      expect(connection.touches(const Position(1, 0)), isFalse);
    });

    group('crosses', () {
      final horizontal = Connection(const Position(0, 2), const Position(4, 2));

      final cases = [
        ('a perpendicular line through its middle', (2, 0, 2, 4), true),
        ('a perpendicular line ending on it', (2, 0, 2, 2), false),
        ('a perpendicular line at its end', (4, 0, 4, 4), false),
        ('a perpendicular line beside it', (5, 0, 5, 4), false),
        ('a parallel line', (0, 4, 4, 4), false),
      ];

      for (final (description, (x1, y1, x2, y2), expected) in cases) {
        test('${expected ? 'crosses' : 'does not cross'} $description', () {
          final other = Connection(Position(x1, y1), Position(x2, y2));

          expect(horizontal.crosses(other), expected);
          expect(other.crosses(horizontal), expected);
        });
      }
    });

    test('orders connections by start, then by end', () {
      final connections = [
        Connection(const Position(0, 1), const Position(2, 1)),
        Connection(const Position(0, 0), const Position(0, 2)),
        Connection(const Position(0, 0), const Position(2, 0)),
      ]..sort();

      expect(connections, [
        Connection(const Position(0, 0), const Position(2, 0)),
        Connection(const Position(0, 0), const Position(0, 2)),
        Connection(const Position(0, 1), const Position(2, 1)),
      ]);
    });
  });
}
