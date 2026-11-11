import 'package:klura/core/seeded_random.dart';
import 'package:test/test.dart';

// Expected values come from JavaScript reference implementations (FNV-1a and
// Mulberry32 using Math.imul). Run these tests on the VM and compiled to
// JavaScript: a failure means platforms would generate different puzzles.
void main() {
  group('hashKey', () {
    const cases = {
      '': 0x811C9DC5,
      'a': 0xE40C292C,
      'foobar': 0xBF9CF968,
      'bridges:v1:2026-11-11': 0x246268AA,
      'Klura åäö': 0xA0F5E6FE,
    };

    for (final MapEntry(:key, :value) in cases.entries) {
      test('hashes "$key"', () {
        expect(SeededRandom.hashKey(key), value);
      });
    }
  });

  group('nextUint32', () {
    const cases = {
      0: [1144304738, 1416247, 958946056, 627933444, 2007157716],
      1: [2693262067, 11749833, 2265367787, 4213581821, 4159151403],
      0xFFFFFFFF: [3850105811, 813802916, 3073704848, 4054706436, 3630262831],
    };

    for (final MapEntry(key: seed, value: expected) in cases.entries) {
      test('matches the reference sequence for seed $seed', () {
        final random = SeededRandom(seed);

        final actual = List.generate(
          expected.length,
          (_) => random.nextUint32(),
        );

        expect(actual, expected);
      });
    }

    test('matches the reference after 100 000 values', () {
      final random = SeededRandom(12345);

      var value = 0;
      for (var count = 0; count < 100000; count++) {
        value = random.nextUint32();
      }

      expect(value, 4140998437);
    });

    test('seeds from the hash of a key', () {
      final random = SeededRandom.fromKey('bridges:v1:2026-11-11');

      expect(random.nextUint32(), 547071941);
    });
  });

  group('nextInt', () {
    test('matches the reference sequence', () {
      final random = SeededRandom(42);

      final actual = List.generate(8, (_) => random.nextInt(10));

      expect(actual, [6, 4, 8, 6, 1, 5, 2, 6]);
    });

    test('stays within the bound', () {
      final random = SeededRandom(7);

      final values = List.generate(1000, (_) => random.nextInt(3));

      expect(values.toSet(), {0, 1, 2});
    });

    test('rejects bounds outside the supported range', () {
      final random = SeededRandom(1);

      expect(() => random.nextInt(0), throwsRangeError);
      expect(() => random.nextInt(SeededRandom.maxBound + 1), throwsRangeError);
    });
  });

  group('shuffle', () {
    test('matches the reference order', () {
      final random = SeededRandom(42);
      final items = List.generate(10, (index) => index);

      random.shuffle(items);

      expect(items, [0, 7, 3, 5, 2, 1, 8, 9, 4, 6]);
    });

    test('handles empty and single-item lists', () {
      final random = SeededRandom(1);
      final empty = <int>[];
      final single = [5];

      random
        ..shuffle(empty)
        ..shuffle(single);

      expect(empty, isEmpty);
      expect(single, [5]);
    });
  });
}
