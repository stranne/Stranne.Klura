import 'package:klura/core/seeded_random.dart';
import 'package:klura/puzzles/tents/logic/pairing.dart';
import 'package:test/test.dart';

void main() {
  group('countPairs', () {
    test('moves an earlier pair aside to make room', () {
      // The first item takes 0, which the second needs, so it moves to 1.
      expect(
        countPairs([
          [0, 1],
          [0],
        ], 2),
        2,
      );
    });

    test('counts only the pairs the partners allow', () {
      expect(
        countPairs([
          [0],
          [0],
          [],
        ], 2),
        1,
      );
    });
  });

  group('findUnpaired', () {
    test('finds nothing when every item can have a partner', () {
      expect(
        findUnpaired([
          [0, 1],
          [0],
        ], 2),
        isEmpty,
      );
    });

    test('names every item of a group that outnumbers its partners', () {
      // Items 0, 1 and 2 share partners 0 and 1; item 3 has 2 to itself.
      expect(
        findUnpaired([
          [0],
          [0, 1],
          [1],
          [2],
        ], 3),
        [0, 1, 2],
      );
    });

    test('leaves out items that keep a partner however the rest pair', () {
      // Items 0 and 1 both need partner 0. Item 2 could take 0 as well,
      // but partner 1 is always free for it.
      expect(
        findUnpaired([
          [0],
          [0],
          [0, 1],
        ], 2),
        [0, 1],
      );
    });

    test('names an item with no partners at all', () {
      expect(
        findUnpaired([
          [0],
          [],
        ], 1),
        [1],
      );
    });

    test('names the items that some largest pairing leaves out', () {
      // An item can be left out exactly when the others still make as many
      // pairs without it.
      final random = SeededRandom(2026);
      for (var round = 0; round < 400; round++) {
        final firstCount = 1 + random.nextInt(7);
        final secondCount = 1 + random.nextInt(7);
        final partners = [
          for (var first = 0; first < firstCount; first++)
            [
              for (var second = 0; second < secondCount; second++)
                if (random.nextChance(0.3)) second,
            ],
        ];
        final pairs = countPairs(partners, secondCount);
        final expected = [
          for (var first = 0; first < firstCount; first++)
            if (countPairs(_without(partners, first), secondCount) == pairs)
              first,
        ];

        expect(
          findUnpaired(partners, secondCount),
          expected,
          reason: '$partners',
        );
      }
    });
  });
}

/// [partners] with the item [first] given no partners at all.
List<List<int>> _without(List<List<int>> partners, int first) => [
  for (final (index, items) in partners.indexed)
    if (index == first) [] else items,
];
