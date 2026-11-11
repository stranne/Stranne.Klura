import 'package:flutter/material.dart';

/// Lists the available puzzles for [today].
class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.today, super.key});

  final DateTime today;

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
                const _PuzzleCard(
                  title: 'Bridges',
                  description: 'Connect every island without making a loop.',
                  icon: Icons.hub_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PuzzleCard extends StatelessWidget {
  const _PuzzleCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card.outlined(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, size: 32, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(description),
        trailing: Text(
          'Coming soon',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
