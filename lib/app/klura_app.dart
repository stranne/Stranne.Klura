import 'package:flutter/material.dart';
import 'package:klura/app/klura_theme.dart';
import 'package:klura/home/home_screen.dart';
import 'package:klura/puzzles/bridges/bridges_daily_games.dart';
import 'package:klura/puzzles/bridges/bridges_screen.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';

class KluraApp extends StatefulWidget {
  const KluraApp({required this.today, super.key});

  /// The date the app started on. It picks the daily puzzles for the whole
  /// session, so a new day's puzzles appear on the next launch; a later
  /// date given to a rebuilt app is ignored.
  final DateTime today;

  @override
  State<KluraApp> createState() => _KluraAppState();
}

class _KluraAppState extends State<KluraApp> {
  late final BridgesDailyGames _bridges = BridgesDailyGames(widget.today);

  @override
  void dispose() {
    _bridges.dispose();
    super.dispose();
  }

  /// Builds the route named in [settings]: `/` for the home screen and
  /// `/bridges/<level>` for a daily Bridges puzzle, or `null` for any other.
  Route<void>? _route(RouteSettings settings) {
    if (settings.name == Navigator.defaultRouteName) {
      return MaterialPageRoute(
        settings: settings,
        builder: (context) =>
            HomeScreen(today: _bridges.date, bridges: _bridges),
      );
    }
    for (final level in BridgesLevel.values) {
      if (settings.name == bridgesRouteName(level)) {
        final controller = _bridges.open(level);
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => BridgesScreen(controller: controller),
        );
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Klura',
      debugShowCheckedModeBanner: false,
      theme: buildKluraTheme(Brightness.light),
      darkTheme: buildKluraTheme(Brightness.dark),
      onGenerateRoute: _route,
      onUnknownRoute: (settings) => _route(
        const RouteSettings(name: Navigator.defaultRouteName),
      ),
    );
  }
}
