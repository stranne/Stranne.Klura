import 'package:klura/app/browser_sound_stub.dart'
    if (dart.library.js_interop) 'package:klura/app/browser_sound.dart';
import 'package:klura/app/browser_store_stub.dart'
    if (dart.library.js_interop) 'package:klura/app/browser_store.dart';
import 'package:klura/app/klura_app.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  runApp(KluraApp(store: openBrowserStore(), sound: openBrowserSound()));
}
