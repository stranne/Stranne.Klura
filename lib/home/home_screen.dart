import 'dart:async';

import 'package:flutter/material.dart';
import 'package:klura/puzzles/bridges/bridges_controller.dart';
import 'package:klura/puzzles/bridges/bridges_daily_games.dart';
import 'package:klura/puzzles/bridges/bridges_screen.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';

/// Lists the puzzles of [today].
class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.today, required this.bridges, super.key});

  final DateTime today;

  /// Today's Bridges games, to open them and show how far each has come.
  final BridgesDailyGames bridges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
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
                ListenableBuilder(
                  listenable: bridges,
                  builder: (context, _) => _BridgesCard(bridges: bridges),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BridgesCard extends StatelessWidget {
  const _BridgesCard({required this.bridges});

  final BridgesDailyGames bridges;

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
            _LevelTile(level: level, game: bridges.started(level)),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.level, required this.game});

  final BridgesLevel level;

  /// The game at [level], or `null` if it has not been opened.
  final BridgesController? game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = level.config;
    final progress = game?.game;
    final (status, icon) = switch (progress) {
      final game? when game.isSolved => ('Solved', Icons.check_circle),
      final game? when !game.arrangement.isEmpty => (
        'In progress',
        Icons.chevron_right,
      ),
      _ => (null, Icons.chevron_right),
    };

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
              status,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 8),
          Icon(icon, color: theme.colorScheme.primary),
        ],
      ),
      onTap: () => unawaited(
        Navigator.of(context).pushNamed(bridgesRouteName(level)),
      ),
    );
  }
}
