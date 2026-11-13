import 'dart:async';

import 'package:klura/app/klura_settings.dart';
import 'package:klura/app/klura_theme.dart';
import 'package:klura/core/calendar_date.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/home/home_screen.dart';
import 'package:klura/play/puzzle_sound.dart';
import 'package:klura/puzzles/bridges/bridges_daily_games.dart';
import 'package:klura/puzzles/bridges/bridges_screen.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_storage.dart';
import 'package:klura/puzzles/logjam/logic/logjam_generator.dart';
import 'package:klura/puzzles/logjam/logic/logjam_storage.dart';
import 'package:klura/puzzles/logjam/logjam_daily_games.dart';
import 'package:klura/puzzles/logjam/logjam_screen.dart';
import 'package:klura/puzzles/tents/logic/tents_generator.dart';
import 'package:klura/puzzles/tents/logic/tents_storage.dart';
import 'package:klura/puzzles/tents/tents_daily_games.dart';
import 'package:klura/puzzles/tents/tents_screen.dart';
import 'package:material_ui/material_ui.dart';

class KluraApp extends StatefulWidget {
  const KluraApp({
    required this.store,
    this.sound = const SilentSoundOutput(),
    this.clock = DateTime.now,
    super.key,
  });

  /// Where progress and settings are saved. It is read once.
  final LocalStore store;

  /// Where the sounds of moves are heard, while the player has them on.
  final SoundOutput sound;

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

/// The games of every puzzle on one day.
final class _Day {
  _Day(
    this.date,
    BridgesStorage bridgesStorage,
    TentsStorage tentsStorage,
    LogjamStorage logjamStorage,
  ) : bridges = BridgesDailyGames(date, bridgesStorage),
      tents = TentsDailyGames(date, tentsStorage),
      logjam = LogjamDailyGames(date, logjamStorage);

  final DateTime date;
  final BridgesDailyGames bridges;
  final TentsDailyGames tents;
  final LogjamDailyGames logjam;

  void stopSaving() {
    bridges.stopSaving();
    tents.stopSaving();
    logjam.stopSaving();
  }

  void dispose() {
    bridges.dispose();
    tents.dispose();
    logjam.dispose();
  }
}

class _KluraAppState extends State<KluraApp> {
  late final KluraSettings _settings = KluraSettings(widget.store);
  late final BridgesStorage _bridgesStorage = BridgesStorage(widget.store);
  late final TentsStorage _tentsStorage = TentsStorage(widget.store);
  late final LogjamStorage _logjamStorage = LogjamStorage(widget.store);
  late final ValueNotifier<_Day> _day = ValueNotifier(_newDay(widget.clock()));
  late final AppLifecycleListener _lifecycle;
  Timer? _midnightCheck;

  /// Whether each open puzzle screen shows a game the player has begun;
  /// normally there is at most one.
  final List<bool Function()> _openGames = [];

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
    _day.value.dispose();
    _day.dispose();
    _settings.dispose();
    super.dispose();
  }

  _Day _newDay(DateTime date) =>
      _Day(date, _bridgesStorage, _tentsStorage, _logjamStorage);

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
    final previous = _day.value;
    if (calendarDaysBetween(previous.date, today) == 0 ||
        _openGames.any((isStarted) => isStarted())) {
      return;
    }
    previous.stopSaving();
    _day.value = _newDay(today);
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

  /// Builds the route named in [settings]: `/` for the home screen,
  /// `/bridges/<level>` for a daily Bridges puzzle, `/tents/<level>` for a
  /// daily Tents puzzle and `/logjam/<level>` for a daily Logjam puzzle, or
  /// `null` for any other.
  Route<void>? _route(RouteSettings settings) {
    if (settings.name == Navigator.defaultRouteName) {
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => ValueListenableBuilder(
          valueListenable: _day,
          builder: (context, day, _) => HomeScreen(
            today: day.date,
            bridges: day.bridges,
            tents: day.tents,
            logjam: day.logjam,
            settings: _settings,
          ),
        ),
      );
    }
    for (final level in BridgesLevel.values) {
      if (settings.name == bridgesRouteName(level)) {
        return _puzzleRoute(
          settings,
          isStarted: (day) => day.bridges.started(level)?.isStarted ?? false,
          screen: (day) {
            final controller = day.bridges.open(level);
            return BridgesScreen(
              key: ObjectKey(controller),
              controller: controller,
              settings: _settings,
              sound: widget.sound,
            );
          },
        );
      }
    }
    for (final level in TentsLevel.values) {
      if (settings.name == tentsRouteName(level)) {
        return _puzzleRoute(
          settings,
          isStarted: (day) => day.tents.started(level)?.isStarted ?? false,
          screen: (day) {
            final controller = day.tents.open(level);
            return TentsScreen(
              key: ObjectKey(controller),
              controller: controller,
              settings: _settings,
              sound: widget.sound,
            );
          },
        );
      }
    }
    for (final level in LogjamLevel.values) {
      if (settings.name == logjamRouteName(level)) {
        return _puzzleRoute(
          settings,
          isStarted: (day) => day.logjam.started(level)?.isStarted ?? false,
          screen: (day) {
            final controller = day.logjam.open(level);
            return LogjamScreen(
              key: ObjectKey(controller),
              controller: controller,
              settings: _settings,
              sound: widget.sound,
            );
          },
        );
      }
    }
    return null;
  }

  /// Shows the [screen] of a day's game and checks the date once it has
  /// closed, in case the move to a new day waited for it. While it is open,
  /// [isStarted] tells whether the player has begun its game.
  Route<void> _puzzleRoute(
    RouteSettings settings, {
    required Widget Function(_Day day) screen,
    required bool Function(_Day day) isStarted,
  }) {
    final route = MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => ValueListenableBuilder(
        valueListenable: _day,
        builder: (context, day, _) => screen(day),
      ),
    );
    bool showsStartedGame() => isStarted(_day.value);
    _openGames.add(showsStartedGame);
    unawaited(
      route.completed.whenComplete(() {
        _openGames.remove(showsStartedGame);
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
