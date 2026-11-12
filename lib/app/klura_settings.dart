import 'package:flutter/foundation.dart';
import 'package:klura/core/local_store.dart';

/// The player's choices for every puzzle, kept on the device.
final class KluraSettings extends ChangeNotifier {
  KluraSettings(LocalStore store)
    : _store = store,
      _showTimer = store.read(_showTimerKey) != 'false';

  static const String _showTimerKey = 'klura.showTimer';

  final LocalStore _store;
  bool _showTimer;

  /// Whether puzzles show the time played. The time counts either way, so
  /// showing it again gives the true time.
  bool get showTimer => _showTimer;

  set showTimer(bool show) {
    if (show == _showTimer) {
      return;
    }
    _showTimer = show;
    _store.write(_showTimerKey, '$show');
    notifyListeners();
  }
}
