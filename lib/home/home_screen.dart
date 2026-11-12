import 'dart:async';

import 'package:klura/app/klura_settings.dart';
import 'package:klura/core/play_time.dart';
import 'package:klura/puzzles/bridges/bridges_daily_games.dart';
import 'package:klura/puzzles/bridges/bridges_screen.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:material_ui/material_ui.dart';

/// Lists the puzzles of [today], how far each has come and the daily
/// streak.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.today,
    required this.bridges,
    required this.settings,
    super.key,
  });

  final DateTime today;

  /// Today's Bridges games, to open them and show how far each has come.
  final BridgesDailyGames bridges;

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
              listenable: Listenable.merge([bridges, settings]),
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
                  if (bridges.streak > 0) ...[
                    const SizedBox(height: 12),
                    _Streak(days: bridges.streak),
                  ],
                  const SizedBox(height: 32),
                  _BridgesCard(
                    bridges: bridges,
                    showTimes: settings.showTimer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The number of days in a row with a solved puzzle.
class _Streak extends StatelessWidget {
  const _Streak({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          Icons.event_available_outlined,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          '$days-day streak',
          semanticsLabel:
              'Streak: $days ${days == 1 ? 'day' : 'days'} in a row with a '
              'solved puzzle',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _BridgesCard extends StatelessWidget {
  const _BridgesCard({required this.bridges, required this.showTimes});

  final BridgesDailyGames bridges;
  final bool showTimes;

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
                Icon(
                  Icons.hub_outlined,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bridges', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        'Connect every island without making a loop.',
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
          for (final level in BridgesLevel.values) ...[
            const Divider(height: 1, indent: 20, endIndent: 20),
            _LevelTile(
              level: level,
              status: _statusOf(level),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  /// How far today's game at [level] has come, or `null` if it has not
  /// started.
  ///
  /// A puzzle stays solved after a start over, since the solve stands.
  _Status? _statusOf(BridgesLevel level) {
    if (bridges.solveTime(level) case final time?) {
      return showTimes
          ? (
              text: 'Solved · ${formatPlayTime(time)}',
              spoken: 'Solved in ${describePlayTime(time)}',
              solved: true,
            )
          : (text: 'Solved', spoken: 'Solved', solved: true);
    }
    if (bridges.started(level) case final game? when game.isStarted) {
      return (text: 'In progress', spoken: 'In progress', solved: false);
    }
    return null;
  }
}

/// A level's progress as shown, as read aloud, and whether it is solved.
typedef _Status = ({String text, String spoken, bool solved});

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.level, required this.status});

  final BridgesLevel level;

  /// How far the game has come, or `null` if it has not started.
  final _Status? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = level.config;
    final status = this.status;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(bridgesLevelTitle(level)),
      subtitle: Text(
        '${config.width} × ${config.height} · '
        '${config.islandCount} islands',
      ),
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
      onTap: () => unawaited(
        Navigator.of(context).pushNamed(bridgesRouteName(level)),
      ),
    );
  }
}
