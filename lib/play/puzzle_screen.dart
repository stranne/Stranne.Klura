import 'dart:async';

import 'package:flutter/services.dart';
import 'package:klura/app/klura_settings.dart';
import 'package:klura/core/play_time.dart';
import 'package:klura/core/puzzle_game.dart';
import 'package:klura/play/play_timer.dart';
import 'package:klura/play/puzzle_controller.dart';
import 'package:material_ui/material_ui.dart';

/// A short message in the status line, marked when it reports a problem.
typedef PuzzleNotice = ({String text, bool isProblem});

/// Builds a puzzle's board, which may show a short [PuzzleNotice] in the
/// status line through `showNotice`.
typedef PuzzleBoardBuilder = Widget Function(
  BuildContext context,
  ValueSetter<PuzzleNotice> showNotice,
);

/// What the how-to-play sheet of a puzzle says.
typedef HowToPlay = ({
  /// The rules of the puzzle, numbered from 1.
  List<HowToPlayPoint> rules,

  /// The heading over [controls], such as `Building bridges`.
  String controlsTitle,

  /// How to make moves on the board, each marked with a bullet.
  List<HowToPlayPoint> controls,

  /// What the player puts on the board, as in `Your bridges are saved`.
  String marksName,
});

/// Plays one game of the day with a game of type [G]: the board, the time
/// played, a status line, undo and starting over, and how to play.
///
/// The game's timer runs while this screen is open and the app is in front.
/// Each puzzle supplies its board, the problems it names in the status line
/// and its how-to-play text.
class PuzzleScreen<G extends PuzzleGame> extends StatefulWidget {
  const PuzzleScreen({
    required this.title,
    required this.controller,
    required this.settings,
    required this.board,
    required this.problemIn,
    required this.solvedDetail,
    required this.resetNotice,
    required this.howToPlay,
    super.key,
  });

  /// The title in the app bar, such as `Bridges · Normal`.
  final String title;

  final PuzzleController<Enum, G> controller;

  /// Whether to show the time played.
  final KluraSettings settings;

  final PuzzleBoardBuilder board;

  /// Names what in a game the player should look at, or returns `null` when
  /// nothing is wrong.
  final PuzzleNotice? Function(G game) problemIn;

  /// What the solved panel says instead of the time when the timer is
  /// hidden, such as `All 30 islands are linked`.
  final String solvedDetail;

  /// The status line's note after starting over, such as `Board cleared.
  /// Undo brings the bridges back.`
  final String resetNotice;

  final HowToPlay howToPlay;

  @override
  State<PuzzleScreen<G>> createState() => _PuzzleScreenState<G>();
}

/// How long a short notice stays in the status line.
const Duration _noticeDuration = Duration(milliseconds: 2800);

class _PuzzleScreenState<G extends PuzzleGame> extends State<PuzzleScreen<G>> {
  PuzzleNotice? _notice;
  Timer? _noticeTimer;
  late final AppLifecycleListener _lifecycle;

  PuzzleController<Enum, G> get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _updateTiming);
    _updateTiming(WidgetsBinding.instance.lifecycleState);
  }

  @override
  void didUpdateWidget(PuzzleScreen<G> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.pauseTiming();
      _updateTiming(WidgetsBinding.instance.lifecycleState);
    }
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _lifecycle.dispose();
    _controller.pauseTiming();
    super.dispose();
  }

  /// Runs the timer only while the app is in front: on the web, while the
  /// tab is visible and the window has focus. A `null` state means the
  /// platform has not reported one yet.
  void _updateTiming(AppLifecycleState? state) {
    if (state == null || state == AppLifecycleState.resumed) {
      _controller.resumeTiming();
    } else {
      _controller.pauseTiming();
    }
  }

  void _showNotice(PuzzleNotice notice) {
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
    _showNotice((text: widget.resetNotice, isProblem: false));
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
            title: Text(widget.title),
            actions: [
              _PlayClock(controller: _controller, settings: widget.settings),
              IconButton(
                tooltip: 'How to play',
                icon: const Icon(Icons.help_outline),
                onPressed: () => _showHowToPlay(context, widget.howToPlay),
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
                        child: widget.board(context, _showNotice),
                      ),
                    ),
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        _controller,
                        widget.settings,
                      ]),
                      builder: (context, _) => _BottomPanel(
                        game: _controller.game,
                        problem: widget.problemIn(_controller.game),
                        solveTime:
                            widget.settings.showTimer && _controller.wasSolved
                            ? _controller.timer.elapsed
                            : null,
                        solvedDetail: widget.solvedDetail,
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
    required this.problem,
    required this.solveTime,
    required this.solvedDetail,
    required this.notice,
    required this.onUndo,
    required this.onReset,
    required this.onDone,
  });

  final PuzzleGame game;

  /// The problem the status line names when there is no notice.
  final PuzzleNotice? problem;

  /// The time the first solve took, or `null` if the timer is hidden.
  final Duration? solveTime;

  final String solvedDetail;
  final PuzzleNotice? notice;
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
                _StatusLine(message: notice ?? problem),
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
              solveTime: solveTime,
              detail: solvedDetail,
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
  const _StatusLine({required this.message});

  final PuzzleNotice? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          child: switch (message) {
            null => const SizedBox.shrink(),
            (:final text, :final isProblem) => Center(
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
          },
        ),
      ),
    );
  }
}

class _SolvedPanel extends StatelessWidget {
  const _SolvedPanel({
    required this.solveTime,
    required this.detail,
    required this.onReset,
    required this.onDone,
  });

  /// The time the first solve took, or `null` if the timer is hidden.
  final Duration? solveTime;

  /// What the panel says instead of the time.
  final String detail;

  final VoidCallback onReset;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detailStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

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
                child: switch (solveTime) {
                  final time? => Text(
                    '  ·  ${formatPlayTime(time)}',
                    semanticsLabel: 'in ${describePlayTime(time)}',
                    style: detailStyle?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  null => Text(
                    '  ·  $detail',
                    overflow: TextOverflow.ellipsis,
                    style: detailStyle,
                  ),
                },
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

void _showHowToPlay(BuildContext context, HowToPlay howToPlay) {
  unawaited(
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _HowToPlaySheet(howToPlay: howToPlay),
    ),
  );
}

class _HowToPlaySheet extends StatelessWidget {
  const _HowToPlaySheet({required this.howToPlay});

  final HowToPlay howToPlay;

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
            ...howToPlay.rules,
            const SizedBox(height: 16),
            Text(howToPlay.controlsTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...howToPlay.controls,
            const SizedBox(height: 16),
            Text('Saving and time', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            HowToPlayPoint(
              text:
                  'Your ${howToPlay.marksName} are saved on this device as '
                  'you play, so you can leave and pick up where you were.',
            ),
            const HowToPlayPoint(
              text:
                  'The clock counts only the time you spend on the puzzle and '
                  'stops when you solve it. Tap it to hide it.',
            ),
          ],
        ),
      ),
    );
  }
}

/// One point of the how-to-play sheet, after a number or a bullet.
class HowToPlayPoint extends StatelessWidget {
  const HowToPlayPoint({required this.text, this.marker = '•', super.key});

  /// The number or bullet before the text.
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

/// The time played, quiet in the app bar. Tapping it hides it behind a
/// small icon, which shows it again.
///
/// After the first solve it shows that solve's time with a check mark.
class _PlayClock extends StatefulWidget {
  const _PlayClock({required this.controller, required this.settings});

  final PuzzleController<Enum, PuzzleGame> controller;
  final KluraSettings settings;

  @override
  State<_PlayClock> createState() => _PlayClockState();
}

class _PlayClockState extends State<_PlayClock> {
  Timer? _tick;

  PlayTimer get _timer => widget.controller.timer;

  @override
  void initState() {
    super.initState();
    _timer.addListener(_onTimerChanged);
    widget.settings.addListener(_onTimerChanged);
    _scheduleTick();
  }

  @override
  void didUpdateWidget(_PlayClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.timer.removeListener(_onTimerChanged);
      _timer.addListener(_onTimerChanged);
    }
    if (oldWidget.settings != widget.settings) {
      oldWidget.settings.removeListener(_onTimerChanged);
      widget.settings.addListener(_onTimerChanged);
    }
    _scheduleTick();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _timer.removeListener(_onTimerChanged);
    widget.settings.removeListener(_onTimerChanged);
    super.dispose();
  }

  void _onTimerChanged() {
    setState(() {});
    _scheduleTick();
  }

  /// Rebuilds when the shown time next turns to a new second, while the
  /// timer runs and is shown.
  void _scheduleTick() {
    _tick?.cancel();
    _tick = null;
    if (!_timer.isRunning || !widget.settings.showTimer) {
      return;
    }
    const second = Duration.microsecondsPerSecond;
    final intoSecond = _timer.elapsed.inMicroseconds % second;
    _tick = Timer(Duration(microseconds: second - intoSecond), () {
      setState(() {});
      _scheduleTick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = widget.settings;

    if (!settings.showTimer) {
      return IconButton(
        tooltip: 'Show timer',
        icon: const Icon(Icons.timer_outlined),
        onPressed: () => settings.showTimer = true,
      );
    }

    final elapsed = _timer.elapsed;
    final solved = widget.controller.wasSolved;
    final style = theme.textTheme.titleMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Tooltip(
      message: 'Hide timer',
      child: TextButton.icon(
        onPressed: () => settings.showTimer = false,
        icon: solved ? const Icon(Icons.check, size: 18) : null,
        label: Text(
          formatPlayTime(elapsed),
          semanticsLabel: solved
              ? 'Solved in ${describePlayTime(elapsed)}'
              : 'Time played, ${describePlayTime(elapsed)}',
          style: style,
        ),
      ),
    );
  }
}
