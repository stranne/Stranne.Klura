import 'dart:js_interop';

import 'package:klura/core/local_store.dart';

/// Opens the browser's local storage, or a store in memory for the session
/// if the browser blocks it.
///
/// Every puzzle shares the storage of the site's origin, which on GitHub
/// Pages also holds the owner's other projects, so keys start with `klura.`.
LocalStore openBrowserStore() {
  try {
    // Reading localStorage throws where the browser blocks site data.
    if (_localStorage case final storage?) {
      return _BrowserStore(storage);
    }
  } on Object {
    // Fall back to memory below.
  }
  return MemoryLocalStore();
}

@JS('localStorage')
external _Storage? get _localStorage;

/// The browser's `Storage` interface.
extension type _Storage._(JSObject _) implements JSObject {
  external int get length;
  external String? key(int index);
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

/// A [LocalStore] over the browser's local storage that never throws: a
/// read that fails finds nothing, and a write that fails, for example on
/// full storage, is lost while the game goes on from memory.
final class _BrowserStore implements LocalStore {
  _BrowserStore(this._storage);

  final _Storage _storage;

  @override
  String? read(String key) {
    try {
      return _storage.getItem(key);
    } on Object {
      return null;
    }
  }

  @override
  void write(String key, String value) {
    try {
      _storage.setItem(key, value);
    } on Object {
      // Storage is full or blocked; see the class documentation.
    }
  }

  @override
  void remove(String key) {
    try {
      _storage.removeItem(key);
    } on Object {
      // Storage is blocked; the value stays until a later write.
    }
  }

  @override
  List<String> get keys {
    try {
      return [
        for (var index = 0; index < _storage.length; index++)
          ?_storage.key(index),
      ];
    } on Object {
      return const [];
    }
  }
}
