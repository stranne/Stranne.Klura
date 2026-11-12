import 'dart:async';

import 'package:klura/app/klura_settings.dart';
import 'package:klura/app/klura_theme.dart';
import 'package:klura/core/calendar_date.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/home/home_screen.dart';
import 'package:klura/puzzles/bridges/bridges_daily_games.dart';
import 'package:klura/puzzles/bridges/bridges_screen.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_storage.dart';
import 'package:material_ui/material_ui.dart';

class KluraApp extends StatefulWidget {
  const KluraApp({required this.store, this.clock = DateTime.now, super.key});

  /// Where progress and settings are saved. It is read once.
  final LocalStore store;

  /// Reads the local date and time, whose date picks the daily puzzles.
  ///
  /// The app checks the date again when it comes back to the front, at
  /// midnight and when a puzzle closes, and then moves on to the new day's
  /// puzzles. A started game on screen is never replaced: the move waits
  /// until it closes.
  final DateTime Function() clock;

  @override
  State<KluraApp> createState() => _KluraAppState();
}

class _KluraAppState extends State<KluraApp> {
  late final KluraSettings _settings = KluraSettings(widget.store);
  late final BridgesStorage _storage = BridgesStorage(widget.store);
  late final ValueNotifier<BridgesDailyGames> _bridges = ValueNotifier(
    BridgesDailyGames(widget.clock(), _storage),
  );
  late final AppLifecycleListener _lifecycle;
  Timer? _midnightCheck;

  /// The level of each open puzzle screen; normally at most one.
  final List<BridgesLevel> _openLevels = [];

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _followDate);
    _scheduleMidnightCheck();
  }

  @override
  void dispose() {
    _midnightCheck?.cancel();
    _lifecycle.dispose();
    _bridges.value.dispose();
    _bridges.dispose();
    _settings.dispose();
    super.dispose();
  }

  /// Whether an open puzzle screen shows a game the player has begun.
  bool get _showsStartedGame => _openLevels.any(
    (level) => _bridges.value.started(level)?.isStarted ?? false,
  );

  /// Moves on to the puzzles of the clock's date if it has changed, unless
  /// a started game is open.
  ///
  /// The home screen and any untouched puzzle on screen switch to the new
  /// day at once.
  void _followDate() {
    if (!mounted) {
      return;
    }
    _scheduleMidnightCheck();
    final today = widget.clock();
    final previous = _bridges.value;
    if (calendarDaysBetween(previous.date, today) == 0 || _showsStartedGame) {
      return;
    }
    previous.stopSaving();
    _bridges.value = BridgesDailyGames(today, _storage);
    // The screens let go of the previous games in the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  /// Checks the date just after the next midnight, for an app that stays in
  /// front across it.
  void _scheduleMidnightCheck() {
    _midnightCheck?.cancel();
    final now = widget.clock();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _midnightCheck = Timer(nextDay.difference(now), _followDate);
  }

  /// Builds the route named in [settings]: `/` for the home screen and
  /// `/bridges/<level>` for a daily Bridges puzzle, or `null` for any other.
  Route<void>? _route(RouteSettings settings) {
    if (settings.name == Navigator.defaultRouteName) {
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => ValueListenableBuilder(
          valueListenable: _bridges,
          builder: (context, bridges, _) => HomeScreen(
            today: bridges.date,
            bridges: bridges,
            settings: _settings,
          ),
        ),
      );
    }
    for (final level in BridgesLevel.values) {
      if (settings.name == bridgesRouteName(level)) {
        return _bridgesRoute(level, settings);
      }
    }
    return null;
  }

  /// Shows the day's game at [level] and checks the date once the screen
  /// has closed, in case the move to a new day waited for it.
  Route<void> _bridgesRoute(BridgesLevel level, RouteSettings settings) {
    final route = MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => ValueListenableBuilder(
        valueListenable: _bridges,
        builder: (context, bridges, _) {
          final controller = bridges.open(level);
          return BridgesScreen(
            key: ObjectKey(controller),
            controller: controller,
            settings: _settings,
          );
        },
      ),
    );
    _openLevels.add(level);
    unawaited(
      route.completed.whenComplete(() {
        _openLevels.remove(level);
        _followDate();
      }),
    );
    return route;
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
