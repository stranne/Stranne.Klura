import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:klura/core/grid.dart';
import 'package:klura/play/puzzle_sound.dart';
import 'package:klura/puzzles/bridges/bridges_board_geometry.dart';
import 'package:klura/puzzles/bridges/bridges_board_painter.dart';
import 'package:klura/puzzles/bridges/bridges_controller.dart';
import 'package:klura/puzzles/bridges/logic/bridges_game.dart';
import 'package:klura/puzzles/bridges/logic/bridges_puzzle.dart';
import 'package:klura/puzzles/bridges/logic/bridges_rules.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';
import 'package:material_ui/material_ui.dart';

/// The playing board: islands, bridges and the gestures and keys that build
/// them.
///
/// Drag from an island toward a neighbor to cycle the bridges between them,
/// or tap a bridge, or the gap where one can go, to do the same. With the
/// keyboard, the arrow keys move between islands, two arrows together move
/// diagonally and Shift with an arrow cycles the bridges in that direction.
/// The board fills the space it is given, keeping its cells square.
class BridgesBoard extends StatefulWidget {
  const BridgesBoard({
    required this.controller,
    this.onBlocked,
    this.onSound,
    super.key,
  });

  final BridgesController controller;

  /// Called when the player tries a bridge that would cross another.
  final VoidCallback? onBlocked;

  /// Called with the sound of each move the player makes, and of a bridge
  /// that would cross another. Moving the focus makes no sound.
  final ValueSetter<PuzzleSound>? onSound;

  @override
  State<BridgesBoard> createState() => _BridgesBoardState();
}

/// Cells never grow beyond this, so the board stays calm on a large screen.
const double _maxCellSize = 60;

/// How far a drag must move, in cells, before it aims at a neighbor. A press
/// that never moves this far counts as a tap where it went down.
const double _aimDistance = 0.35;

/// How strongly the soft halo around an overfull island or a loop shows.
const double _haloAlpha = 0.16;

const Duration _changeDuration = Duration(milliseconds: 150);
const Duration _blockedDuration = Duration(milliseconds: 450);
const Duration _waveDuration = Duration(milliseconds: 1400);

final Map<LogicalKeyboardKey, Direction> _arrowDirections = {
  LogicalKeyboardKey.arrowUp: Direction.up,
  LogicalKeyboardKey.arrowRight: Direction.right,
  LogicalKeyboardKey.arrowDown: Direction.down,
  LogicalKeyboardKey.arrowLeft: Direction.left,
};

class _BridgesBoardState extends State<BridgesBoard>
    with TickerProviderStateMixin {
  late final AnimationController _change = AnimationController(
    vsync: this,
    duration: _changeDuration,
    value: 1,
  );
  late final AnimationController _blockedAnimation = AnimationController(
    vsync: this,
    duration: _blockedDuration,
    value: 1,
  );
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: _waveDuration,
    value: 1,
  );
  final FocusNode _focusNode = FocusNode(debugLabel: 'Bridges board');
  final ValueNotifier<BoardDrag?> _drag = ValueNotifier(null);
  final ValueNotifier<BoardHover?> _hover = ValueNotifier(null);

  late BridgesGame _game;
  Map<Connection, BridgeChange> _changes = const {};
  BlockedMove? _blocked;
  SolveWave? _solveWave;
  Position? _cursor;
  bool _showFocus = false;

  /// The last move of the cursor by a single arrow: its key and the island
  /// it left, so that a second arrow pressed with it can move diagonally
  /// from there instead.
  ({LogicalKeyboardKey key, Position from})? _step;

  /// The island a move in progress grows its bridge from, if any.
  Position? _growFrom;

  /// Where the press in progress went down, and whether it has since moved
  /// far enough to be a drag rather than a tap.
  Offset _pressStart = Offset.zero;
  bool _pressMovedAway = false;
  BridgesBoardGeometry? _geometry;
  bool _reduceMotion = false;

  BridgesPuzzle get _puzzle => _game.puzzle;

  @override
  void initState() {
    super.initState();
    _game = widget.controller.value;
    widget.controller.addListener(_onGameChanged);
    _focusNode.addListener(_updateFocusHighlight);
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChanged);
  }

  @override
  void didUpdateWidget(BridgesBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onGameChanged);
      widget.controller.addListener(_onGameChanged);
      _game = widget.controller.value;
      _changes = const {};
      _blocked = null;
      _solveWave = null;
      _cursor = null;
      _step = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onGameChanged);
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChanged);
    _focusNode.dispose();
    _drag.dispose();
    _hover.dispose();
    _change.dispose();
    _blockedAnimation.dispose();
    _wave.dispose();
    super.dispose();
  }

  void _onGameChanged() {
    final previous = _game;
    final current = widget.controller.value;
    final changes = {
      for (final connection in {
        ...previous.arrangement.connections,
        ...current.arrangement.connections,
      })
        if (previous.arrangement[connection] != current.arrangement[connection])
          connection: (
            from: previous.arrangement[connection],
            to: current.arrangement[connection],
            growFrom: _growFrom,
          ),
    };
    final solvedByMove =
        current.isSolved && !previous.isSolved && changes.length == 1;

    setState(() {
      _game = current;
      _changes = changes;
      _blocked = null;
      _solveWave = solvedByMove && !_reduceMotion
          ? SolveWave.from(current, changes.keys.single)
          : null;
    });
    _drag.value = null;
    _hover.value = null;
    _play(_change);
    if (_solveWave != null) {
      _play(_wave);
    }
  }

  void _play(AnimationController animation) {
    if (_reduceMotion && animation != _blockedAnimation) {
      animation.value = 1;
    } else {
      unawaited(animation.forward(from: 0));
    }
  }

  void _onHighlightModeChanged(FocusHighlightMode mode) =>
      _updateFocusHighlight();

  void _updateFocusHighlight() {
    final showFocus =
        _focusNode.hasFocus &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    if (showFocus != _showFocus) {
      setState(() => _showFocus = showFocus);
    }
  }

  /// Cycles the bridges on [connection], or shows what is in the way.
  void _cycle(Connection connection, {Position? growFrom}) {
    _growFrom = growFrom;
    final blockers = widget.controller.cycleBridges(connection);
    _growFrom = null;
    if (blockers.isEmpty) {
      unawaited(HapticFeedback.selectionClick());
      widget.onSound?.call(_soundOfMove(connection));
      return;
    }

    setState(() => _blocked = (attempt: connection, blockers: blockers));
    _play(_blockedAnimation);
    unawaited(HapticFeedback.mediumImpact());
    widget.onSound?.call(PuzzleSound.blocked);
    widget.onBlocked?.call();
  }

  /// The sound of the move that has just changed [connection]: the chime if
  /// it solved the puzzle, since a solved board takes no moves.
  PuzzleSound _soundOfMove(Connection connection) {
    if (_game.isSolved) {
      return PuzzleSound.solved;
    }
    return switch (_game.arrangement[connection]) {
      0 => PuzzleSound.removed,
      1 => PuzzleSound.bridge,
      _ => PuzzleSound.doubleBridge,
    };
  }

  Connection? _connectionToward(Position island, Direction direction) {
    final neighbor = _puzzle.neighbor(island, direction);
    return neighbor == null ? null : Connection(island, neighbor.position);
  }

  void _onPanDown(DragDownDetails details) {
    _focusNode.requestFocus();
    _pressStart = details.localPosition;
    _pressMovedAway = false;
    final geometry = _geometry;
    if (geometry == null || _game.isSolved) {
      return;
    }
    final island = geometry.dragIslandNear(
      details.localPosition,
      _game.arrangement,
    );
    _hover.value = null;
    _drag.value = island == null
        ? null
        : (island: island.position, direction: null);
    if (island != null) {
      _cursor = island.position;
      _step = null;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final geometry = _geometry;
    if (geometry == null) {
      return;
    }
    final movement = details.localPosition - _pressStart;
    if (movement.distance >= geometry.cellSize * _aimDistance) {
      _pressMovedAway = true;
    }
    final drag = _drag.value;
    if (drag == null) {
      return;
    }
    final direction = _aim(movement, geometry.cellSize, drag.direction);
    _drag.value = (island: drag.island, direction: direction);
  }

  void _onPanEnd(DragEndDetails details) {
    final drag = _drag.value;
    _drag.value = null;
    // A click or tap that slips a little turns into a drag, which should
    // still act as the tap.
    if (!_pressMovedAway) {
      _tapAt(_pressStart);
      return;
    }
    if (drag == null) {
      return;
    }
    final direction = drag.direction;
    final connection = direction == null
        ? null
        : _connectionToward(drag.island, direction);
    if (connection != null) {
      _cycle(connection, growFrom: drag.island);
    }
  }

  void _onPanCancel() => _drag.value = null;

  void _onTapUp(TapUpDetails details) => _tapAt(details.localPosition);

  /// Cycles the bridges a tap at [point] means, if any.
  void _tapAt(Offset point) {
    final geometry = _geometry;
    if (geometry == null || _game.isSolved) {
      return;
    }
    if (geometry.islandNear(point, reach: 0.45) != null) {
      return;
    }
    final connection = geometry.connectionNear(point, _game.arrangement);
    if (connection != null) {
      _cycle(connection);
    }
  }

  void _onHover(PointerHoverEvent event) {
    // Flutter on the web also reports a hover when a touch ends; only a
    // mouse really hovers.
    if (event.kind != PointerDeviceKind.mouse) {
      return;
    }
    final geometry = _geometry;
    if (geometry == null || _game.isSolved || _drag.value != null) {
      _hover.value = null;
      return;
    }
    final point = event.localPosition;
    final island = geometry.islandNear(point, reach: 0.45);
    if (island != null) {
      _hover.value = (island: island.position, connection: null);
      return;
    }
    final connection = geometry.connectionNear(point, _game.arrangement);
    _hover.value = connection == null
        ? null
        : (island: null, connection: connection);
  }

  void _onExit(PointerExitEvent event) => _hover.value = null;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final direction = _arrowDirections[event.logicalKey];
    if (direction == null || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }

    final cursor = _cursorOrFirst;
    if (HardwareKeyboard.instance.isShiftPressed) {
      _step = null;
      final connection = _connectionToward(cursor, direction);
      if (event is KeyDownEvent && connection != null && !_game.isSolved) {
        _cycle(connection, growFrom: cursor);
      }
      return KeyEventResult.handled;
    }

    final held = _arrowHeldAcross(direction);
    if (held == null) {
      final next = _islandToward(cursor, direction) ?? cursor;
      _step = (key: event.logicalKey, from: cursor);
      setState(() => _cursor = next);
      return KeyEventResult.handled;
    }

    // Two arrows pressed together move diagonally. The arrow that went down
    // first has already stepped, so the diagonal starts where that step
    // began. Without an island that way, the step stays.
    final (heldKey, heldDirection) = held;
    final step = _step;
    final from = step != null && step.key == heldKey ? step.from : cursor;
    final next = _nearestIsland(
      from,
      direction.dx + heldDirection.dx,
      direction.dy + heldDirection.dy,
    );
    if (next != null) {
      _step = null;
      setState(() => _cursor = next);
    }
    return KeyEventResult.handled;
  }

  /// An arrow key held down at right angles to [direction], if any.
  (LogicalKeyboardKey, Direction)? _arrowHeldAcross(Direction direction) {
    for (final key in HardwareKeyboard.instance.logicalKeysPressed) {
      if (_arrowDirections[key] case final held?
          when held.isHorizontal != direction.isHorizontal) {
        return (key, held);
      }
    }
    return null;
  }

  /// The island the arrow in [direction] moves to from [from]: the neighbor a
  /// bridge would reach, or else the nearest island that way.
  Position? _islandToward(Position from, Direction direction) =>
      _puzzle.neighbor(from, direction)?.position ??
      _nearestIsland(from, direction.dx, direction.dy);

  /// The island nearest the line from [from] along the step ([stepX],
  /// [stepY]), straight or diagonal, among those ahead of [from] on each
  /// axis the step moves along. Distance across the line counts double, so
  /// an island close to the line wins over a nearer one far off it.
  Position? _nearestIsland(Position from, int stepX, int stepY) {
    Position? best;
    var bestScore = 0;
    for (final island in _puzzle.islands) {
      final dx = island.position.x - from.x;
      final dy = island.position.y - from.y;
      final ahead =
          (stepX == 0 || dx * stepX > 0) && (stepY == 0 || dy * stepY > 0);
      final along = dx * stepX + dy * stepY;
      final across = (dx * stepY - dy * stepX).abs();
      final score = along + 2 * across;
      if (ahead && (best == null || score < bestScore)) {
        best = island.position;
        bestScore = score;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scheme = Theme.of(context).colorScheme;
    final BoardColors colors = (
      dot: scheme.outlineVariant,
      bridge: scheme.onSurfaceVariant,
      solvedBridge: scheme.primary,
      preview: scheme.primary,
      problem: scheme.error,
      problemHalo: scheme.error.withValues(alpha: _haloAlpha),
      guide: scheme.outline,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = [
          constraints.maxWidth / _puzzle.width,
          constraints.maxHeight / _puzzle.height,
          _maxCellSize,
        ].reduce(math.min);
        final geometry = BridgesBoardGeometry(_puzzle, cellSize);
        _geometry = geometry;

        final board = Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: BridgesBoardPainter(
                  geometry: geometry,
                  game: _game,
                  colors: colors,
                  changes: _changes,
                  change: _change,
                  drag: _drag,
                  hover: _hover,
                  blocked: _blocked,
                  blockedAnimation: _blockedAnimation,
                  solveWave: _solveWave,
                  wave: _wave,
                  focusedIsland: _showFocus ? _cursorOrFirst : null,
                  reduceMotion: _reduceMotion,
                ),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: _drag,
              builder: (context, drag, _) => _IslandsLayer(
                geometry: geometry,
                game: _game,
                drag: drag,
                focusedIsland: _showFocus ? _cursorOrFirst : null,
                solveWave: _solveWave,
                wave: _wave,
              ),
            ),
          ],
        );

        return Center(
          child: SizedBox.fromSize(
            size: geometry.size,
            child: Semantics(
              container: true,
              // The filled islands show progress at a glance; a screen
              // reader hears it here.
              label:
                  'Bridges board, ${_puzzle.width} columns by '
                  '${_puzzle.height} rows, ${_puzzle.islands.length} islands, '
                  '$_completeIslands complete',
              child: Focus(
                focusNode: _focusNode,
                // A solved board takes no moves, so it gives up the focus
                // and its ring, as it is when the puzzle opens solved.
                canRequestFocus: !_game.isSolved,
                onKeyEvent: _onKeyEvent,
                child: ValueListenableBuilder(
                  valueListenable: _hover,
                  builder: (context, hover, child) => MouseRegion(
                    cursor: hover == null
                        ? MouseCursor.defer
                        : SystemMouseCursors.click,
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
                    child: board,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Position get _cursorOrFirst => _cursor ?? _puzzle.islands.first.position;

  int get _completeIslands => _game.check.islandStatuses.values
      .where((status) => status == IslandStatus.met)
      .length;
}

/// The direction a drag that has moved by [movement] aims in, or `null`
/// while it is too short to tell.
///
/// The drag keeps its [current] direction until the other axis clearly
/// leads, so a diagonal drag does not flicker between two neighbors.
Direction? _aim(Offset movement, double cellSize, Direction? current) {
  if (movement.distance < cellSize * _aimDistance) {
    return null;
  }
  final dx = movement.dx.abs();
  final dy = movement.dy.abs();
  var horizontal = dx >= dy;
  if (current != null && current.isHorizontal != horizontal) {
    final (along, across) = current.isHorizontal ? (dx, dy) : (dy, dx);
    if (across < along * 1.3) {
      horizontal = current.isHorizontal;
    }
  }
  if (horizontal) {
    return movement.dx > 0 ? Direction.right : Direction.left;
  }
  return movement.dy > 0 ? Direction.down : Direction.up;
}

/// The islands, drawn as widgets above the painted bridges so each has its
/// own semantics and animates its state.
class _IslandsLayer extends StatelessWidget {
  const _IslandsLayer({
    required this.geometry,
    required this.game,
    required this.drag,
    required this.focusedIsland,
    required this.solveWave,
    required this.wave,
  });

  final BridgesBoardGeometry geometry;
  final BridgesGame game;
  final BoardDrag? drag;
  final Position? focusedIsland;
  final SolveWave? solveWave;
  final Animation<double> wave;

  @override
  Widget build(BuildContext context) {
    final target = switch (drag) {
      (island: final from, direction: final direction?) =>
        game.puzzle.neighbor(from, direction)?.position,
      _ => null,
    };

    return Stack(
      children: [
        for (final island in game.puzzle.islands)
          Positioned.fromRect(
            rect: geometry.rectOf(island.position),
            child: _waving(
              island.position,
              _IslandView(
                island: island,
                status: game.check.islandStatuses[island.position]!,
                label: _islandLabel(island, game),
                diameter: geometry.islandRadius * 2,
                highlighted:
                    island.position == drag?.island ||
                    island.position == target,
                focused: island.position == focusedIsland,
              ),
            ),
          ),
      ],
    );
  }

  Widget _waving(Position island, Widget child) {
    final solveWave = this.solveWave;
    if (solveWave == null) {
      return child;
    }
    return AnimatedBuilder(
      animation: wave,
      builder: (context, child) => Transform.scale(
        scale: 1 + 0.18 * solveWave.pulseAt(island, wave.value),
        child: child,
      ),
      child: child,
    );
  }
}

class _IslandView extends StatelessWidget {
  const _IslandView({
    required this.island,
    required this.status,
    required this.label,
    required this.diameter,
    required this.highlighted,
    required this.focused,
  });

  final Island island;
  final IslandStatus status;
  final String label;
  final double diameter;
  final bool highlighted;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (fill, border, text) = switch (status) {
      IslandStatus.under => (scheme.surface, scheme.outline, scheme.onSurface),
      IslandStatus.met => (scheme.primary, scheme.primary, scheme.onPrimary),
      IslandStatus.over => (scheme.surface, scheme.error, scheme.error),
    };
    final ring = diameter * 0.07;
    final halo = switch ((status, highlighted)) {
      (IslandStatus.over, _) => scheme.error.withValues(alpha: _haloAlpha),
      (_, true) => scheme.primary.withValues(alpha: 0.22),
      _ => null,
    };

    return Semantics(
      container: true,
      label: label,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: diameter,
          height: diameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(color: border, width: math.max(1.5, ring)),
            boxShadow: [
              // A keyboard focus ring with a gap, or else a soft halo.
              if (focused) ...[
                BoxShadow(
                  color: scheme.primary,
                  spreadRadius: math.max(2, ring) + math.max(2, ring * 0.8),
                ),
                BoxShadow(
                  color: scheme.surface,
                  spreadRadius: math.max(2, ring),
                ),
              ] else if (halo != null)
                BoxShadow(color: halo, spreadRadius: ring * 2.5),
            ],
          ),
          child: ExcludeSemantics(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: theme.textTheme.titleMedium!.copyWith(
                color: text,
                fontSize: diameter * 0.52,
                fontWeight: FontWeight.w600,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              // The number is sized to its island, which grows with the
              // board. Larger text would push it out of the circle.
              child: Text(
                '${island.requiredBridges}',
                textScaler: TextScaler.noScaling,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Describes [island] for a screen reader: its number, place and bridges.
String _islandLabel(Island island, BridgesGame game) {
  final position = island.position;
  final required = island.requiredBridges;
  final placed = game.arrangement.bridgesTouching(position);
  final state = switch (game.check.islandStatuses[position]!) {
    IslandStatus.under => '$placed of $required bridges',
    IslandStatus.met => 'complete',
    IslandStatus.over => '$placed bridges, too many',
  };
  final bridges = [
    for (final direction in Direction.values)
      if (game.puzzle.neighbor(position, direction) case final neighbor?)
        if (game.arrangement[Connection(position, neighbor.position)]
            case final count when count > 0)
          '$count ${_directionNames[direction]}',
  ];
  return [
    'Island $required, row ${position.y + 1}, column ${position.x + 1}',
    state,
    if (bridges.isNotEmpty) bridges.join(', '),
  ].join('. ');
}

const Map<Direction, String> _directionNames = {
  Direction.up: 'up',
  Direction.right: 'to the right',
  Direction.down: 'down',
  Direction.left: 'to the left',
};
