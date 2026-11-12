import 'package:klura/play/puzzle_sound.dart';

/// Stays silent where there is no browser audio, such as on the Dart VM.
///
/// `main.dart` imports `browser_sound.dart` instead on the web.
SoundOutput openBrowserSound() => const SilentSoundOutput();
