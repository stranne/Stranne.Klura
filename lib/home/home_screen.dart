import 'dart:async';

import 'package:klura/app/klura_settings.dart';
import 'package:klura/core/daily_storage.dart';
import 'package:klura/core/play_time.dart';
import 'package:klura/core/puzzle_game.dart';
import 'package:klura/play/daily_games.dart';
import 'package:klura/play/puzzle_controller.dart';
import 'package:klura/puzzles/bridges/bridges_daily_games.dart';
import 'package:klura/puzzles/bridges/bridges_screen.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/tents/logic/tents_generator.dart';
import 'package:klura/puzzles/tents/tents_daily_games.dart';
import 'package:klura/puzzles/tents/tents_screen.dart';
import 'package:material_ui/material_ui.dart';

/// Lists the puzzles of [today] and how far each has come.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.today,
    required this.bridges,
    required this.tents,
    required this.settings,
    super.key,
  });

  final DateTime today;

  /// Today's Bridges games, to open them and show how far each has come.
  final BridgesDailyGames bridges;

  /// Today's Tents games, likewise.
  final TentsDailyGames tents;

  /// Whether to show solve times.
  final KluraSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListenableBuilder(
              listenable: Listenable.merge([bridges, tents, settings]),
              builder: (context, _) => ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Klura', style: theme.textTheme.displaySmall),
                  const SizedBox(height: 4),
                  Text(
                    localizations.formatFullDate(today),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _PuzzleCard(
                    icon: Icons.hub_outlined,
                    title: 'Bridges',
                    description: 'Connect every island without making a loop.',
                    levels: [
                      for (final level in BridgesLevel.values)
                        (
                          title: bridgesLevelTitle(level),
                          size:
                              '${level.config.width} × ${level.config.height}'
                              ' · ${level.config.islandCount} islands',
                          status: _statusOf(bridges, level),
                          routeName: bridgesRouteName(level),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PuzzleCard(
                    icon: Icons.park_outlined,
                    title: 'Tents',
                    description: 'Give every tree a tent of its own.',
                    levels: [
                      for (final level in TentsLevel.values)
                        (
                          title: tentsLevelTitle(level),
                          size:
                              '${level.config.width} × ${level.config.height}'
                              ' · ${level.config.tentCount} tents',
                          status: _statusOf(tents, level),
                          routeName: tentsRouteName(level),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// How far today's game at [level] of [games] has come, or `null` if it
  /// has not started.
  ///
  /// A puzzle stays solved after a start over, since the solve stands.
  _Status? _statusOf<L extends Enum>(
    DailyGames<L, DailySave<L>, PuzzleController<L, PuzzleGame>> games,
    L level,
  ) {
    if (games.solveTime(level) case final time?) {
      return settings.showTimer
          ? (
              text: 'Solved · ${formatPlayTime(time)}',
              spoken: 'Solved in ${describePlayTime(time)}',
              solved: true,
            )
          : (text: 'Solved', spoken: 'Solved', solved: true);
    }
    if (games.started(level) case final game? when game.isStarted) {
      return (text: 'In progress', spoken: 'In progress', solved: false);
    }
    return null;
  }
}

/// A level's progress as shown, as read aloud, and whether it is solved.
typedef _Status = ({String text, String spoken, bool solved});

/// A level of a puzzle as the home screen lists it: its name, the size of
/// its board, how far today's game has come and the route that opens it.
typedef _Level = ({
  String title,
  String size,
  _Status? status,
  String routeName,
});

/// A puzzle with its name, what it is about and its levels.
class _PuzzleCard extends StatelessWidget {
  const _PuzzleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.levels,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<_Level> levels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Icon(icon, size: 32, color: theme.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final level in levels) ...[
            const Divider(height: 1, indent: 20, endIndent: 20),
            _LevelTile(level: level),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.level});

  final _Level level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = level.status;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(level.title),
      subtitle: Text(level.size),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status != null)
            Text(
              status.text,
              semanticsLabel: status.spoken,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          const SizedBox(width: 8),
          Icon(
            status?.solved ?? false ? Icons.check_circle : Icons.chevron_right,
            color: theme.colorScheme.primary,
          ),
        ],
      ),
      onTap: () => unawaited(Navigator.of(context).pushNamed(level.routeName)),
    );
  }
}
