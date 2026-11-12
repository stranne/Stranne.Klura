import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
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

/// The room around the home screen's content.
const double _margin = 24;

/// The room between the puzzle cards.
const double _gap = 16;

/// The narrowest a puzzle card may be at the normal text size. Where the
/// screen has no room for another card this wide, the cards take fewer
/// columns.
const double _minCardWidth = 340;

/// The widest a puzzle card may be.
const double _maxCardWidth = 432;

/// The most puzzle cards side by side, so a wide screen stays calm.
const int _maxColumns = 3;

/// Lists the puzzles of [today] and how far each has come, in as many
/// columns as the screen has room for.
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
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([bridges, tents, settings]),
          builder: (context, _) {
            final cards = _cards();
            return LayoutBuilder(
              builder: (context, constraints) {
                final room = math.max(0.0, constraints.maxWidth - 2 * _margin);
                final columns = _columnsFor(room, cards.length, context);
                final width = math.min(
                  room,
                  columns * _maxCardWidth + (columns - 1) * _gap,
                );
                return ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: (constraints.maxWidth - width) / 2,
                    vertical: _margin,
                  ),
                  children: [
                    _Header(today: today),
                    const SizedBox(height: 32),
                    for (var first = 0; first < cards.length; first += columns)
                      Padding(
                        padding: EdgeInsets.only(top: first == 0 ? 0 : _gap),
                        child: _CardRow(
                          columns: columns,
                          children: cards.sublist(
                            first,
                            math.min(first + columns, cards.length),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// How many of [count] cards fit side by side in [room], at most
  /// [_maxColumns].
  ///
  /// Larger text needs wider cards, so it leaves room for fewer.
  int _columnsFor(double room, int count, BuildContext context) {
    final cardWidth = MediaQuery.textScalerOf(context).scale(_minCardWidth);
    final fit = ((room + _gap) / (cardWidth + _gap)).floor();
    return fit.clamp(1, math.max(1, math.min(count, _maxColumns)));
  }

  /// A card for every puzzle, with how far each of today's games has come.
  List<Widget> _cards() => [
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
  ];

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

/// The app's name over a word on what the screen holds, with the date of
/// the puzzles at the side.
///
/// Where large text leaves no room beside the name, the date goes below it.
class _Header extends StatelessWidget {
  const _Header({required this.today});

  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OverflowBar(
      alignment: MainAxisAlignment.spaceBetween,
      spacing: 16,
      overflowSpacing: 12,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Klura', style: theme.textTheme.displaySmall),
            const SizedBox(height: 4),
            Text(
              "Today's puzzles",
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        _DateLabel(date: today),
      ],
    );
  }
}

/// The [date] in short, read aloud in full.
class _DateLabel extends StatelessWidget {
  const _DateLabel({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: theme.colorScheme.secondaryContainer,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Text(
          localizations.formatMediumDate(date),
          semanticsLabel: localizations.formatFullDate(date),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Cards side by side in [columns] columns of equal width, [_gap] apart,
/// each as tall as the tallest. A row with fewer cards leaves its last
/// columns empty, so every card has the same width.
class _CardRow extends MultiChildRenderObjectWidget {
  const _CardRow({required this.columns, required super.children});

  final int columns;

  @override
  _RenderCardRow createRenderObject(BuildContext context) =>
      _RenderCardRow(columns, Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, _RenderCardRow renderObject) {
    renderObject
      ..columns = columns
      ..textDirection = Directionality.of(context);
  }
}

class _CardRowParentData extends ContainerBoxParentData<RenderBox> {}

/// Lays out a [_CardRow].
///
/// Each card is laid out twice: at its own height, to find the tallest, and
/// then at that height. `IntrinsicHeight` would save the first pass, but a
/// `ListTile` measures its intrinsic height without the room its trailing
/// widget takes, so a level whose text wraps there would overflow the card.
class _RenderCardRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CardRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CardRowParentData> {
  _RenderCardRow(this._columns, this._textDirection);

  int get columns => _columns;
  int _columns;
  set columns(int value) {
    if (value != _columns) {
      _columns = value;
      markNeedsLayout();
    }
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value != _textDirection) {
      _textDirection = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CardRowParentData) {
      child.parentData = _CardRowParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final cardWidth = (width - (columns - 1) * _gap) / columns;

    var height = 0.0;
    for (var card = firstChild; card != null; card = childAfter(card)) {
      card.layout(
        BoxConstraints.tightFor(width: cardWidth),
        parentUsesSize: true,
      );
      height = math.max(height, card.size.height);
    }

    var x = 0.0;
    for (var card = firstChild; card != null; card = childAfter(card)) {
      // A least height rather than a tight one keeps the card from becoming
      // a relayout boundary, so a change inside it lays out the row again.
      card.layout(
        BoxConstraints(
          minWidth: cardWidth,
          maxWidth: cardWidth,
          minHeight: height,
        ),
        parentUsesSize: true,
      );
      (card.parentData! as _CardRowParentData).offset = Offset(
        switch (textDirection) {
          TextDirection.ltr => x,
          TextDirection.rtl => width - cardWidth - x,
        },
        0,
      );
      x += cardWidth + _gap;
    }
    size = constraints.constrain(Size(width, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
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
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      // A card beside a taller one keeps its levels at the bottom, in line
      // with the levels beside them.
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final level in levels) ...[
                const Divider(height: 1, indent: 20, endIndent: 20),
                _LevelTile(level: level),
              ],
              const SizedBox(height: 4),
            ],
          ),
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
