import 'package:flutter/material.dart';
import 'package:klura/app/browser_store_stub.dart'
    if (dart.library.js_interop) 'package:klura/app/browser_store.dart';
import 'package:klura/app/klura_app.dart';

void main() {
  runApp(KluraApp(today: DateTime.now(), store: openBrowserStore()));
}
