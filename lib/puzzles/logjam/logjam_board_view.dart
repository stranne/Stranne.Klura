import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:klura/core/grid.dart';
import 'package:klura/play/puzzle_sound.dart';
import 'package:klura/puzzles/logjam/logic/logjam_board.dart';
import 'package:klura/puzzles/logjam/logic/logjam_game.dart';
import 'package:klura/puzzles/logjam/logjam_board_geometry.dart';
import 'package:klura/puzzles/logjam/logjam_board_painter.dart';
import 'package:klura/puzzles/logjam/logjam_controller.dart';
import 'package:material_ui/material_ui.dart';

/// The playing board: the river with its logs and the gestures and keys
/// that slide them.
///
/// Drag a log along its length and let go: it follows the finger as far as
/// the water is clear and settles in the nearest cell. A tap only shows how
/// far a log can slide, since every move counts. With the keyboard, the
/// arrow keys move between logs and Shift with an arrow slides one a cell.
/// The board fills the space it is given, keeping its cells square.
class LogjamBoardView extends StatefulWidget {
  const LogjamBoardView({
    required this.controller,
    required this.focusNode,
    this.onSound,
    super.key,
  });

  final LogjamController controller;

  /// The board's keyboard focus, owned by the screen, which also gives it to
  /// the board when the player presses an arrow key elsewhere.
  final FocusNode focusNode;

  /// Called with the sound of each slide, and of a log pushed against what
  /// stops it. Moving the focus makes no sound.
  final ValueSetter<PuzzleSound>? onSound;

  @override
  State<LogjamBoardView> createState() => _LogjamBoardViewState();
}

/// Cells never grow beyond this, so the board stays calm on a large screen.
const double _maxCellSize = 60;

/// How far a press must move, in cells, before it is a drag. A press that
/// never moves this far counts as a tap.
const double _dragDistance = 1 / 3;

/// How far past what stops it a dragged log must be pushed, in cells,
/// before it knocks, so that a drag that just overshoots stays quiet.
const double _pushDistance = 0.25;

const Duration _glideDuration = Duration(milliseconds: 140);
const Duration _laneFadeDuration = Duration(milliseconds: 200);
const Duration _tapLaneDuration = Duration(milliseconds: 1200);
const Duration _blockedDuration = Duration(milliseconds: 900);
const Duration _solveDuration = Duration(milliseconds: 1600);

/// The share of [_blockedDuration] the marks of a stopped slide hold before
/// they fade.
const double _blockedHold = 0.35;

final Map<LogicalKeyboardKey, Direction> _arrowDirections = {
  LogicalKeyboardKey.arrowUp: Direction.up,
  LogicalKeyboardKey.arrowRight: Direction.right,
  LogicalKeyboardKey.arrowDown: Direction.down,
  LogicalKeyboardKey.arrowLeft: Direction.left,
};

/// The brown of the tree trunks in Tents, which the logs share, since logs
/// are the one place wood is literal. It is a little lighter or darker on
/// the larger areas of a log.
const Color _lightTrunk = Color(0xFF7A6250);
const Color _darkTrunk = Color(0xFFB09783);

class _LogjamBoardViewState extends State<LogjamBoardView>
    with TickerProviderStateMixin {
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: _glideDuration,
    value: 1,
  );
  late final AnimationController _laneOpacity = AnimationController(
    vsync: this,
    duration: _laneFadeDuration,
  );
  late final AnimationController _blockedAnimation = AnimationController(
    vsync: this,
    duration: _blockedDuration,
    value: 1,
  );
  late final AnimationController _solve = AnimationController(
    vsync: this,
    duration: _solveDuration,
    value: 1,
  );
  final ValueNotifier<LogDrag?> _drag = ValueNotifier(null);
  final ValueNotifier<bool> _overLog = ValueNotifier(false);

  late LogjamGame _game;
  Map<int, double> _glideFrom = const {};
  int? _lane;
  LogBlock? _blocked;
  int _cursor = 0;
  bool _showFocus = false;

  /// The log the press in progress holds, where the press went down,
  /// whether it has moved far enough to be a drag and the side the log is
  /// pushed against, 0 while it is pushed against nothing.
  int? _pressPiece;
  Offset _pressStart = Offset.zero;
  bool _pressMovedAway = false;
  int _pushSide = 0;

  /// Where a released log glides from, for the change it makes.
  Map<int, double> _releasedAt = const {};

  LogjamBoardGeometry? _geometry;
  bool _reduceMotion = false;

  FocusNode get _focusNode => widget.focusNode;
  LogjamBoard get _board => _game.board;

  @override
  void initState() {
    super.initState();
    _game = widget.controller.value;
    widget.controller.addListener(_onGameChanged);
    _focusNode.addListener(_updateFocusHighlight);
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChanged);
  }

  @override
  void didUpdateWidget(LogjamBoardView oldWidget) {
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
      _glideFrom = const {};
      _lane = null;
      _blocked = null;
      _cursor = 0;
      _pressPiece = null;
      _drag.value = null;
      _solve.value = 1;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onGameChanged);
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChanged);
    _focusNode.removeListener(_updateFocusHighlight);
    _drag.dispose();
    _overLog.dispose();
    _glide.dispose();
    _laneOpacity.dispose();
    _blockedAnimation.dispose();
    _solve.dispose();
    super.dispose();
  }

  /// Glides every log the change moved from where it showed to where it now
  /// lies, and lets the marked log float out if the change solved the
  /// puzzle.
  void _onGameChanged() {
    final previous = _game;
    final current = widget.controller.value;
    final glideFrom = <int, double>{
      for (final (index, piece) in current.board.pieces.indexed)
        if (piece != previous.board.pieces[index])
          index: _releasedAt[index] ?? _shownOffset(index),
    };
    final solvedByMove = current.isSolved && !previous.isSolved;

    // A change from elsewhere, such as an undo from the keyboard, ends a
    // drag in progress, whose log may no longer have the room it had.
    _pressPiece = null;
    _pushSide = 0;
    _drag.value = null;
    setState(() {
      _game = current;
      _glideFrom = glideFrom;
      _blocked = null;
    });
    _releasedAt = const {};
    _play(_glide);
    if (solvedByMove) {
      _laneOpacity.value = 0;
      _play(_solve);
    } else if (!current.isSolved) {
      _solve.value = 1;
    }
  }

  /// Where the log at [index] shows along its line now, while it may still
  /// be gliding.
  double _shownOffset(int index) {
    final to = _board.pieces[index].offset.toDouble();
    final from = _glideFrom[index];
    if (from == null) {
      return to;
    }
    final progress = Curves.easeOutCubic.transform(_glide.value);
    return from + (to - from) * progress;
  }

  void _play(AnimationController animation) {
    if (_reduceMotion) {
      animation.value = 1;
    } else {
      unawaited(animation.forward(from: 0));
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

  /// Slides the log at [piece] to [to] and plays its sound: a lower one for
  /// a longer log, or the chime if the slide solves the puzzle.
  void _slide(int piece, int to) {
    widget.controller.slide(LogjamMove(piece: piece, to: to));
    unawaited(HapticFeedback.selectionClick());
    final sound = _game.isSolved
        ? PuzzleSound.solved
        : _board.pieces[piece].length > LogjamPiece.minLength
        ? PuzzleSound.longLog
        : PuzzleSound.log;
    widget.onSound?.call(sound);
  }

  /// Shows what stops the log at [piece] from sliding toward [side], with a
  /// knock. A [byKey] push nudges the log and lets the marks fade at once;
  /// a drag holds them until the finger eases off.
  void _knock(int piece, int side, {required bool byKey}) {
    final log = _board.pieces[piece];
    final edge = side > 0
        ? _board.highestOffset(piece) + log.length
        : _board.lowestOffset(piece);
    final beyond = side > 0 ? edge : edge - 1;
    final blocker = _board.pieceAt(
      log.isHorizontal ? Position(beyond, log.y) : Position(log.x, beyond),
    );
    setState(
      () => _blocked = (
        piece: piece,
        side: side,
        blocker: blocker,
        byKey: byKey,
      ),
    );
    if (byKey) {
      unawaited(_blockedAnimation.forward(from: 0));
    } else {
      _blockedAnimation
        ..stop()
        ..value = 0;
    }
    unawaited(HapticFeedback.lightImpact());
    widget.onSound?.call(PuzzleSound.blocked);
  }

  /// Lets the marks of a drag pushed against something fade, once the
  /// finger eases off.
  void _easeOff() {
    if (_pushSide != 0) {
      _pushSide = 0;
      unawaited(_blockedAnimation.forward(from: _blockedHold));
    }
  }

  /// Shows the lane of [piece], how far it can slide, for as long as it is
  /// held.
  void _showLane(int piece) {
    setState(() => _lane = piece);
    _laneOpacity
      ..stop()
      ..value = 1;
  }

  /// Lets the lane fade, after a moment if a tap showed it.
  void _hideLane({bool afterTap = false}) {
    if (afterTap) {
      unawaited(
        _laneOpacity.animateTo(
          0,
          duration: _tapLaneDuration,
          curve: const Interval(0.75, 1),
        ),
      );
    } else {
      unawaited(_laneOpacity.animateTo(0, duration: _laneFadeDuration));
    }
  }

  /// The log on the cell under [point], if any.
  int? _pieceAt(Offset point) {
    final cell = _geometry?.cellAt(point);
    return cell == null ? null : _board.pieceAt(cell);
  }

  void _onPanDown(DragDownDetails details) {
    _focusNode.requestFocus();
    _pressStart = details.localPosition;
    _pressMovedAway = false;
    _pushSide = 0;
    final piece = _game.isSolved ? null : _pieceAt(details.localPosition);
    _pressPiece = piece;
    if (piece != null) {
      _cursor = piece;
      _showLane(piece);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final geometry = _geometry;
    final piece = _pressPiece;
    if (geometry == null || piece == null || _game.isSolved) {
      return;
    }
    final movement = details.localPosition - _pressStart;
    if (movement.distance >= geometry.cellSize * _dragDistance) {
      _pressMovedAway = true;
    }
    final log = _board.pieces[piece];
    final wanted =
        log.offset +
        (log.isHorizontal ? movement.dx : movement.dy) / geometry.cellSize;
    final lowest = _board.lowestOffset(piece);
    final highest = _board.highestOffset(piece);
    _drag.value = (
      piece: piece,
      offset: wanted.clamp(lowest, highest).toDouble(),
    );

    // The marked log at the end of a clear row floats out, so nothing
    // stops it there.
    final reachesExit = piece == 0 && highest + log.length == _board.width;
    final side = wanted < lowest - _pushDistance
        ? -1
        : wanted > highest + _pushDistance && !reachesExit
        ? 1
        : 0;
    if (side != 0 && side != _pushSide) {
      _pushSide = side;
      _knock(piece, side, byKey: false);
    } else if (side == 0) {
      _easeOff();
    }
  }

  void _onPanEnd(DragEndDetails details) => _release();

  void _onPanCancel() => _release(cancelled: true);

  /// Ends the press in progress: a drag settles its log in the nearest cell
  /// and a tap shows the lane for a moment.
  void _release({bool cancelled = false}) {
    final piece = _pressPiece;
    final drag = _drag.value;
    _pressPiece = null;
    _drag.value = null;
    _easeOff();
    if (piece == null) {
      return;
    }
    if (!_pressMovedAway && !cancelled) {
      _hideLane(afterTap: true);
    } else {
      _hideLane();
    }
    if (drag == null) {
      return;
    }

    final target = drag.offset.round();
    if (!cancelled &&
        _pressMovedAway &&
        _board.canMove(LogjamMove(piece: piece, to: target))) {
      _releasedAt = {piece: drag.offset};
      _slide(piece, target);
      return;
    }
    // Back to where it lay, without a move.
    setState(() => _glideFrom = {piece: drag.offset});
    _play(_glide);
  }

  void _onTapUp(TapUpDetails details) {
    final piece = _game.isSolved ? null : _pieceAt(details.localPosition);
    if (piece == null) {
      return;
    }
    _cursor = piece;
    _showLane(piece);
    _hideLane(afterTap: true);
  }

  void _onHover(PointerHoverEvent event) {
    // Flutter on the web also reports a hover when a touch ends; only a
    // mouse really hovers.
    if (event.kind != PointerDeviceKind.mouse) {
      return;
    }
    _overLog.value = !_game.isSolved && _pieceAt(event.localPosition) != null;
  }

  void _onExit(PointerExitEvent event) => _overLog.value = false;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final direction = _arrowDirections[event.logicalKey];
    if (direction == null || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    if (_game.isSolved) {
      return KeyEventResult.handled;
    }

    final cursor = _cursor;
    if (HardwareKeyboard.instance.isShiftPressed) {
      final log = _board.pieces[cursor];
      // A log slides only along its length; Shift with a key across it does
      // nothing.
      if (direction.isHorizontal == log.isHorizontal) {
        final side = direction.dx + direction.dy;
        final to = log.offset + side;
        if (_board.canMove(LogjamMove(piece: cursor, to: to))) {
          _slide(cursor, to);
        } else if (event is KeyDownEvent) {
          _knock(cursor, side, byKey: true);
        }
      }
      return KeyEventResult.handled;
    }

    if (_nearestLog(cursor, direction) case final next?) {
      setState(() => _cursor = next);
    }
    return KeyEventResult.handled;
  }

  /// The log the arrow in [direction] moves to from the log at [from]: among
  /// the logs whose middle lies ahead of its middle, the one with a cell
  /// nearest a cell of it that way. Distance across counts double, so a log
  /// in line wins over a nearer one off to the side.
  ///
  /// Measuring from cells rather than middles keeps a long log beside the
  /// focused one from losing to a short one a row away.
  int? _nearestLog(int from, Direction direction) {
    final current = _board.pieces[from];
    final (fromX, fromY) = _doubledMiddle(current);
    int? best;
    var bestScore = 0;
    for (final (index, piece) in _board.pieces.indexed) {
      final (x, y) = _doubledMiddle(piece);
      if ((x - fromX) * direction.dx + (y - fromY) * direction.dy <= 0) {
        continue;
      }
      final score = _stepScore(current, piece, direction);
      if (score != null && (best == null || score < bestScore)) {
        best = index;
        bestScore = score;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final trunk = isDark ? _darkTrunk : _lightTrunk;
    final LogjamColors colors = (
      water: Color.lerp(
        scheme.surface,
        scheme.primaryContainer,
        isDark ? 0.55 : 0.42,
      )!,
      current: scheme.primary.withValues(alpha: isDark ? 0.26 : 0.22),
      dot: scheme.primary.withValues(alpha: isDark ? 0.34 : 0.3),
      boom: scheme.outline,
      bark: isDark
          ? Color.lerp(trunk, scheme.surface, 0.26)!
          : Color.lerp(trunk, Colors.white, 0.06)!,
      barkLine: isDark
          ? Color.lerp(trunk, scheme.surface, 0.62)!
          : Color.lerp(trunk, Colors.black, 0.34)!,
      face: Color.lerp(trunk, Colors.white, isDark ? 0.22 : 0.55)!,
      ring: isDark
          ? Color.lerp(trunk, scheme.surface, 0.5)!
          : Color.lerp(trunk, Colors.black, 0.1)!,
      highlight: Colors.white.withValues(alpha: isDark ? 0.1 : 0.17),
      shadow: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
      liftShadow: Colors.black.withValues(alpha: isDark ? 0.55 : 0.28),
      marked: scheme.primary,
      markedFace: isDark
          ? Color.lerp(scheme.primary, Colors.white, 0.5)!
          : scheme.primaryContainer,
      markedRing: isDark
          ? Color.lerp(scheme.primary, scheme.surface, 0.45)!
          : scheme.primary,
      markedLine: isDark
          ? Color.lerp(scheme.primary, scheme.surface, 0.45)!
          : Color.lerp(scheme.primary, Colors.black, 0.3)!,
      chevron: scheme.onPrimary,
      lane: scheme.primary.withValues(alpha: isDark ? 0.24 : 0.16),
      ripple: scheme.primary.withValues(alpha: isDark ? 0.7 : 0.55),
      focus: scheme.primary,
      problem: scheme.error,
      halo: scheme.surface,
    );
    final board = _board;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = [
          constraints.maxWidth / LogjamBoardGeometry.widthInCells(board.width),
          constraints.maxHeight /
              LogjamBoardGeometry.heightInCells(board.height),
          _maxCellSize,
        ].reduce(math.min);
        final geometry = LogjamBoardGeometry(
          width: board.width,
          height: board.height,
          cellSize: cellSize,
        );
        _geometry = geometry;

        final painted = Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: LogjamBoardPainter(
                  geometry: geometry,
                  board: board,
                  colors: colors,
                  glideFrom: _glideFrom,
                  glide: _glide,
                  drag: _drag,
                  lane: _lane,
                  laneOpacity: _laneOpacity,
                  blocked: _blocked,
                  blockedAnimation: _blockedAnimation,
                  focusedPiece: _showFocus && !_game.isSolved ? _cursor : null,
                  solve: _solve,
                  reduceMotion: _reduceMotion,
                ),
              ),
            ),
            ..._logSemantics(geometry),
          ],
        );

        return Center(
          child: SizedBox.fromSize(
            size: geometry.size,
            child: Semantics(
              container: true,
              label: _boardLabel(),
              child: Focus(
                focusNode: _focusNode,
                // A solved board takes no moves, so it gives up the focus
                // and its ring, as it is when the puzzle opens solved.
                canRequestFocus: !_game.isSolved,
                onKeyEvent: _onKeyEvent,
                child: ListenableBuilder(
                  listenable: Listenable.merge([_overLog, _drag]),
                  builder: (context, child) => MouseRegion(
                    cursor: _drag.value != null
                        ? SystemMouseCursors.grabbing
                        : _overLog.value
                        ? SystemMouseCursors.grab
                        : MouseCursor.defer,
                    onHover: _onHover,
                    onExit: _onExit,
                    child: child,
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTapUp: _onTapUp,
                    onPanDown: _onPanDown,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    onPanCancel: _onPanCancel,
                    child: painted,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _boardLabel() {
    final board = _board;
    final where = _game.isSolved
        ? 'The marked log has floated out'
        : 'The marked log lies in row ${board.exitRow + 1}, '
              '${_span('column', board.marked.x, board.marked.length)}';
    return 'Logjam board, ${board.width} columns by ${board.height} rows, '
        '${board.pieces.length} logs. The gap in the boom is at the right '
        'end of row ${board.exitRow + 1}. $where.';
  }

  /// A node for each log, so a screen reader can find each one and how far
  /// it can slide.
  List<Widget> _logSemantics(LogjamBoardGeometry geometry) => [
    for (final (index, piece) in _board.pieces.indexed)
      if (index != 0 || !_game.isSolved)
        Positioned.fromRect(
          rect: geometry.pieceRect(piece),
          child: Semantics(
            container: true,
            label: _logLabel(index, piece),
            child: const SizedBox.expand(),
          ),
        ),
  ];

  /// Describes the log at [index], such as `Marked log, 2 cells, row 3,
  /// columns 3 to 4, can slide 2 right`.
  String _logLabel(int index, LogjamPiece piece) {
    final lower = piece.offset - _board.lowestOffset(index);
    final higher = _board.highestOffset(index) - piece.offset;
    final (back, ahead) = piece.isHorizontal
        ? ('left', 'right')
        : ('up', 'down');
    final slides = [
      if (lower > 0) '$lower $back',
      if (higher > 0) '$higher $ahead',
    ];
    return [
      if (index == 0) 'Marked log' else 'Log',
      '${piece.length} cells',
      if (piece.isHorizontal)
        'row ${piece.y + 1}, ${_span('column', piece.x, piece.length)}'
      else
        'column ${piece.x + 1}, ${_span('row', piece.y, piece.length)}',
      if (slides.isEmpty)
        'cannot slide'
      else
        'can slide ${slides.join(' and ')}',
    ].join(', ');
  }
}

/// The lines from [first] on, [length] of them, counted from 1, such as
/// `columns 3 to 4`.
String _span(String line, int first, int length) =>
    '${line}s ${first + 1} to ${first + length}';

/// The shortest step from a cell of [from] to a cell of [to] ahead of it in
/// [direction], the distance across counting double, or `null` if no cell
/// of [to] lies ahead.
int? _stepScore(LogjamPiece from, LogjamPiece to, Direction direction) {
  int? best;
  for (final start in from.cells) {
    for (final end in to.cells) {
      final dx = end.x - start.x;
      final dy = end.y - start.y;
      final along = dx * direction.dx + dy * direction.dy;
      if (along <= 0) {
        continue;
      }
      final score = along + 2 * (dx * direction.dy - dy * direction.dx).abs();
      if (best == null || score < best) {
        best = score;
      }
    }
  }
  return best;
}

/// The middle of [piece] in half cells, so it is a whole number.
(int, int) _doubledMiddle(LogjamPiece piece) => piece.isHorizontal
    ? (2 * piece.x + piece.length, 2 * piece.y + 1)
    : (2 * piece.x + 1, 2 * piece.y + piece.length);
