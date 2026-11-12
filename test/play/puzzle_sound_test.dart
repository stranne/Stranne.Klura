import 'package:klura/play/puzzle_sound.dart';
import 'package:test/test.dart';

void main() {
  test('every sound but the solve fades before a next move could begin', () {
    for (final sound in PuzzleSound.values) {
      if (sound == PuzzleSound.solved) {
        continue;
      }
      expect(
        _lengthOf(sound),
        lessThanOrEqualTo(const Duration(milliseconds: 200)),
        reason: sound.name,
      );
    }
  });

  test('the solve chimes for about as long as the wave on the board', () {
    expect(
      _lengthOf(PuzzleSound.solved),
      allOf(
        greaterThanOrEqualTo(const Duration(milliseconds: 1000)),
        lessThanOrEqualTo(const Duration(milliseconds: 1600)),
      ),
    );
  });

  test('every voice can be played as an exponential fade', () {
    // Web Audio's exponential ramps need levels and pitches above zero.
    for (final sound in PuzzleSound.values) {
      expect(sound.voices, isNotEmpty, reason: sound.name);
      for (final voice in sound.voices) {
        expect(voice.gain, inExclusiveRange(0, 1), reason: sound.name);
        expect(voice.length, greaterThan(Duration.zero), reason: sound.name);
        expect(
          voice.delay,
          greaterThanOrEqualTo(Duration.zero),
          reason: sound.name,
        );
        for (final pitch in [voice.frequency, voice.frequency * voice.glide]) {
          expect(pitch, inInclusiveRange(100, 8000), reason: sound.name);
        }
        if (voice case Pluck(:final overtone)) {
          expect(overtone, inInclusiveRange(0, 1), reason: sound.name);
        }
      }
    }
  });
}

/// When the last voice of [sound] has faded away.
Duration _lengthOf(PuzzleSound sound) => sound.voices
    .map((voice) => voice.delay + voice.length)
    .reduce((longest, end) => end > longest ? end : longest);
