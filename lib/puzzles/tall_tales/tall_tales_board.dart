import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:klura/play/puzzle_sound.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_game.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_marks.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_puzzle.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_rules.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_wording.dart';
import 'package:klura/puzzles/tall_tales/tall_tales_controller.dart';
import 'package:material_ui/material_ui.dart';

/// The jetty: a plank for each fisher, with their name, their statement and
/// the player's mark, over the water.
///
/// Tap a plank to move its fisher through the truth, tall tales and
/// unmarked. With the keyboard, the arrow keys move between fishers and
/// Space or Enter changes the mark. A statement that does not fit its
/// marks gets a red edge. The planks keep to a calm width, and the jetty
/// scrolls where they do not all fit.
class TallTalesBoard extends StatefulWidget {
  const TallTalesBoard({
    required this.controller,
    required this.focusNode,
    this.onSound,
    super.key,
  });

  final TallTalesController controller;

  /// The board's keyboard focus, owned by the screen, which also gives it to
  /// the board when the player presses an arrow key elsewhere.
  final FocusNode focusNode;

  /// Called with the sound of each move the player makes. Moving the focus
  /// makes no sound.
  final ValueSetter<PuzzleSound>? onSound;

  @override
  State<TallTalesBoard> createState() => _TallTalesBoardState();
}

/// The jetty never grows wider than this, so lines of text stay easy to
/// read on a large screen.
const double _maxWidth = 560;

const Duration _changeDuration = Duration(milliseconds: 160);

/// How long after its neighbor each plank lifts in the wave of a solve.
const int _waveStepMs = 90;

/// How long each plank takes to lift and settle in the wave.
const int _liftMs = 420;

/// How far each plank lifts in the wave.
const double _liftHeight = 6;

/// The size of the mark on each plank.
const double _badgeSize = 32;

class _TallTalesBoardState extends State<TallTalesBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: (TallTalesPuzzle.maxFishers - 1) * _waveStepMs + _liftMs,
    ),
    value: 1,
  );

  late TallTalesGame _game;

  /// The fisher whose mark solved the puzzle, where the wave starts, or
  /// `null` while no wave runs.
  int? _waveOrigin;

  /// The fisher the keyboard works on.
  int _cursor = 0;

  bool _showFocus = false;

  /// The fisher under the mouse, if any.
  int? _hovered;

  bool _reduceMotion = false;

  final List<GlobalKey> _plankKeys = [
    for (var fisher = 0; fisher < TallTalesPuzzle.maxFishers; fisher++)
      GlobalKey(debugLabel: 'Plank $fisher'),
  ];

  FocusNode get _focusNode => widget.focusNode;

  @override
  void initState() {
    super.initState();
    _game = widget.controller.value;
    widget.controller.addListener(_onGameChanged);
    _focusNode.addListener(_updateFocusHighlight);
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChanged);
  }

  @override
  void didUpdateWidget(TallTalesBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_updateFocusHighlight);
      widget.focusNode.addListener(_updateFocusHighlight);
      _showFocus = _focusShows;
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onGameChanged);
      widget.controller.addListener(_onGameChanged);
      _game = widget.controller.value;
      _waveOrigin = null;
      _cursor = 0;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onGameChanged);
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChanged);
    _focusNode.removeListener(_updateFocusHighlight);
    _wave.dispose();
    super.dispose();
  }

  void _onGameChanged() {
    final previous = _game;
    final current = widget.controller.value;
    final changed = [
      for (var fisher = 0; fisher < current.puzzle.fisherCount; fisher++)
        if (previous.marks[fisher] != current.marks[fisher]) fisher,
    ];
    final solvedByMove =
        current.isSolved && !previous.isSolved && changed.length == 1;

    setState(() {
      _game = current;
      _waveOrigin = solvedByMove && !_reduceMotion ? changed.single : null;
    });
    if (_waveOrigin != null) {
      unawaited(_wave.forward(from: 0));
    }
  }

  void _onHighlightModeChanged(FocusHighlightMode mode) =>
      _updateFocusHighlight();

  /// Whether the focus ring shows: the board has the focus and the player
  /// uses a keyboard or a mouse rather than touch.
  bool get _focusShows =>
      _focusNode.hasFocus &&
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  void _updateFocusHighlight() {
    final showFocus = _focusShows;
    if (showFocus != _showFocus) {
      setState(() => _showFocus = showFocus);
    }
  }

  /// Moves [fisher] to their next mark.
  void _cycle(int fisher) {
    if (_game.isSolved) {
      return;
    }
    // A tap gives the jetty the keyboard, so the arrow keys carry on from
    // the plank tapped. Only a keyboard or a mouse shows the ring.
    _focusNode.requestFocus();
    _cursor = fisher;
    widget.controller.cycleMark(fisher);
    unawaited(HapticFeedback.selectionClick());
    widget.onSound?.call(_soundOfMove(fisher));
  }

  /// The sound of the move that has just changed [fisher]: the chime if it
  /// solved the puzzle, since a solved jetty takes no moves.
  PuzzleSound _soundOfMove(int fisher) {
    if (_game.isSolved) {
      return PuzzleSound.solved;
    }
    return switch (_game.marks[fisher]) {
      TallTalesMark.truth => PuzzleSound.truth,
      TallTalesMark.tallTales => PuzzleSound.tallTales,
      null => PuzzleSound.removed,
    };
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter) {
      if (event is KeyDownEvent) {
        _cycle(_cursor);
      }
      return KeyEventResult.handled;
    }
    final step = switch (key) {
      LogicalKeyboardKey.arrowUp => -1,
      LogicalKeyboardKey.arrowDown => 1,
      // The fishers sit in one column, so the arrows across it do nothing.
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.arrowRight => 0,
      _ => null,
    };
    if (step == null) {
      return KeyEventResult.ignored;
    }
    final next = (_cursor + step).clamp(0, _game.puzzle.fisherCount - 1);
    if (next != _cursor) {
      setState(() => _cursor = next);
      _revealCursor();
    }
    return KeyEventResult.handled;
  }

  /// Scrolls the jetty, if it must, so the plank with the focus ring shows.
  void _revealCursor() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final plank = _plankKeys[_cursor].currentContext;
      if (!mounted || plank == null) {
        return;
      }
      unawaited(
        Scrollable.ensureVisible(
          plank,
          duration: _reduceMotion ? Duration.zero : _changeDuration,
          alignmentPolicy: _cursor == 0
              ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
              : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final colors = _jettyColors(Theme.of(context));
    final puzzle = _game.puzzle;
    final marked = _game.marks.marks.where((mark) => mark != null).length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Semantics(
          container: true,
          label:
              'Jetty with ${puzzle.fisherCount} fishers, '
              '$marked marked',
          child: Focus(
            focusNode: _focusNode,
            // A solved jetty takes no moves, so it gives up the focus and
            // its ring, as it is when the puzzle opens solved.
            canRequestFocus: !_game.isSolved,
            onKeyEvent: _onKeyEvent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colors.waterTop, colors.waterBottom],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var fisher = 0; fisher < puzzle.fisherCount; fisher++)
                      _lifted(fisher, _plankOf(fisher, colors)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _plankOf(int fisher, _JettyColors colors) {
    final canChange = !_game.isSolved;
    return _Plank(
      key: _plankKeys[fisher],
      fisher: fisher,
      statement: _game.puzzle.statements[fisher],
      marks: _game.marks,
      status: _game.check.statuses[fisher],
      colors: colors,
      focused: _showFocus && canChange && _cursor == fisher,
      hovered: canChange && _hovered == fisher,
      animate: !_reduceMotion,
      onTap: canChange ? () => _cycle(fisher) : null,
      onHover: (hovering) => setState(
        () => _hovered = hovering
            ? fisher
            : _hovered == fisher
            ? null
            : _hovered,
      ),
    );
  }

  /// [plank] lifting once as the wave of a solve passes, which starts at
  /// the plank that solved the puzzle.
  Widget _lifted(int fisher, Widget plank) {
    final origin = _waveOrigin;
    if (origin == null) {
      return plank;
    }
    final delay = (fisher - origin).abs() * _waveStepMs;
    final total = _wave.duration!.inMilliseconds;
    return AnimatedBuilder(
      animation: _wave,
      builder: (context, child) {
        final progress = ((_wave.value * total - delay) / _liftMs).clamp(
          0.0,
          1.0,
        );
        return Transform.translate(
          offset: Offset(0, -_liftHeight * math.sin(math.pi * progress)),
          child: child,
        );
      },
      child: plank,
    );
  }
}

/// One fisher's plank: their name and statement, and the mark the player
/// has given them.
class _Plank extends StatelessWidget {
  const _Plank({
    required this.fisher,
    required this.statement,
    required this.marks,
    required this.status,
    required this.colors,
    required this.focused,
    required this.hovered,
    required this.animate,
    required this.onTap,
    required this.onHover,
    super.key,
  });

  final int fisher;
  final TallTalesStatement statement;

  /// Every fisher's mark, for this one's and for the names in the
  /// statement.
  final TallTalesMarks marks;

  final StatementStatus status;
  final _JettyColors colors;

  /// Whether the keyboard's focus ring is on this plank.
  final bool focused;

  final bool hovered;
  final bool animate;

  /// Changes the mark, or `null` while the puzzle is solved.
  final VoidCallback? onTap;

  final ValueSetter<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = tallTalesNames[fisher];
    final mark = marks[fisher];
    final broken = status == StatementStatus.broken;
    final duration = animate ? _changeDuration : Duration.zero;
    final statementStyle = theme.textTheme.bodyLarge!.copyWith(
      color: theme.colorScheme.onSurface,
      height: 1.3,
    );
    final chipSize = MediaQuery.textScalerOf(context).scale(15);

    final plank = AnimatedContainer(
      duration: duration,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused ? colors.focus : colors.focus.withValues(alpha: 0),
          width: 2.5,
        ),
      ),
      child: AnimatedContainer(
        duration: duration,
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: BoxDecoration(
          color: hovered ? colors.plankHover : colors.plank,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: broken
                ? colors.problem
                : colors.problem.withValues(alpha: 0),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.plankShadow,
              offset: const Offset(0, 1.5),
              blurRadius: 3,
            ),
          ],
        ),
        child: Row(
          children: [
            // The speaker's name leads their words, as in a script, so a
            // plank takes no more lines than its statement.
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$name  ',
                      style: TextStyle(
                        color: colors.name,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: '“'),
                    ..._statementSpans(chipSize),
                    const TextSpan(text: '”'),
                  ],
                ),
                style: statementStyle,
              ),
            ),
            const SizedBox(width: 8),
            _MarkBadge(mark: mark, colors: colors, animate: animate),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Semantics(
        container: true,
        button: onTap != null,
        label: [
          '$name says: ${statementText(statement)}',
          switch (mark) {
            TallTalesMark.truth => 'Marked as telling the truth.',
            TallTalesMark.tallTales => 'Marked as telling tall tales.',
            null => 'Unmarked.',
          },
          if (broken) 'Does not fit the marks.',
        ].join(' '),
        onTap: onTap,
        child: ExcludeSemantics(
          child: MouseRegion(
            cursor: onTap == null
                ? MouseCursor.defer
                : SystemMouseCursors.click,
            // Flutter on the web also reports a touch as entering; only a
            // mouse really hovers.
            onEnter: (event) => onHover(event.kind == PointerDeviceKind.mouse),
            onExit: (_) => onHover(false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: onTap,
              child: plank,
            ),
          ),
        ),
      ),
    );
  }

  /// The statement, with each named fisher in bold and that fisher's mark
  /// beside the name. An unmarked name has a faint empty ring, so the text
  /// keeps its lines as marks come and go.
  List<InlineSpan> _statementSpans(double chipSize) => [
    for (final part in statementParts(statement))
      switch (part) {
        StatementWords(:final text) => TextSpan(text: text),
        StatementName(:final fisher, :final name) => TextSpan(
          children: [
            TextSpan(
              text: name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(left: 3, right: 1),
                child: SizedBox.square(
                  dimension: chipSize,
                  child: CustomPaint(
                    painter: _MarkPainter(
                      marks[fisher],
                      colors,
                      faintRing: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      },
  ];
}

/// The player's mark on a fisher, with its name below: a check for the
/// truth, a fish for tall tales or a dashed ring for none.
class _MarkBadge extends StatelessWidget {
  const _MarkBadge({
    required this.mark,
    required this.colors,
    required this.animate,
  });

  final TallTalesMark? mark;
  final _JettyColors colors;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: _badgeSize,
            child: AnimatedSwitcher(
              duration: animate ? _changeDuration : Duration.zero,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: Tween(begin: 0.6, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: CustomPaint(
                key: ValueKey(mark),
                size: const Size.square(_badgeSize),
                painter: _MarkPainter(mark, colors),
              ),
            ),
          ),
          const SizedBox(height: 1),
          // Larger text shrinks the word rather than widen the column.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              switch (mark) {
                TallTalesMark.truth => 'Truth',
                TallTalesMark.tallTales => 'Tall tales',
                // Keeps the plank as tall as a marked one.
                null => ' ',
              },
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a mark in a circle that fills its size.
class _MarkPainter extends CustomPainter {
  _MarkPainter(this.mark, this.colors, {this.faintRing = false});

  final TallTalesMark? mark;
  final _JettyColors colors;

  /// Whether no mark shows as a faint ring, beside a name in a statement,
  /// rather than as the plank's own dashed ring.
  final bool faintRing;

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = size.shortestSide;
    final center = size.center(Offset.zero);
    final radius = diameter / 2;

    switch (mark) {
      case null when faintRing:
        canvas.drawCircle(
          center,
          radius - 0.75,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = colors.unmarked.withValues(alpha: 0.35),
        );
      case null:
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, diameter * 0.055)
          ..color = colors.unmarked;
        const dashes = 12;
        const sweep = 2 * math.pi / dashes;
        final rect = Rect.fromCircle(
          center: center,
          radius: radius - ring.strokeWidth / 2,
        );
        for (var dash = 0; dash < dashes; dash++) {
          canvas.drawArc(rect, dash * sweep, sweep * 0.55, false, ring);
        }
      case TallTalesMark.truth:
        canvas.drawCircle(center, radius, Paint()..color = colors.truth);
        _glyph(canvas, center, diameter, (scale) {
          canvas.drawPath(
            Path()
              ..moveTo(5, 12.5)
              ..lineTo(9.5, 17)
              ..lineTo(19, 7.5),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..color = colors.onTruth,
          );
        });
      case TallTalesMark.tallTales:
        canvas.drawCircle(center, radius, Paint()..color = colors.tallTales);
        _glyph(canvas, center, diameter, (scale) {
          canvas
            ..drawPath(
              Path()
                ..moveTo(2, 12)
                ..cubicTo(5, 6, 12, 5.5, 16, 10)
                ..lineTo(22, 6)
                ..lineTo(22, 18)
                ..lineTo(16, 14)
                ..cubicTo(12, 18.5, 5, 18, 2, 12)
                ..close(),
              Paint()..color = colors.onTallTales,
            )
            ..drawCircle(
              const Offset(6.5, 11),
              1.4,
              Paint()..color = colors.tallTales,
            );
        });
    }
  }

  /// Runs [draw] with the canvas scaled so a glyph drawn on a square of 24
  /// units sits in the middle of the circle.
  void _glyph(
    Canvas canvas,
    Offset center,
    double diameter,
    void Function(double scale) draw,
  ) {
    final scale = diameter * 0.62 / 24;
    canvas
      ..save()
      ..translate(center.dx - 12 * scale, center.dy - 12 * scale)
      ..scale(scale);
    draw(scale);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.mark != mark ||
      oldDelegate.colors != colors ||
      oldDelegate.faintRing != faintRing;
}

/// The colors of the jetty.
typedef _JettyColors = ({
  Color waterTop,
  Color waterBottom,
  Color plank,
  Color plankHover,
  Color plankShadow,
  Color name,
  Color truth,
  Color onTruth,
  Color tallTales,
  Color onTallTales,
  Color unmarked,
  Color problem,
  Color focus,
});

/// The jetty's colors in [theme]: its teal for the truth and its error
/// color for problems, with water, planks and a brown for tall tales of
/// their own that sit calmly beside them.
_JettyColors _jettyColors(ThemeData theme) {
  final scheme = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;
  return (
    waterTop: isDark ? const Color(0xFF16363B) : const Color(0xFFD3EAED),
    waterBottom: isDark ? const Color(0xFF102B2F) : const Color(0xFFBBDCE0),
    plank: isDark ? const Color(0xFF3A332C) : const Color(0xFFF2E9DD),
    plankHover: isDark ? const Color(0xFF453D35) : const Color(0xFFF8F2EA),
    plankShadow: isDark ? const Color(0x66000000) : const Color(0x2E3C2814),
    name: isDark ? const Color(0xFFD2BDA6) : const Color(0xFF6B5544),
    truth: scheme.primary,
    onTruth: scheme.onPrimary,
    tallTales: isDark ? const Color(0xFFDDA567) : const Color(0xFF8B5A1E),
    onTallTales: isDark ? const Color(0xFF2E1C08) : const Color(0xFFFFFFFF),
    unmarked: scheme.outline,
    problem: scheme.error,
    focus: scheme.primary,
  );
}
