import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/tents/logic/tents_game.dart';
import 'package:klura/puzzles/tents/logic/tents_marks.dart';
import 'package:klura/puzzles/tents/logic/tents_rules.dart';
import 'package:klura/puzzles/tents/tents_board_geometry.dart';
import 'package:klura/puzzles/tents/tents_board_painter.dart';
import 'package:klura/puzzles/tents/tents_controller.dart';
import 'package:material_ui/material_ui.dart';

/// The playing board: the trees, the numbers of each row and column and the
/// gestures and keys that place tents and grass.
///
/// Tap a cell to move it through grass, a tent and empty. Drag along a row
/// or column to put grass on every empty cell on the way, or, from a cell
/// with grass, to clear grass. With the keyboard, the arrow keys move
/// between cells and Space or Enter changes one. The board fills the space
/// it is given, keeping its cells square.
class TentsBoard extends StatefulWidget {
  const TentsBoard({required this.controller, super.key});

  final TentsController controller;

  @override
  State<TentsBoard> createState() => _TentsBoardState();
}

/// Cells never grow beyond this, so the board stays calm on a large screen.
const double _maxCellSize = 60;

/// How far a press must move, in cells, before it is a drag. A press that
/// never moves this far counts as a tap where it went down.
const double _dragDistance = 0.35;

/// How strongly the soft marks around broken rules show.
const double _haloAlpha = 0.16;

const Duration _changeDuration = Duration(milliseconds: 160);
const Duration _waveDuration = Duration(milliseconds: 1200);

final Map<LogicalKeyboardKey, Direction> _arrowDirections = {
  LogicalKeyboardKey.arrowUp: Direction.up,
  LogicalKeyboardKey.arrowRight: Direction.right,
  LogicalKeyboardKey.arrowDown: Direction.down,
  LogicalKeyboardKey.arrowLeft: Direction.left,
};

class _TentsBoardState extends State<TentsBoard> with TickerProviderStateMixin {
  late final AnimationController _change = AnimationController(
    vsync: this,
    duration: _changeDuration,
    value: 1,
  );
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: _waveDuration,
    value: 1,
  );
  final FocusNode _focusNode = FocusNode(debugLabel: 'Tents board');
  final ValueNotifier<GrassDrag?> _drag = ValueNotifier(null);
  final ValueNotifier<Position?> _hover = ValueNotifier(null);

  late TentsGame _game;
  Map<Position, MarkChange> _changes = const {};
  SolveWave? _solveWave;
  Position _cursor = const Position(0, 0);
  bool _showFocus = false;

  /// Where the press in progress went down, the cell there, whether it has
  /// moved far enough to be a drag and, once it has, whether it runs along
  /// a row.
  Offset _pressStart = Offset.zero;
  Position? _pressCell;
  bool _pressMovedAway = false;
  bool? _alongRow;

  TentsBoardGeometry? _geometry;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _game = widget.controller.value;
    widget.controller.addListener(_onGameChanged);
    _focusNode.addListener(_updateFocusHighlight);
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChanged);
  }

  @override
  void didUpdateWidget(TentsBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onGameChanged);
      widget.controller.addListener(_onGameChanged);
      _game = widget.controller.value;
      _changes = const {};
      _solveWave = null;
      _cursor = const Position(0, 0);
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
    _wave.dispose();
    super.dispose();
  }

  void _onGameChanged() {
    final previous = _game;
    final current = widget.controller.value;
    final changes = <Position, MarkChange>{
      for (final position in {
        ...previous.marks.marks.keys,
        ...current.marks.marks.keys,
      })
        if (previous.marks[position] != current.marks[position])
          position: (
            from: previous.marks[position],
            to: current.marks[position],
          ),
    };
    final solvedByMove =
        current.isSolved && !previous.isSolved && changes.length == 1;

    setState(() {
      _game = current;
      _changes = changes;
      _solveWave = solvedByMove && !_reduceMotion
          ? SolveWave(
              changes.keys.single,
              current.puzzle.width,
              current.puzzle.height,
            )
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
    if (_reduceMotion) {
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

  bool _isFree(Position position) => !_game.puzzle.hasTree(position);

  /// Moves [position] to its next mark, if it is a free cell.
  void _cycle(Position position) {
    if (_game.isSolved || !_isFree(position)) {
      return;
    }
    _cursor = position;
    widget.controller.cycleMark(position);
    unawaited(HapticFeedback.selectionClick());
  }

  void _onPanDown(DragDownDetails details) {
    _focusNode.requestFocus();
    _pressStart = details.localPosition;
    _pressCell = _geometry?.cellAt(details.localPosition);
    _pressMovedAway = false;
    _alongRow = null;
    _hover.value = null;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final geometry = _geometry;
    final start = _pressCell;
    if (geometry == null || start == null || _game.isSolved) {
      return;
    }
    final movement = details.localPosition - _pressStart;
    if (!_pressMovedAway &&
        movement.distance < geometry.cellSize * _dragDistance) {
      return;
    }
    _pressMovedAway = true;
    final alongRow = _alongRow = _axis(movement, _alongRow);

    final end = geometry.nearestCell(details.localPosition);
    final cells = alongRow
        ? _line(start, Position(end.x, start.y))
        : _line(start, Position(start.x, end.y));
    final clearing = _game.marks[start] == TentsMark.grass;
    _drag.value = (
      cells: clearing ? _game.grassCells(cells) : _game.fillableCells(cells),
      clearing: clearing,
    );
  }

  void _onPanEnd(DragEndDetails details) {
    final drag = _drag.value;
    _drag.value = null;
    // A click or tap that slips a little turns into a drag, which should
    // still act as the tap.
    if (!_pressMovedAway) {
      if (_pressCell case final cell?) {
        _cycle(cell);
      }
      return;
    }
    if (drag == null || drag.cells.isEmpty || _game.isSolved) {
      return;
    }
    if (drag.clearing) {
      widget.controller.clearGrass(drag.cells);
    } else {
      widget.controller.fillGrass(drag.cells);
    }
    unawaited(HapticFeedback.selectionClick());
  }

  void _onPanCancel() => _drag.value = null;

  void _onTapUp(TapUpDetails details) {
    if (_geometry?.cellAt(details.localPosition) case final cell?) {
      _cycle(cell);
    }
  }

  void _onHover(PointerHoverEvent event) {
    // Flutter on the web also reports a hover when a touch ends; only a
    // mouse really hovers.
    if (event.kind != PointerDeviceKind.mouse) {
      return;
    }
    final cell = _geometry?.cellAt(event.localPosition);
    _hover.value =
        cell != null && _isFree(cell) && !_game.isSolved && _drag.value == null
        ? cell
        : null;
  }

  void _onExit(PointerExitEvent event) => _hover.value = null;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      if (event is KeyDownEvent) {
        _cycle(_cursor);
      }
      return KeyEventResult.handled;
    }
    final direction = _arrowDirections[event.logicalKey];
    if (direction == null) {
      return KeyEventResult.ignored;
    }
    final next = _cursor.step(direction);
    if (_game.puzzle.contains(next)) {
      setState(() => _cursor = next);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final TentsColors colors = (
      board: scheme.surfaceContainerLowest,
      line: scheme.outlineVariant,
      grass: (isDark ? _darkGrass : _lightGrass),
      tuft: (isDark ? _darkCrown : _lightCrown).withValues(alpha: 0.7),
      crown: isDark ? _darkCrown : _lightCrown,
      trunk: isDark ? _darkTrunk : _lightTrunk,
      tent: scheme.primary,
      door: scheme.surfaceContainerLowest,
      problem: scheme.error,
      problemHalo: scheme.error.withValues(alpha: _haloAlpha),
      focus: scheme.primary,
    );
    final puzzle = _game.puzzle;
    final rowPlaced = List.filled(puzzle.height, 0);
    final columnPlaced = List.filled(puzzle.width, 0);
    for (final tent in _game.marks.tents) {
      rowPlaced[tent.y]++;
      columnPlaced[tent.x]++;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = [
          constraints.maxWidth /
              (puzzle.width + tentsClueStrip + tentsBoardMargin),
          constraints.maxHeight /
              (puzzle.height + tentsClueStrip + tentsBoardMargin),
          _maxCellSize,
        ].reduce(math.min);
        final geometry = TentsBoardGeometry(
          width: puzzle.width,
          height: puzzle.height,
          cellSize: cellSize,
        );
        _geometry = geometry;

        final board = Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: TentsBoardPainter(
                  geometry: geometry,
                  game: _game,
                  colors: colors,
                  changes: _changes,
                  change: _change,
                  drag: _drag,
                  hover: _hover,
                  solveWave: _solveWave,
                  wave: _wave,
                  focusedCell: _showFocus && !_game.isSolved ? _cursor : null,
                ),
              ),
            ),
            for (var x = 0; x < puzzle.width; x++)
              Positioned.fromRect(
                rect: geometry.columnNumberRect(x),
                child: _LineNumber(
                  count: puzzle.columnTents[x],
                  status: _game.check.columnStatuses[x],
                  label:
                      'Column ${x + 1}: ${_tents(puzzle.columnTents[x])}, '
                      '${columnPlaced[x]} placed',
                  cellSize: cellSize,
                ),
              ),
            for (var y = 0; y < puzzle.height; y++)
              Positioned.fromRect(
                rect: geometry.rowNumberRect(y),
                child: _LineNumber(
                  count: puzzle.rowTents[y],
                  status: _game.check.rowStatuses[y],
                  label:
                      'Row ${y + 1}: ${_tents(puzzle.rowTents[y])}, '
                      '${rowPlaced[y]} placed',
                  cellSize: cellSize,
                ),
              ),
            ..._cellSemantics(geometry),
          ],
        );

        return Center(
          child: SizedBox.fromSize(
            size: geometry.size,
            child: Semantics(
              container: true,
              label:
                  'Tents board, ${puzzle.width} columns by ${puzzle.height} '
                  'rows, ${puzzle.trees.length} trees, '
                  '${_game.marks.tents.length} tents placed',
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

  /// A node for each cell, so a screen reader can read the board cell by
  /// cell and change the free ones.
  List<Widget> _cellSemantics(TentsBoardGeometry geometry) {
    final puzzle = _game.puzzle;
    final touching = _game.check.touchingTents;
    final withoutTree = _game.check.tentsWithoutTree.toSet();
    final nodes = <Widget>[];
    for (var y = 0; y < puzzle.height; y++) {
      for (var x = 0; x < puzzle.width; x++) {
        final position = Position(x, y);
        final canChange = _isFree(position) && !_game.isSolved;
        final content = puzzle.hasTree(position)
            ? 'tree'
            : switch (_game.marks[position]) {
                TentsMark.tent => 'tent',
                TentsMark.grass => 'grass',
                null => 'empty',
              };
        nodes.add(
          Positioned.fromRect(
            rect: geometry.rectOf(position),
            child: Semantics(
              container: true,
              button: canChange,
              label: [
                'Row ${y + 1}, column ${x + 1}',
                content,
                if (touching.contains(position)) 'touches another tent',
                if (withoutTree.contains(position)) 'no tree beside it',
              ].join(', '),
              onTap: canChange ? () => _cycle(position) : null,
              child: const SizedBox.expand(),
            ),
          ),
        );
      }
    }
    return nodes;
  }
}

/// The tree's colors, a calm green and brown in each brightness that sit
/// beside the theme's teal.
const Color _lightCrown = Color(0xFF5C8B72);
const Color _darkCrown = Color(0xFF86B89C);
const Color _lightTrunk = Color(0xFF7A6250);
const Color _darkTrunk = Color(0xFFB09783);
const Color _lightGrass = Color(0x245C8B72);
const Color _darkGrass = Color(0x2E86B89C);

String _tents(int count) => count == 1 ? '1 tent' : '$count tents';

/// Whether a drag that has moved by [movement] runs along a row, keeping
/// the [current] answer until the other axis clearly leads, so a slanted
/// drag does not flicker between a row and a column.
bool _axis(Offset movement, bool? current) {
  final dx = movement.dx.abs();
  final dy = movement.dy.abs();
  final alongRow = dx >= dy;
  if (current == null || current == alongRow) {
    return alongRow;
  }
  final (along, across) = current ? (dx, dy) : (dy, dx);
  return across < along * 1.3 ? current : alongRow;
}

/// The cells from [from] to [to], which share a row or column, in order.
List<Position> _line(Position from, Position to) {
  final dx = (to.x - from.x).sign;
  final dy = (to.y - from.y).sign;
  final length = math.max((to.x - from.x).abs(), (to.y - from.y).abs());
  return [
    for (var step = 0; step <= length; step++)
      Position(from.x + dx * step, from.y + dy * step),
  ];
}

/// The number of tents a row or column needs, which fades once met and
/// turns red with a ring when there are too many.
class _LineNumber extends StatelessWidget {
  const _LineNumber({
    required this.count,
    required this.status,
    required this.label,
    required this.cellSize,
  });

  final int count;
  final LineStatus status;
  final String label;
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = switch (status) {
      LineStatus.under => scheme.onSurface,
      LineStatus.met => scheme.onSurfaceVariant.withValues(alpha: 0.4),
      LineStatus.over => scheme.error,
    };
    final diameter = cellSize * 0.62;
    final stateLabel = switch (status) {
      LineStatus.under => '',
      LineStatus.met => ', complete',
      LineStatus.over => ', too many',
    };

    return Semantics(
      container: true,
      label: '$label$stateLabel',
      child: ExcludeSemantics(
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: diameter,
            height: diameter,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: status == LineStatus.over
                    ? scheme.error
                    : scheme.error.withValues(alpha: 0),
                width: math.max(1.5, cellSize * 0.04),
              ),
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: theme.textTheme.titleMedium!.copyWith(
                color: color,
                fontSize: cellSize * 0.42,
                fontWeight: FontWeight.w600,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              child: Text('$count'),
            ),
          ),
        ),
      ),
    );
  }
}
