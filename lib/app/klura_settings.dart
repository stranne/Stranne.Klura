import 'package:flutter/foundation.dart';
import 'package:klura/core/local_store.dart';

/// The player's choices for every puzzle, kept on the device.
final class KluraSettings extends ChangeNotifier {
  KluraSettings(LocalStore store)
    : _store = store,
      _showTimer = store.read(_showTimerKey) != 'false',
      _playSounds = store.read(_playSoundsKey) != 'false';

  static const String _showTimerKey = 'klura.showTimer';
  static const String _playSoundsKey = 'klura.playSounds';

  final LocalStore _store;
  bool _showTimer;
  bool _playSounds;

  /// Whether puzzles show the time played. The time counts either way, so
  /// showing it again gives the true time.
  bool get showTimer => _showTimer;

  set showTimer(bool show) {
    if (show == _showTimer) {
      return;
    }
    _showTimer = show;
    _save(_showTimerKey, show);
  }

  /// Whether moves on the board make their soft sounds.
  bool get playSounds => _playSounds;

  set playSounds(bool play) {
    if (play == _playSounds) {
      return;
    }
    _playSounds = play;
    _save(_playSoundsKey, play);
  }

  void _save(String key, bool value) {
    _store.write(key, '$value');
    notifyListeners();
  }
}
