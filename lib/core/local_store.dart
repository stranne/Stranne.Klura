/// Text values kept on the device under string keys, such as the browser's
/// local storage.
///
/// Storage is best effort. A browser may refuse to store anything, for
/// example in some private modes or when storage is full, so a write can be
/// lost without an error and the app keeps working from memory.
abstract interface class LocalStore {
  /// The value stored under [key], or `null` if there is none.
  String? read(String key);

  /// Stores [value] under [key], replacing any earlier value.
  void write(String key, String value);

  /// Removes the value under [key], if any.
  void remove(String key);

  /// Every key with a value, as a list that later changes do not affect.
  List<String> get keys;
}

/// A [LocalStore] that keeps its values in memory for the session only.
///
/// Tests use it, and the app falls back to it when the browser offers no
/// storage.
final class MemoryLocalStore implements LocalStore {
  MemoryLocalStore([Map<String, String> values = const {}])
    : _values = Map.of(values);

  final Map<String, String> _values;

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) => _values[key] = value;

  @override
  void remove(String key) => _values.remove(key);

  @override
  List<String> get keys => _values.keys.toList();
}
