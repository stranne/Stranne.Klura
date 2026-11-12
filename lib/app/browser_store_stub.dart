import 'package:klura/core/local_store.dart';

/// Opens a store in memory for the session, where there is no browser
/// storage, such as on the Dart VM.
///
/// `main.dart` imports `browser_store.dart` instead on the web.
LocalStore openBrowserStore() => MemoryLocalStore();
