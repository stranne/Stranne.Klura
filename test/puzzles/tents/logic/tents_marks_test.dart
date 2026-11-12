import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/tents/logic/tents_marks.dart';
import 'package:test/test.dart';

void main() {
  test('starts empty', () {
    const marks = TentsMarks.empty();

    expect(marks.isEmpty, isTrue);
    expect(marks[const Position(0, 0)], isNull);
  });

  test('lists tents and grass in reading order', () {
    final marks = TentsMarks({
      const Position(2, 1): TentsMark.tent,
      const Position(0, 1): TentsMark.grass,
      const Position(3, 0): TentsMark.tent,
      const Position(1, 0): TentsMark.grass,
    });

    expect(marks.tents, const [Position(3, 0), Position(2, 1)]);
    expect(marks.grass, const [Position(1, 0), Position(0, 1)]);
    expect(marks.marks.keys, const [
      Position(1, 0),
      Position(3, 0),
      Position(0, 1),
      Position(2, 1),
    ]);
  });

  test('returns a copy with marks set or cleared', () {
    final marks = TentsMarks({const Position(0, 0): TentsMark.tent});

    final changed = marks.withMark(const [
      Position(1, 0),
      Position(2, 0),
    ], TentsMark.grass);
    final cleared = changed.withMark(const [Position(0, 0)], null);

    expect(marks.tents, const [Position(0, 0)]);
    expect(changed.grass, const [Position(1, 0), Position(2, 0)]);
    expect(changed[const Position(0, 0)], TentsMark.tent);
    expect(cleared[const Position(0, 0)], isNull);
    expect(cleared.tents, isEmpty);
  });

  test('equals marks on the same cells, whatever their order', () {
    final first = TentsMarks({
      const Position(0, 0): TentsMark.tent,
      const Position(1, 1): TentsMark.grass,
    });
    final second = TentsMarks({
      const Position(1, 1): TentsMark.grass,
      const Position(0, 0): TentsMark.tent,
    });

    expect(second, first);
    expect(second.hashCode, first.hashCode);
    expect(
      first.withMark(const [Position(1, 1)], TentsMark.tent),
      isNot(first),
    );
    expect(first.withMark(const [Position(0, 0)], null), isNot(first));
  });
}
