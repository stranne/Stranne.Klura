import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/bridges/bridges_board_geometry.dart';
import 'package:klura/puzzles/bridges/logic/bridges_game.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';

/// A drag from `island`, aimed in `direction` once it has moved far enough.
typedef BoardDrag = ({Position island, Direction? direction});

/// What the mouse is over: an `island` or a `connection`.
typedef BoardHover = ({Position? island, Connection? connection});

/// A change in the bridges on one connection, drawn growing from the island
/// at `growFrom`, or from the middle if it is `null`.
typedef BridgeChange = ({int from, int to, Position? growFrom});

/// A first bridge on `attempt` that was not placed because it would cross
/// the `blockers`.
typedef BlockedMove = ({Connection attempt, List<Connection> blockers});

/// The colors of everything the board paints, taken from the theme.
typedef BoardColors = ({
  Color dot,
  Color bridge,
  Color solvedBridge,
  Color preview,
  Color problem,
  Color problemHalo,
  Color guide,
});

/// The light that spreads along the bridges from the move that solved the
/// puzzle.
final class SolveWave {
  SolveWave._(this._distances)
    : _maxDistance = _distances.values.fold(0, math.max);

  /// Starts the wave at both ends of [last], the connection whose bridges
  /// solved [game], and measures how many bridges away every island is.
  factory SolveWave.from(BridgesGame game, Connection last) {
    final neighbors = <Position, List<Position>>{};
    for (final connection in game.arrangement.connections) {
      neighbors.putIfAbsent(connection.start, () => []).add(connection.end);
      neighbors.putIfAbsent(connection.end, () => []).add(connection.start);
    }
    final distances = {last.start: 0, last.end: 0};
    final queue = [last.start, last.end];
    for (var index = 0; index < queue.length; index++) {
      final island = queue[index];
      for (final neighbor in neighbors[island] ?? const <Position>[]) {
        if (!distances.containsKey(neighbor)) {
          distances[neighbor] = distances[island]! + 1;
          queue.add(neighbor);
        }
      }
    }
    return SolveWave._(distances);
  }

  /// The share of the animation the wave takes to reach the farthest island.
  static const double _spread = 0.6;

  final Map<Position, int> _distances;
  final int _maxDistance;

  /// When the wave reaches [island], as a share of the animation.
  double reachOf(Position island) => _maxDistance == 0
      ? 0
      : (_distances[island] ?? _maxDistance) / _maxDistance * _spread;

  /// How much [island] is lifted at [time], rising and falling once after the
  /// wave reaches it.
  double pulseAt(Position island, double time) {
    final local = (time - reachOf(island)) / (1 - _spread);
    return local <= 0 || local >= 1 ? 0 : math.sin(local * math.pi);
  }

  /// How far the bridges on [connection] have lit up at [time], from 0 to 1.
  double lightAt(Connection connection, double time) {
    final reach = math.min(reachOf(connection.start), reachOf(connection.end));
    return ((time - reach) / 0.15).clamp(0, 1);
  }
}

/// Paints everything on the board except the islands: grid dots, bridges,
/// marks for loops and blocked moves, and the preview of the next move.
class BridgesBoardPainter extends CustomPainter {
  BridgesBoardPainter({
    required this.geometry,
    required this.game,
    required this.colors,
    required this.changes,
    required this.change,
    required this.drag,
    required this.hover,
    required this.blocked,
    required this.blockedAnimation,
    required this.solveWave,
    required this.wave,
    required this.focusedIsland,
    required this.reduceMotion,
  }) : super(
         repaint: Listenable.merge([
           change,
           drag,
           hover,
           blockedAnimation,
           wave,
         ]),
       );

  final BridgesBoardGeometry geometry;
  final BridgesGame game;
  final BoardColors colors;

  /// The bridges that changed in the last move, animated by [change].
  final Map<Connection, BridgeChange> changes;
  final Animation<double> change;

  final ValueListenable<BoardDrag?> drag;
  final ValueListenable<BoardHover?> hover;

  /// The last move that was blocked, marked while [blockedAnimation] runs.
  final BlockedMove? blocked;
  final Animation<double> blockedAnimation;

  final SolveWave? solveWave;
  final Animation<double> wave;

  /// The island with keyboard focus, whose possible bridges are shown.
  final Position? focusedIsland;
  final bool reduceMotion;

  double get _cell => geometry.cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    final preview = _preview();
    _paintDots(canvas);
    _paintGuides(canvas);
    _paintLoops(canvas);
    _paintBridges(canvas, preview);
    if (preview != null) {
      _paintPreview(canvas, preview);
    }
    _paintBlocked(canvas);
  }

  /// The move a finished drag or a click would make, if any.
  _Preview? _preview() {
    if (drag.value case (island: final island, direction: final direction?)) {
      final neighbor = game.puzzle.neighbor(island, direction);
      return neighbor == null
          ? null
          : _previewOf(Connection(island, neighbor.position), strong: true);
    }
    if (hover.value?.connection case final connection?) {
      return _previewOf(connection, strong: false);
    }
    return null;
  }

  _Preview _previewOf(Connection connection, {required bool strong}) => (
    connection: connection,
    next: game.nextBridgeCount(connection),
    blockers: game.blockersOf(connection),
    strong: strong,
  );

  void _paintDots(Canvas canvas) {
    final covered = {
      for (final connection in game.arrangement.connections)
        ...connection.cellsBetween,
    };
    final paint = Paint()..color = colors.dot;
    final radius = math.max(1.2, _cell * 0.04);
    for (var y = 0; y < game.puzzle.height; y++) {
      for (var x = 0; x < game.puzzle.width; x++) {
        final cell = Position(x, y);
        if (game.puzzle.islandAt(cell) == null && !covered.contains(cell)) {
          canvas.drawCircle(geometry.centerOf(cell), radius, paint);
        }
      }
    }
  }

  /// Faint dashes from an island to each neighbor it can still bridge to,
  /// while the island is pressed, hovered or has keyboard focus.
  void _paintGuides(Canvas canvas) {
    final drag = this.drag.value;
    final island = drag == null
        ? hover.value?.island ?? focusedIsland
        : (drag.direction == null ? drag.island : null);
    if (island == null || game.isSolved) {
      return;
    }

    final paint = Paint()
      ..color = colors.guide.withValues(alpha: 0.6)
      ..strokeWidth = math.max(1, geometry.bridgeWidth * 0.5)
      ..strokeCap = StrokeCap.round;
    for (final direction in Direction.values) {
      final neighbor = game.puzzle.neighbor(island, direction);
      if (neighbor == null) {
        continue;
      }
      final connection = Connection(island, neighbor.position);
      if (game.arrangement[connection] == 0 &&
          game.blockersOf(connection).isEmpty) {
        _dashed(canvas, connection, paint);
      }
    }
  }

  void _paintLoops(Canvas canvas) {
    final paint = Paint()
      ..color = colors.problemHalo
      ..strokeWidth = _cell * 0.44
      ..strokeCap = StrokeCap.round;
    for (final connection in game.check.loopConnections) {
      final (start, end) = geometry.bridgeEnds(connection);
      canvas.drawLine(start, end, paint);
    }
  }

  void _paintBridges(Canvas canvas, _Preview? preview) {
    final loops = game.check.loopConnections.toSet();
    final blockers = {
      if (preview != null && preview.strong) ...preview.blockers,
    };
    final changing = change.value < 1;

    for (final connection in game.puzzle.connections) {
      final count = game.arrangement[connection];
      final transition = changing ? changes[connection] : null;
      if (count == 0 && transition == null) {
        continue;
      }

      var color = _bridgeColor(connection);
      var shift = 0.0;
      if (loops.contains(connection) || blockers.contains(connection)) {
        color = colors.problem;
      } else if (_blockedFade(connection) case final fade when fade > 0) {
        color = Color.lerp(color, colors.problem, fade)!;
        shift = _shake();
      }

      var alpha = 1.0;
      if (preview?.connection == connection) {
        if (preview!.next > 0 && preview.blockers.isEmpty && preview.strong) {
          // The preview draws this connection's bridges instead.
          continue;
        }
        if (preview.next == 0) {
          alpha = preview.strong ? 0.3 : 0.6;
        }
      }

      if (transition == null) {
        _bridge(
          canvas,
          connection,
          count,
          color.withValues(alpha: alpha),
          shift: shift,
        );
      } else {
        _transition(canvas, connection, transition, color, alpha);
      }
    }
  }

  Color _bridgeColor(Connection connection) {
    final solveWave = this.solveWave;
    if (solveWave != null && wave.value < 1) {
      return Color.lerp(
        colors.bridge,
        colors.solvedBridge,
        solveWave.lightAt(connection, wave.value),
      )!;
    }
    return game.isSolved ? colors.solvedBridge : colors.bridge;
  }

  /// How strongly [connection] still shows that it blocked the last move.
  double _blockedFade(Connection connection) {
    final blocked = this.blocked;
    if (blocked == null || !blocked.blockers.contains(connection)) {
      return 0;
    }
    return 1 - Curves.easeIn.transform(blockedAnimation.value);
  }

  /// The sideways offset of a blocking bridge as it shakes.
  double _shake() {
    if (reduceMotion) {
      return 0;
    }
    final time = blockedAnimation.value;
    return _cell * 0.08 * math.sin(time * math.pi * 6) * (1 - time);
  }

  void _transition(
    Canvas canvas,
    Connection connection,
    BridgeChange transition,
    Color color,
    double alpha,
  ) {
    final time = Curves.easeOutCubic.transform(change.value);
    final gap = geometry.doubleBridgeGap;
    final paint = color.withValues(alpha: alpha);
    switch (transition) {
      case (from: 0, to: final to, growFrom: final growFrom):
        _bridge(canvas, connection, to, paint, length: time, from: growFrom);
      case (from: final from, to: 0, growFrom: _):
        _bridge(
          canvas,
          connection,
          from,
          color.withValues(alpha: alpha * (1 - time)),
        );
      case (from: 1, to: 2, growFrom: _):
        _bridge(canvas, connection, 2, paint, gap: gap * time);
      case (from: _, to: _, growFrom: _):
        _bridge(canvas, connection, 2, paint, gap: gap * (1 - time));
    }
  }

  void _paintPreview(Canvas canvas, _Preview preview) {
    final connection = preview.connection;
    if (preview.blockers.isNotEmpty) {
      final paint = Paint()
        ..color = colors.problem.withValues(alpha: preview.strong ? 0.9 : 0.5)
        ..strokeWidth = geometry.bridgeWidth
        ..strokeCap = StrokeCap.round;
      _dashed(canvas, connection, paint);
    } else if (preview.next > 0) {
      final alpha = preview.strong ? 0.55 : 0.3;
      _bridge(
        canvas,
        connection,
        preview.next,
        colors.preview.withValues(alpha: alpha),
      );
    }
  }

  void _paintBlocked(Canvas canvas) {
    final blocked = this.blocked;
    if (blocked == null || blockedAnimation.value >= 1) {
      return;
    }
    final paint = Paint()
      ..color = colors.problem.withValues(
        alpha: 0.9 * (1 - blockedAnimation.value),
      )
      ..strokeWidth = geometry.bridgeWidth
      ..strokeCap = StrokeCap.round;
    _dashed(canvas, blocked.attempt, paint);
  }

  /// Draws [count] bridges on [connection] in [color], [gap] apart when
  /// there are two.
  ///
  /// A [length] below 1 draws only that share of the bridges, growing from
  /// the island at [from], or from the middle if [from] is `null`. A [shift]
  /// moves them sideways.
  void _bridge(
    Canvas canvas,
    Connection connection,
    int count,
    Color color, {
    double? gap,
    double length = 1,
    Position? from,
    double shift = 0,
  }) {
    if (count == 0 || length <= 0) {
      return;
    }
    var (start, end) = geometry.bridgeLineEnds(connection);
    if (from == connection.end) {
      (start, end) = (end, start);
    }
    if (length < 1) {
      if (from == null) {
        final middle = (start + end) / 2;
        final half = (end - start) * (length / 2);
        (start, end) = (middle - half, middle + half);
      } else {
        end = start + (end - start) * length;
      }
    }

    final along = end - start;
    final normal = along.distance == 0
        ? Offset.zero
        : Offset(-along.dy, along.dx) / along.distance;
    final spacing = gap ?? geometry.doubleBridgeGap;
    final offsets = count == 1 ? [0.0] : [-spacing / 2, spacing / 2];
    final paint = Paint()
      ..color = color
      ..strokeWidth = geometry.bridgeWidth
      ..strokeCap = StrokeCap.round;
    for (final offset in offsets) {
      final sideways = normal * (offset + shift);
      canvas.drawLine(start + sideways, end + sideways, paint);
    }
  }

  void _dashed(Canvas canvas, Connection connection, Paint paint) {
    final (start, end) = geometry.bridgeEnds(connection);
    final along = end - start;
    final length = along.distance;
    final dash = _cell * 0.14;
    final space = _cell * 0.1;
    for (var at = 0.0; at < length; at += dash + space) {
      final dashEnd = math.min(at + dash, length);
      canvas.drawLine(
        start + along * (at / length),
        start + along * (dashEnd / length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(BridgesBoardPainter oldDelegate) =>
      oldDelegate.geometry.cellSize != geometry.cellSize ||
      oldDelegate.game != game ||
      oldDelegate.colors != colors ||
      oldDelegate.changes != changes ||
      oldDelegate.blocked != blocked ||
      oldDelegate.solveWave != solveWave ||
      oldDelegate.focusedIsland != focusedIsland ||
      oldDelegate.reduceMotion != reduceMotion;
}

typedef _Preview = ({
  Connection connection,
  int next,
  List<Connection> blockers,
  bool strong,
});
