import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:klura/puzzles/bridges/bridges_board.dart';
import 'package:klura/puzzles/bridges/bridges_controller.dart';
import 'package:klura/puzzles/bridges/logic/bridges_game.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_rules.dart';

/// The route name of the daily puzzle at [level], such as `/bridges/normal`.
String bridgesRouteName(BridgesLevel level) => '/bridges/${level.name}';

/// The name of [level] as the player sees it.
String bridgesLevelTitle(BridgesLevel level) => switch (level) {
  BridgesLevel.normal => 'Normal',
  BridgesLevel.hard => 'Hard',
};

/// Plays one game of Bridges: the board, how far the player has come, undo
/// and starting over.
class BridgesScreen extends StatefulWidget {
  const BridgesScreen({required this.controller, super.key});

  final BridgesController controller;

  @override
  State<BridgesScreen> createState() => _BridgesScreenState();
}

/// How long a short notice stays in the status line.
const Duration _noticeDuration = Duration(milliseconds: 2800);

/// A short message in the status line, marked when it reports a problem.
typedef _Notice = ({String text, bool isProblem});

class _BridgesScreenState extends State<BridgesScreen> {
  _Notice? _notice;
  Timer? _noticeTimer;

  BridgesController get _controller => widget.controller;

  @override
  void dispose() {
    _noticeTimer?.cancel();
    super.dispose();
  }

  void _showNotice(_Notice notice) {
    _noticeTimer?.cancel();
    setState(() => _notice = notice);
    _noticeTimer = Timer(_noticeDuration, () {
      if (mounted) {
        setState(() => _notice = null);
      }
    });
  }

  void _clearNotice() {
    _noticeTimer?.cancel();
    if (_notice != null) {
      setState(() => _notice = null);
    }
  }

  void _undo() {
    _controller.undo();
    _clearNotice();
  }

  void _reset() {
    if (!_controller.game.canReset) {
      return;
    }
    _controller.reset();
    _showNotice((
      text: 'Board cleared. Undo brings the bridges back.',
      isProblem: false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text('Bridges · ${bridgesLevelTitle(_controller.level)}'),
            actions: [
              IconButton(
                tooltip: 'How to play',
                icon: const Icon(Icons.help_outline),
                onPressed: () => _showHowToPlay(context),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                        child: BridgesBoard(
                          controller: _controller,
                          onBlocked: () => _showNotice((
                            text: 'Bridges cannot cross each other.',
                            isProblem: true,
                          )),
                        ),
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (context, game, _) => _BottomPanel(
                        game: game,
                        notice: _notice,
                        onUndo: _undo,
                        onReset: _reset,
                        onDone: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The status and buttons below the board while playing, and the solved
/// message once the puzzle is done.
///
/// Both stay laid out, one of them hidden, so the board keeps its size when
/// they swap.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.game,
    required this.notice,
    required this.onUndo,
    required this.onReset,
    required this.onDone,
  });

  final BridgesGame game;
  final _Notice? notice;
  final VoidCallback onUndo;
  final VoidCallback onReset;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final solved = game.isSolved;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          _Reveal(
            visible: !solved,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusLine(game: game, notice: notice),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: game.canUndo ? onUndo : null,
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo'),
                    ),
                    TextButton.icon(
                      onPressed: game.canReset ? onReset : null,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Start over'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _Reveal(
            visible: solved,
            delay: const Duration(milliseconds: 700),
            child: _SolvedPanel(
              islandCount: game.puzzle.islands.length,
              onReset: onReset,
              onDone: onDone,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.game, required this.notice});

  final BridgesGame game;
  final _Notice? notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (:text, :isProblem) =
        notice ?? _describe(game.check, game.puzzle.islands.length);
    final style = theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // Room for two lines, so a longer message never moves the board.
    final height =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) *
        (style.height ?? 1.2) *
        2;

    return Semantics(
      liveRegion: true,
      child: SizedBox(
        height: height,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: Center(
            key: ValueKey(text),
            child: Text.rich(
              TextSpan(
                children: [
                  if (isProblem)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.info_outline,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  TextSpan(text: text),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
        ),
      ),
    );
  }
}

/// Describes how far [check] is from solved, marking a problem the player
/// should look at.
_Notice _describe(BridgesCheck check, int islandCount) {
  final statuses = check.islandStatuses.values;
  final over = statuses.where((status) => status == IslandStatus.over).length;
  final met = statuses.where((status) => status == IslandStatus.met).length;
  final problems = [
    if (check.hasLoops) 'Some bridges form a loop',
    if (over == 1) 'An island has too many bridges',
    if (over > 1) '$over islands have too many bridges',
  ];
  if (problems.isNotEmpty) {
    return (text: problems.join(' · '), isProblem: true);
  }
  if (met == islandCount && !check.isConnected) {
    return (
      text: 'Every number is met, but not all islands are linked',
      isProblem: true,
    );
  }
  return (text: '$met of $islandCount islands complete', isProblem: false);
}

class _SolvedPanel extends StatelessWidget {
  const _SolvedPanel({
    required this.islandCount,
    required this.onReset,
    required this.onDone,
  });

  final int islandCount;
  final VoidCallback onReset;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Solved', style: theme.textTheme.titleMedium),
              Flexible(
                child: Text(
                  '  ·  All $islandCount islands are linked',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Start over'),
            ),
            FilledButton(onPressed: onDone, child: const Text('Done')),
          ],
        ),
      ],
    );
  }
}

/// Fades and slides [child] in when [visible], after [delay], and out at
/// once when not. A hidden child keeps its size but takes no input, focus or
/// semantics.
class _Reveal extends StatefulWidget {
  const _Reveal({
    required this.visible,
    required this.child,
    this.delay = Duration.zero,
  });

  final bool visible;
  final Duration delay;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 160),
    value: widget.visible ? 1 : 0,
  );
  Timer? _delay;

  @override
  void didUpdateWidget(_Reveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) {
      return;
    }
    _delay?.cancel();
    if (!widget.visible) {
      unawaited(_animation.reverse());
    } else if (widget.delay == Duration.zero ||
        MediaQuery.disableAnimationsOf(context)) {
      unawaited(_animation.forward());
    } else {
      _delay = Timer(widget.delay, () => unawaited(_animation.forward()));
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _animation, curve: Curves.easeOut);

    return IgnorePointer(
      ignoring: !widget.visible,
      child: ExcludeFocus(
        excluding: !widget.visible,
        child: ExcludeSemantics(
          excluding: !widget.visible,
          child: FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.2),
                end: Offset.zero,
              ).animate(curve),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

void _showHowToPlay(BuildContext context) {
  unawaited(
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _HowToPlay(),
    ),
  );
}

class _HowToPlay extends StatelessWidget {
  const _HowToPlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Text('How to play', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            const _Point(
              marker: '1',
              text: 'Each number tells how many bridges touch that island.',
            ),
            const _Point(
              marker: '2',
              text:
                  'Bridges run straight across or down, never diagonally. '
                  'Two islands can share one or two bridges.',
            ),
            const _Point(
              marker: '3',
              text: 'Bridges never cross each other or pass over an island.',
            ),
            const _Point(
              marker: '4',
              text: 'Link all the islands into one group.',
            ),
            const _Point(
              marker: '5',
              text:
                  'No loops: there is only one way along the bridges from '
                  'any island to any other. A double bridge is not a loop.',
            ),
            const SizedBox(height: 16),
            Text('Building bridges', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const _Point(
              marker: '•',
              text:
                  'Drag from an island toward a neighbor to build a bridge. '
                  'Do it again for a second bridge, and once more to remove '
                  'them.',
            ),
            const _Point(
              marker: '•',
              text:
                  'Tap a bridge, or the gap where one can go, to switch '
                  'between one, two and no bridges.',
            ),
            const _Point(
              marker: '•',
              text:
                  'With a keyboard, the arrow keys move between islands, '
                  'Shift and an arrow builds a bridge, and Ctrl and Z undoes.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.marker, required this.text});

  final String marker;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              marker,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
