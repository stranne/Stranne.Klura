import 'dart:convert';

/// A small deterministic pseudo-random number generator (Mulberry32).
///
/// Puzzles are generated on the player's device from a seed key, so every
/// platform must produce exactly the same sequence for the same key.
/// `dart:math` `Random` does not promise a stable sequence across SDK
/// releases, and integer arithmetic differs between JavaScript (53-bit
/// doubles) and native or WebAssembly (64-bit integers). This generator keeps
/// every intermediate value within 32 bits so all targets agree.
///
/// Use this class, never `dart:math` `Random`, in puzzle generation.
class SeededRandom {
  SeededRandom(int seed) : _state = seed & _mask32;

  /// Creates a generator from a text key such as `bridges:v1:2026-11-11`.
  factory SeededRandom.fromKey(String key) => SeededRandom(hashKey(key));

  /// The largest supported bound for [nextInt].
  ///
  /// Keeping the bound small keeps `nextUint32() * max` below 2^53, where
  /// JavaScript numbers stay exact.
  static const int maxBound = 1 << 20;

  static const int _mask32 = 0xFFFFFFFF;
  static const int _two32 = 0x100000000;

  int _state;

  /// Hashes [key] to a 32-bit seed with FNV-1a over its UTF-8 bytes.
  static int hashKey(String key) {
    var hash = 0x811C9DC5;
    for (final byte in utf8.encode(key)) {
      hash = _multiply32(hash ^ byte, 0x01000193);
    }
    return hash;
  }

  /// Returns the next value in the range `0 <= value < 2^32`.
  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & _mask32;
    var mixed = _multiply32(_state ^ (_state >>> 15), _state | 1);
    final added = mixed + _multiply32(mixed ^ (mixed >>> 7), mixed | 61);
    mixed = mixed ^ (added & _mask32);
    return mixed ^ (mixed >>> 14);
  }

  /// Returns a value in the range `0 <= value < max`.
  ///
  /// [max] must be between 1 and [maxBound]. The multiply-shift mapping has a
  /// bias below one in four thousand, which is irrelevant for puzzle layout.
  int nextInt(int max) {
    RangeError.checkValueInInterval(max, 1, maxBound, 'max');
    return nextUint32() * max ~/ _two32;
  }

  /// Returns a value in the range `0.0 <= value < 1.0`.
  double nextDouble() => nextUint32() / _two32;

  /// Returns `true` with the given [probability].
  bool nextChance(double probability) => nextDouble() < probability;

  /// Shuffles [items] in place with the Fisher-Yates algorithm.
  ///
  /// `List.shuffle` is not used because its algorithm is not part of its
  /// contract and could change between SDK releases.
  void shuffle<T>(List<T> items) {
    for (var index = items.length - 1; index > 0; index--) {
      final swapIndex = nextInt(index + 1);
      final item = items[index];
      items[index] = items[swapIndex];
      items[swapIndex] = item;
    }
  }

  /// Multiplies two 32-bit values modulo 2^32, like JavaScript `Math.imul`.
  ///
  /// The operands are split into 16-bit halves so no partial product exceeds
  /// what a JavaScript number represents exactly.
  static int _multiply32(int left, int right) {
    final leftHigh = left >>> 16;
    final leftLow = left & 0xFFFF;
    final rightHigh = right >>> 16;
    final rightLow = right & 0xFFFF;
    final crossTerms = (leftHigh * rightLow + leftLow * rightHigh) & 0xFFFF;
    return (leftLow * rightLow + (crossTerms << 16)) & _mask32;
  }
}
