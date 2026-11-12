import 'package:klura/core/grid.dart';
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
    test('touches the eight cells around it, diagonals included', () {
      const position = Position(2, 2);

      final touched = [
        for (var y = 0; y < 5; y++)
          for (var x = 0; x < 5; x++)
            if (position.touches(Position(x, y))) Position(x, y),
      ];

      expect(touched, const [
        Position(1, 1),
        Position(2, 1),
        Position(3, 1),
        Position(1, 2),
        Position(3, 2),
        Position(1, 3),
        Position(2, 3),
        Position(3, 3),
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
}
