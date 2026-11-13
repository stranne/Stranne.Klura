import 'dart:async';

import 'package:flutter/services.dart';
import 'package:klura/app/klura_settings.dart';
import 'package:klura/core/play_time.dart';
import 'package:klura/core/puzzle_game.dart';
import 'package:klura/play/play_timer.dart';
import 'package:klura/play/puzzle_controller.dart';
import 'package:klura/play/puzzle_sound.dart';
import 'package:material_ui/material_ui.dart';

/// A short message in the status line, marked when it reports a problem.
typedef PuzzleNotice = ({String text, bool isProblem});

/// Builds a puzzle's board, which takes the keyboard focus through
/// `focusNode`, may show a short [PuzzleNotice] in the status line through
/// `showNotice` and plays the [PuzzleSound] of a move through `playSound`,
/// which stays silent while the player has sounds off.
///
/// The screen owns `focusNode` and gives the board the focus when the player
/// presses an arrow key elsewhere on the screen. The board refuses the focus
/// while the game is solved, since it then takes no moves.
typedef PuzzleBoardBuilder = Widget Function(
  BuildContext context,
  FocusNode focusNode,
  ValueSetter<PuzzleNotice> showNotice,
  ValueSetter<PuzzleSound> playSound,
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

/// What the solved panel says of a solve whose result is more than its
/// time: a `title` after the check mark, such as `Solved in 15 moves`, a
/// `detail` after it, and the whole of it as `spoken` for screen readers.
typedef SolvedMessage = ({String title, String detail, String spoken});

/// Plays one game of the day with a game of type [G]: the board, the time
/// played, the sounds of moves, a status line, undo and starting over, and
/// how to play.
///
/// The game's timer runs while this screen is open and the app is in front,
/// and pauses while the how-to-play sheet covers the board. Each puzzle
/// supplies its board, the problems it names in the status line and its
/// how-to-play text.
class PuzzleScreen<G extends PuzzleGame> extends StatefulWidget {
  const PuzzleScreen({
    required this.title,
    required this.controller,
    required this.settings,
    required this.sound,
    required this.board,
    required this.problemIn,
    required this.resetNotice,
    required this.howToPlay,
    this.solvedDetail,
    this.solvedMessage,
    this.countIn,
    super.key,
  }) : assert(
         (solvedDetail == null) != (solvedMessage == null),
         'Give either solvedDetail or solvedMessage',
       );

  /// The title in the app bar, such as `Bridges · Normal`.
  final String title;

  final PuzzleController<Enum, G> controller;

  /// Whether to show the time played and play the sounds of moves.
  final KluraSettings settings;

  /// Where the sounds of moves are heard.
  final SoundOutput sound;

  final PuzzleBoardBuilder board;

  /// Names what in a game the player should look at, or returns `null` when
  /// nothing is wrong.
  final PuzzleNotice? Function(G game) problemIn;

  /// What the solved panel says instead of the time when the timer is
  /// hidden, such as `All 30 islands are linked`, unless [solvedMessage]
  /// says it all.
  final String? solvedDetail;

  /// What the solved panel says of a solved game, in place of `Solved` with
  /// the time or [solvedDetail], for a puzzle whose result is more than its
  /// time. The time stays in the app bar.
  final SolvedMessage Function(G game)? solvedMessage;

  /// A short count of the player's progress, such as `4 moves`, which
  /// stands between Undo and Start over while the game is played.
  final String Function(G game)? countIn;

  /// The status line's note after starting over, such as `Board cleared.
  /// Undo brings the bridges back.`
  final String resetNotice;

  final HowToPlay howToPlay;

  @override
  State<PuzzleScreen<G>> createState() => _PuzzleScreenState<G>();
}

/// How long a short notice stays in the status line.
const Duration _noticeDuration = Duration(milliseconds: 2800);

final Set<LogicalKeyboardKey> _arrowKeys = {
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowLeft,
};

class _PuzzleScreenState<G extends PuzzleGame> extends State<PuzzleScreen<G>> {
  PuzzleNotice? _notice;
  Timer? _noticeTimer;
  late final AppLifecycleListener _lifecycle;

  /// The app's state as the platform last reported it, or `null` before it
  /// has reported one.
  AppLifecycleState? _appState;

  /// Whether the how-to-play sheet covers the board.
  bool _isReadingHowToPlay = false;

  /// Whether the game was solved when it last changed, to notice the move
  /// that solves it.
  late bool _isSolved;

  /// The puzzle's own message of the last solve, if it has one, kept so the
  /// solved panel says the same while it fades after a start over.
  SolvedMessage? _lastSolved;

  final FocusNode _boardFocus = FocusNode(debugLabel: 'Board');
  final FocusNode _doneFocus = FocusNode(debugLabel: 'Done');

  PuzzleController<Enum, G> get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _isSolved = _controller.game.isSolved;
    _lastSolved = _solvedMessageOf(_controller.game);
    _controller.addListener(_onGameChanged);
    _appState = WidgetsBinding.instance.lifecycleState;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _appState = state;
        _updateTiming();
      },
    );
    _updateTiming();
  }

  @override
  void didUpdateWidget(PuzzleScreen<G> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller
        ..removeListener(_onGameChanged)
        ..pauseTiming();
      _controller.addListener(_onGameChanged);
      _isSolved = _controller.game.isSolved;
      _lastSolved = _solvedMessageOf(_controller.game);
      _updateTiming();
    }
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _lifecycle.dispose();
    _controller
      ..removeListener(_onGameChanged)
      ..pauseTiming();
    _boardFocus.dispose();
    _doneFocus.dispose();
    super.dispose();
  }

  /// Moves the focus to Done once a move solves the puzzle. The board and
  /// the buttons below it then give up the focus, which would otherwise
  /// jump back to the app bar.
  void _onGameChanged() {
    final isSolved = _controller.game.isSolved;
    if (isSolved && !_isSolved) {
      // The solved panel takes the focus once it has been built as shown.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _doneFocus.requestFocus();
        }
      });
    }
    _isSolved = isSolved;
    _lastSolved = _solvedMessageOf(_controller.game) ?? _lastSolved;
  }

  /// The puzzle's own message for [game] if it is solved, otherwise `null`.
  SolvedMessage? _solvedMessageOf(G game) =>
      game.isSolved ? widget.solvedMessage?.call(game) : null;

  /// Gives the board the keyboard focus when the player presses an arrow
  /// key while something else on the screen has it, so the keyboard works
  /// without tabbing to the board first. Nothing else on the screen uses the
  /// arrows. The press only shows the board's focus ring, even with Shift,
  /// since the player cannot yet see where a move would start.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    // Arrows with these belong to the browser and the system, such as Alt
    // and Left for back.
    final withShortcutModifier =
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed;
    if (event is KeyUpEvent ||
        !_arrowKeys.contains(event.logicalKey) ||
        withShortcutModifier ||
        !_boardFocus.canRequestFocus) {
      return KeyEventResult.ignored;
    }
    _boardFocus.requestFocus();
    return KeyEventResult.handled;
  }

  /// Runs the timer only while the player can see the board: the app is in
  /// front and the how-to-play sheet is closed. On the web the app is in
  /// front while the tab is visible and the window has focus.
  void _updateTiming() {
    final appInFront =
        _appState == null || _appState == AppLifecycleState.resumed;
    if (appInFront && !_isReadingHowToPlay) {
      _controller.resumeTiming();
    } else {
      _controller.pauseTiming();
    }
  }

  /// Shows how to play, with the timer paused until the sheet closes, so
  /// reading the rules never costs the player time.
  Future<void> _showHowToPlay() async {
    _isReadingHowToPlay = true;
    _updateTiming();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _HowToPlaySheet(howToPlay: widget.howToPlay),
    );
    if (!mounted) {
      return;
    }
    _isReadingHowToPlay = false;
    _updateTiming();
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

  void _playSound(PuzzleSound sound) {
    if (widget.settings.playSounds) {
      widget.sound.play(sound);
    }
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
        // The board handles its own arrow keys, so they reach this only
        // while something else has the focus.
        onKeyEvent: _onKeyEvent,
        child: Scaffold(
          appBar: AppBar(
            // The back button already leaves room before the title. Without
            // more spacing around it, a title such as `Bridges · Normal`
            // fits beside the clock and two buttons on a phone 360 pixels
            // wide. A narrower screen or a longer time shrinks the title a
            // little rather than cutting off the level.
            titleSpacing: 0,
            title: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(widget.title),
            ),
            actions: [
              _PlayClock(controller: _controller, settings: widget.settings),
              _SoundButton(settings: widget.settings),
              IconButton(
                tooltip: 'How to play',
                icon: const Icon(Icons.help_outline),
                onPressed: () => unawaited(_showHowToPlay()),
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
                        child: widget.board(
                          context,
                          _boardFocus,
                          _showNotice,
                          _playSound,
                        ),
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
                        solvedDetail: widget.solvedDetail ?? '',
                        // Before a solve the hidden panel lays out the
                        // message of the game as it is, so the board keeps
                        // its size when the panel shows.
                        solvedMessage:
                            _lastSolved ??
                            widget.solvedMessage?.call(_controller.game),
                        count: widget.countIn?.call(_controller.game),
                        notice: _notice,
                        onUndo: _undo,
                        onReset: _reset,
                        onDone: () => Navigator.of(context).maybePop(),
                        doneFocus: _doneFocus,
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
    required this.solvedMessage,
    required this.count,
    required this.notice,
    required this.onUndo,
    required this.onReset,
    required this.onDone,
    required this.doneFocus,
  });

  final PuzzleGame game;

  /// The problem the status line names when there is no notice.
  final PuzzleNotice? problem;

  /// The time the first solve took, or `null` if the timer is hidden.
  final Duration? solveTime;

  final String solvedDetail;

  /// What the solved panel says in place of the time and [solvedDetail], if
  /// the puzzle says more.
  final SolvedMessage? solvedMessage;

  /// The count between the buttons, if the puzzle keeps one.
  final String? count;

  final PuzzleNotice? notice;
  final VoidCallback onUndo;
  final VoidCallback onReset;
  final VoidCallback onDone;

  /// The focus of the solved panel's Done button.
  final FocusNode doneFocus;

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
                _ButtonRow(
                  children: [
                    OutlinedButton.icon(
                      onPressed: game.canUndo ? onUndo : null,
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo'),
                    ),
                    if (count case final count?) _Count(text: count),
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
              message: solvedMessage,
              onReset: onReset,
              onDone: onDone,
              doneFocus: doneFocus,
            ),
          ),
        ],
      ),
    );
  }
}

/// The count between Undo and Start over, such as `4 moves`.
class _Count extends StatelessWidget {
  const _Count({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Buttons at either end of a row, or one above the other where large text
/// leaves no room for them side by side. A third child stands between
/// them.
class _ButtonRow extends StatelessWidget {
  const _ButtonRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return OverflowBar(
      alignment: MainAxisAlignment.spaceBetween,
      overflowAlignment: OverflowBarAlignment.center,
      overflowSpacing: 4,
      children: children,
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

    // A live region speaks its own label when it changes, so the message is
    // its label. The text below is left out: while one message fades into
    // the next, both are on screen and would be read together.
    return Semantics(
      container: true,
      liveRegion: true,
      label: message?.text,
      child: ExcludeSemantics(
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
      ),
    );
  }
}

class _SolvedPanel extends StatelessWidget {
  const _SolvedPanel({
    required this.solveTime,
    required this.detail,
    required this.message,
    required this.onReset,
    required this.onDone,
    required this.doneFocus,
  });

  /// The time the first solve took, or `null` if the timer is hidden.
  final Duration? solveTime;

  /// What the panel says instead of the time.
  final String detail;

  /// What the panel says in place of `Solved` with the time or [detail], if
  /// the puzzle says more.
  final SolvedMessage? message;

  final VoidCallback onReset;
  final VoidCallback onDone;

  /// The focus of the Done button.
  final FocusNode doneFocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detailStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final message = this.message;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A live region speaks its own label, so it says the whole message.
        Semantics(
          container: true,
          liveRegion: true,
          label:
              message?.spoken ??
              switch (solveTime) {
                final time? => 'Solved in ${describePlayTime(time)}',
                null => 'Solved. $detail',
              },
          child: ExcludeSemantics(
            child: message != null
                ? _SolvedMessageLine(message: message, detailStyle: detailStyle)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text('Solved', style: theme.textTheme.titleMedium),
                      Flexible(
                        child: switch (solveTime) {
                          final time? => Text(
                            '  ·  ${formatPlayTime(time)}',
                            style: detailStyle?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
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
        ),
        const SizedBox(height: 8),
        _ButtonRow(
          children: [
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Start over'),
            ),
            FilledButton(
              focusNode: doneFocus,
              onPressed: onDone,
              child: const Text('Done'),
            ),
          ],
        ),
      ],
    );
  }
}

/// A puzzle's own solved message: its title after the check mark and its
/// detail beside it, or below where large text leaves no room.
class _SolvedMessageLine extends StatelessWidget {
  const _SolvedMessageLine({required this.message, required this.detailStyle});

  final SolvedMessage message;
  final TextStyle? detailStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(message.title, style: theme.textTheme.titleMedium),
            ),
          ],
        ),
        Text(
          '  ·  ${message.detail}',
          textAlign: TextAlign.center,
          style: detailStyle,
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
            Text(
              'Saving, time and sound',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            HowToPlayPoint(
              text:
                  'Your ${howToPlay.marksName} are saved on this device as '
                  'you play, so you can leave and pick up where you were.',
            ),
            const HowToPlayPoint(
              text:
                  'The clock counts only the time you spend on the puzzle. '
                  'It pauses while you read this and stops when you solve '
                  'it. Tap it to hide it.',
            ),
            const HowToPlayPoint(
              text:
                  'Each move makes a soft sound. Tap the speaker to turn '
                  'sounds off or on for every puzzle.',
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

  final FocusNode _timeFocus = FocusNode(debugLabel: 'Time');
  final FocusNode _iconFocus = FocusNode(debugLabel: 'Timer icon');

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
    _timeFocus.dispose();
    _iconFocus.dispose();
    super.dispose();
  }

  void _onTimerChanged() {
    setState(() {});
    _scheduleTick();
  }

  /// Shows or hides the time. When the pressed button has the keyboard
  /// focus, the button that takes its place gets it, so the next press
  /// turns the time back. A tap leaves the focus where it was.
  void _showTime(bool show) {
    final pressedHadFocus = (show ? _iconFocus : _timeFocus).hasFocus;
    widget.settings.showTimer = show;
    if (!pressedHadFocus) {
      return;
    }
    // The new button takes the focus once it has been built. Handing it a
    // node that already has the focus would keep the focus but not show
    // the button's focus ring.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        (show ? _timeFocus : _iconFocus).requestFocus();
      }
    });
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
        focusNode: _iconFocus,
        tooltip: 'Show timer',
        icon: const Icon(Icons.timer_outlined),
        onPressed: () => _showTime(true),
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
        focusNode: _timeFocus,
        onPressed: () => _showTime(false),
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

/// Turns the sounds of moves off and on again for every puzzle, its icon
/// showing whether they are on.
class _SoundButton extends StatelessWidget {
  const _SoundButton({required this.settings});

  final KluraSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final playSounds = settings.playSounds;
        return IconButton(
          tooltip: playSounds ? 'Turn sounds off' : 'Turn sounds on',
          icon: Icon(
            playSounds ? Icons.volume_up_outlined : Icons.volume_off_outlined,
          ),
          onPressed: () => settings.playSounds = !playSounds,
        );
      },
    );
  }
}
