import 'package:material_ui/material_ui.dart';

/// A calm sea teal that the light and dark color schemes derive from.
const Color _seedColor = Color(0xFF2F7F86);

/// Builds the app theme for [brightness].
ThemeData buildKluraTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
  );
  return ThemeData(colorScheme: colorScheme);
}
