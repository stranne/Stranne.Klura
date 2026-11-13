/// A short sound that answers one of the player's moves on a board.
///
/// Only moves make sounds: undo, start over, the buttons and moving the
/// focus stay silent, so the player hears what they did and nothing else.
/// Every sound but [solved] fades within 200 ms, before a next move could
/// begin.
enum PuzzleSound {
  /// A first bridge between two islands: one soft pluck.
  bridge([Pluck(_e5, gain: 0.32, length: Duration(milliseconds: 110))]),

  /// A second bridge beside the first: two rising plucks, like its two
  /// lines.
  doubleBridge([
    Pluck(_e5, gain: 0.28, length: Duration(milliseconds: 100)),
    Pluck(
      _g5,
      gain: 0.28,
      length: Duration(milliseconds: 120),
      delay: Duration(milliseconds: 55),
    ),
  ]),

  /// Bridges, a tent or a line of grass taken away: lower and falling, so a
  /// slip is heard.
  removed([
    Pluck(
      _c5,
      gain: 0.22,
      length: Duration(milliseconds: 90),
      glide: 0.85,
      overtone: 0.05,
    ),
  ]),

  /// A bridge that would cross another, or a log pushed against another: a
  /// muted low knock with the shake, never a buzzer.
  blocked([
    Pluck(
      196,
      gain: 0.42,
      length: Duration(milliseconds: 150),
      glide: 0.72,
      overtone: 0,
      waveform: Waveform.triangle,
    ),
  ]),

  /// Grass on one cell: a faint brush, since grass is only a note.
  grass([Brush(gain: 0.09, length: Duration(milliseconds: 35))]),

  /// Grass along a row or column: one longer, rising brush for the whole
  /// move.
  grassLine([
    Brush(
      gain: 0.08,
      length: Duration(milliseconds: 160),
      frequency: 2600,
      glide: 2,
    ),
  ]),

  /// A tent: a pluck, a little brighter than a bridge.
  tent([
    Pluck(
      _g5,
      gain: 0.3,
      length: Duration(milliseconds: 130),
      overtone: 0.3,
      waveform: Waveform.triangle,
    ),
  ]),

  /// A log of two cells slid along the water: a soft wooden tock with a
  /// faint wash of water, far lower than the grass.
  log([
    Pluck(
      _a4,
      gain: 0.26,
      length: Duration(milliseconds: 110),
      glide: 0.92,
      overtone: 0.1,
      waveform: Waveform.triangle,
    ),
    Brush(
      gain: 0.07,
      length: Duration(milliseconds: 120),
      frequency: 900,
      glide: 0.7,
    ),
  ]),

  /// A log of three cells: the same tock a fourth lower, so a heavier log
  /// sounds heavier.
  longLog([
    Pluck(
      _e4,
      gain: 0.28,
      length: Duration(milliseconds: 130),
      glide: 0.92,
      overtone: 0.1,
      waveform: Waveform.triangle,
    ),
    Brush(
      gain: 0.07,
      length: Duration(milliseconds: 140),
      frequency: 800,
      glide: 0.7,
    ),
  ]),

  /// The move that solves the puzzle: a rising chime of five notes that
  /// keeps pace with the wave across the board.
  solved([
    Pluck(_c5, gain: 0.2, length: _chimeLength, overtone: 0.12),
    Pluck(
      _e5,
      gain: 0.2,
      length: _chimeLength,
      overtone: 0.12,
      delay: Duration(milliseconds: 140),
    ),
    Pluck(
      _g5,
      gain: 0.2,
      length: _chimeLength,
      overtone: 0.12,
      delay: Duration(milliseconds: 280),
    ),
    Pluck(
      _a5,
      gain: 0.2,
      length: _chimeLength,
      overtone: 0.12,
      delay: Duration(milliseconds: 420),
    ),
    Pluck(
      _c6,
      gain: 0.2,
      length: _chimeLength,
      overtone: 0.12,
      delay: Duration(milliseconds: 620),
    ),
  ]);

  const PuzzleSound(this.voices);

  /// What the sound is made of, each part starting after its own delay.
  final List<SoundVoice> voices;
}

/// Where the sounds of moves are heard.
abstract interface class SoundOutput {
  /// Plays [sound] at once, or does nothing where there is no audio.
  void play(PuzzleSound sound);
}

/// A [SoundOutput] that stays silent, where there is no audio.
final class SilentSoundOutput implements SoundOutput {
  const SilentSoundOutput();

  @override
  void play(PuzzleSound sound) {}
}

/// One part of a [PuzzleSound], which begins [delay] after the sound starts,
/// rises at once to [gain] and fades away over [length].
sealed class SoundVoice {
  const SoundVoice({
    required this.gain,
    required this.length,
    required this.frequency,
    required this.glide,
    this.delay = Duration.zero,
  });

  /// How loud the voice peaks, from 0 to 1, before the output's own volume.
  final double gain;

  /// How long the voice takes to fade away.
  final Duration length;

  /// The pitch in hertz where the voice begins.
  final double frequency;

  /// The pitch the voice has reached by its end, as a share of [frequency]:
  /// below 1 it falls and above 1 it rises.
  final double glide;

  final Duration delay;
}

/// A plucked tone with a softer overtone an octave above.
final class Pluck extends SoundVoice {
  const Pluck(
    double frequency, {
    required super.gain,
    required super.length,
    super.glide = 1,
    super.delay,
    this.overtone = 0.2,
    this.waveform = Waveform.sine,
  }) : super(frequency: frequency);

  /// How loud the overtone is, as a share of the tone.
  final double overtone;

  final Waveform waveform;
}

/// A soft brush of noise around a pitch, like a stroke over grass.
final class Brush extends SoundVoice {
  const Brush({
    required super.gain,
    required super.length,
    super.frequency = 4200,
    super.glide = 1,
    super.delay,
  });
}

/// The shape of a [Pluck]'s wave: a sine is round and pure, a triangle a
/// little woodier.
enum Waveform { sine, triangle }

/// How long each note of the solve chime rings.
const Duration _chimeLength = Duration(milliseconds: 900);

// Notes of the C major pentatonic scale, in hertz, so any of them sound well
// together.
const double _e4 = 329.63;
const double _a4 = 440;
const double _c5 = 523.25;
const double _e5 = 659.25;
const double _g5 = 783.99;
const double _a5 = 880;
const double _c6 = 1046.5;
