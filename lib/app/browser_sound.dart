import 'dart:js_interop';
import 'dart:typed_data';

import 'package:klura/core/seeded_random.dart';
import 'package:klura/play/puzzle_sound.dart';

/// Plays the sounds of moves through the browser's Web Audio.
///
/// The audio opens with the first sound, which always answers a tap or a
/// key: browsers let a page make sound only once the player has used it.
/// Where the browser has no audio, the game goes on in silence.
SoundOutput openBrowserSound() => _WebAudioOutput();

/// How loud every sound is, on top of each voice's own gain.
const double _volume = 0.3;

/// Softens the top of every sound, so none of them is sharp.
const double _softenAbove = 4200;

/// How far ahead each sound starts, so its first moment is never cut off.
const double _lead = 0.005;

/// How long a pluck takes to rise to its gain, and a brush.
const double _pluckAttack = 0.004;
const double _brushAttack = 0.01;

/// How narrow the band of noise in a brush is.
const double _brushQ = 0.9;

/// How long the noise a brush plays from lasts, longer than any brush.
const double _noiseLength = 0.25;

/// The quietest level a fade reaches before it ends. Fades are exponential,
/// so they can never reach zero itself.
const double _silence = 0.0001;

final class _WebAudioOutput implements SoundOutput {
  _Speaker? _speaker;

  @override
  void play(PuzzleSound sound) {
    try {
      (_speaker ??= _Speaker.open()).play(sound);
    } on Object {
      // Sound only adds to what the board already shows, so a browser
      // without audio plays on in silence.
    }
  }
}

/// The browser's audio: every voice runs through one volume and a gentle
/// low-pass filter.
final class _Speaker {
  _Speaker._(this._context, this._input, this._noise);

  factory _Speaker.open() {
    _mixWithOtherAudio();
    final context = _AudioContext();
    final volume = context.createGain()..gain.value = _volume;
    final soften = context.createBiquadFilter()
      ..type = 'lowpass'
      ..frequency.value = _softenAbove;
    volume.connect(soften).connect(context.destination);
    // Lets the device rest its audio while the page is out of sight. The
    // next sound wakes it again.
    _document.addEventListener(
      'visibilitychange',
      ((JSAny? _) {
        if (_document.hidden) {
          context.suspend().toDart.ignore();
        }
      }).toJS,
    );
    return _Speaker._(context, volume, _noiseBuffer(context));
  }

  final _AudioContext _context;

  /// Where every voice goes.
  final _AudioNode _input;

  /// White noise for the brushes.
  final _AudioBuffer _noise;

  void play(PuzzleSound sound) {
    if (_context.state != 'running') {
      _context.resume().toDart.ignore();
    }
    final start = _context.currentTime + _lead;
    for (final voice in sound.voices) {
      final at = start + _seconds(voice.delay);
      final end = at + _seconds(voice.length);
      switch (voice) {
        case Pluck():
          _pluck(voice, at, end);
        case Brush():
          _brush(voice, at, end);
      }
    }
  }

  void _pluck(Pluck pluck, double at, double end) {
    final envelope = _envelope(pluck, _pluckAttack, at, end);
    final partials = [(1, 1.0), if (pluck.overtone > 0) (2, pluck.overtone)];
    for (final (multiple, gain) in partials) {
      final oscillator = _context.createOscillator()
        ..type = pluck.waveform.name;
      _sweep(oscillator.frequency, pluck, multiple, at, end);
      final level = _context.createGain()..gain.value = gain;
      oscillator.connect(level).connect(envelope);
      oscillator
        ..start(at)
        ..stop(end);
    }
  }

  void _brush(Brush brush, double at, double end) {
    final source = _context.createBufferSource()..buffer = _noise;
    final band = _context.createBiquadFilter()..type = 'bandpass';
    band.q.value = _brushQ;
    _sweep(band.frequency, brush, 1, at, end);
    source.connect(band).connect(_envelope(brush, _brushAttack, at, end));
    source
      ..start(at)
      ..stop(end);
  }

  /// Rises over [attack] to the gain of [voice] and fades away by [end].
  _AudioNode _envelope(SoundVoice voice, double attack, double at, double end) {
    final envelope = _context.createGain();
    envelope.gain
      ..setValueAtTime(_silence, at)
      ..exponentialRampToValueAtTime(voice.gain, at + attack)
      ..exponentialRampToValueAtTime(_silence, end);
    return envelope..connect(_input);
  }

  /// Moves [pitch] from [multiple] times the frequency of [voice] as far as
  /// its glide takes it by [end].
  void _sweep(
    _AudioParam pitch,
    SoundVoice voice,
    int multiple,
    double at,
    double end,
  ) {
    final frequency = voice.frequency * multiple;
    pitch.setValueAtTime(frequency, at);
    if (voice.glide != 1) {
      pitch.exponentialRampToValueAtTime(frequency * voice.glide, end);
    }
  }
}

/// White noise from a fixed seed, so every brush sounds the same.
_AudioBuffer _noiseBuffer(_AudioContext context) {
  final sampleRate = context.sampleRate;
  final random = SeededRandom.fromKey('klura.sound.noise');
  final samples = Float32List((sampleRate * _noiseLength).round());
  for (var index = 0; index < samples.length; index++) {
    samples[index] = random.nextDouble() * 2 - 1;
  }
  return context.createBuffer(1, samples.length, sampleRate)
    ..copyToChannel(samples.toJS, 0);
}

/// Asks the browser to mix the sounds with other audio, such as music the
/// player is listening to, instead of pausing it. Safari also keeps them
/// quiet while an iPhone's silent switch is on. Other browsers do not have
/// the Audio Session API and mix sounds anyway.
void _mixWithOtherAudio() {
  try {
    _navigator.audioSession?.type = 'ambient';
  } on Object {
    // Mixing is the default wherever the setting is missing.
  }
}

double _seconds(Duration duration) =>
    duration.inMicroseconds / Duration.microsecondsPerSecond;

@JS('document')
external _Document get _document;

@JS('navigator')
external _Navigator get _navigator;

extension type _Document._(JSObject _) implements JSObject {
  external bool get hidden;
  external void addEventListener(String type, JSFunction listener);
}

extension type _Navigator._(JSObject _) implements JSObject {
  external _AudioSession? get audioSession;
}

/// The Audio Session API, which only Safari has so far.
extension type _AudioSession._(JSObject _) implements JSObject {
  external String get type;
  external set type(String value);
}

@JS('AudioContext')
extension type _AudioContext._(JSObject _) implements JSObject {
  external _AudioContext();

  external double get currentTime;
  external double get sampleRate;
  external String get state;
  external _AudioNode get destination;
  external JSPromise<JSAny?> resume();
  external JSPromise<JSAny?> suspend();
  external _GainNode createGain();
  external _OscillatorNode createOscillator();
  external _BiquadFilterNode createBiquadFilter();
  external _AudioBufferSourceNode createBufferSource();
  external _AudioBuffer createBuffer(
    int numberOfChannels,
    int length,
    double sampleRate,
  );
}

extension type _AudioNode._(JSObject _) implements JSObject {
  /// Sends this node's output to [destination] and returns it, so that
  /// connections can be chained.
  external _AudioNode connect(_AudioNode destination);
}

extension type _AudioParam._(JSObject _) implements JSObject {
  external double get value;
  external set value(double value);
  external void setValueAtTime(double value, double time);
  external void exponentialRampToValueAtTime(double value, double time);
}

extension type _GainNode._(JSObject _) implements _AudioNode {
  external _AudioParam get gain;
}

extension type _OscillatorNode._(JSObject _) implements _AudioNode {
  external String get type;
  external set type(String value);
  external _AudioParam get frequency;
  external void start(double when);
  external void stop(double when);
}

extension type _BiquadFilterNode._(JSObject _) implements _AudioNode {
  external String get type;
  external set type(String value);
  external _AudioParam get frequency;
  @JS('Q')
  external _AudioParam get q;
}

extension type _AudioBufferSourceNode._(JSObject _) implements _AudioNode {
  external _AudioBuffer? get buffer;
  external set buffer(_AudioBuffer? value);
  external void start(double when);
  external void stop(double when);
}

extension type _AudioBuffer._(JSObject _) implements JSObject {
  external void copyToChannel(JSFloat32Array source, int channelNumber);
}
