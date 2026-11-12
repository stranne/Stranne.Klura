import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/tents/logic/tents_game.dart';
import 'package:klura/puzzles/tents/logic/tents_marks.dart';
import 'package:klura/puzzles/tents/tents_board_geometry.dart';
import 'package:material_ui/material_ui.dart';

/// The colors of everything the board paints.
typedef TentsColors = ({
  Color board,
  Color line,
  Color grass,
  Color tuft,
  Color crown,
  Color trunk,
  Color tent,
  Color door,
  Color problem,
  Color problemHalo,
  Color focus,
});

/// How a cell's mark changed in the last move, for its animation.
typedef MarkChange = ({TentsMark? from, TentsMark? to});

/// A drag along a row or column in progress: the cells it would change and
/// whether it clears their grass rather than adding it.
typedef GrassDrag = ({List<Position> cells, bool clearing});

/// The wave that lifts the trees and tents once when a move solves the
/// puzzle, spreading from [origin], the cell of that move.
final class SolveWave {
  SolveWave(this.origin, int width, int height)
    : _reach = math.max(
        1,
        [
          for (final (x, y) in [
            (0, 0),
            (width - 1, 0),
            (0, height - 1),
            (width - 1, height - 1),
          ])
            _distance(origin, Position(x, y)),
        ].reduce(math.max),
      );

  final Position origin;

  /// The distance from [origin] to the farthest corner.
  final double _reach;

  /// How far the wave lifts [cell] at [time], from 0 to 1: nothing before
  /// the wave arrives and after it has passed.
  double pulseAt(Position cell, double time) {
    const span = 0.4;
    final start = _distance(origin, cell) / _reach * (1 - span);
    final local = (time - start) / span;
    return local <= 0 || local >= 1 ? 0 : math.sin(local * math.pi);
  }

  static double _distance(Position from, Position to) {
    final dx = (to.x - from.x).toDouble();
    final dy = (to.y - from.y).toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }
}

/// Paints the grid, the trees, the player's tents and grass, the marks for
/// broken rules, previews and the wave of a solve. The row and column
/// numbers are widgets of their own.
class TentsBoardPainter extends CustomPainter {
  TentsBoardPainter({
    required this.geometry,
    required this.game,
    required this.colors,
    required this.changes,
    required this.change,
    required this.drag,
    required this.hover,
    required this.solveWave,
    required this.wave,
    required this.focusedCell,
  }) : super(repaint: Listenable.merge([change, drag, hover, wave]));

  final TentsBoardGeometry geometry;
  final TentsGame game;
  final TentsColors colors;

  /// The cells the last move changed.
  final Map<Position, MarkChange> changes;

  /// The progress of the last move's animation, from 0 to 1.
  final Animation<double> change;

  final ValueListenable<GrassDrag?> drag;

  /// The free cell under the mouse, whose next mark shows faintly.
  final ValueListenable<Position?> hover;

  final SolveWave? solveWave;
  final Animation<double> wave;

  /// The cell with the keyboard focus ring, if it shows.
  final Position? focusedCell;

  double get _cell => geometry.cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas);

    final drag = this.drag.value;
    final dragged = <Position>{...?drag?.cells};
    final clearing = drag?.clearing ?? false;
    final progress = Curves.easeOut.transform(change.value);

    for (final position in game.marks.grass) {
      final appearing = changes[position]?.to == TentsMark.grass;
      final faded = clearing && dragged.contains(position);
      _paintGrass(
        canvas,
        position,
        (appearing ? progress : 1) * (faded ? 0.35 : 1),
      );
    }
    for (final MapEntry(key: position, value: markChange) in changes.entries) {
      if (markChange.from == TentsMark.grass &&
          markChange.to != TentsMark.grass) {
        _paintGrass(canvas, position, 1 - progress);
      }
    }
    if (!clearing) {
      for (final position in dragged) {
        _paintGrass(canvas, position, 0.5);
      }
    }

    _paintProblems(canvas);

    for (final tree in game.puzzle.trees) {
      _paintTree(canvas, tree, 1 + 0.14 * _pulse(tree));
    }

    final problemTents = {
      ...game.check.touchingTents,
      ...game.check.tentsWithoutTree,
    };
    for (final position in game.marks.tents) {
      final appearing = changes[position]?.to == TentsMark.tent;
      final scale = appearing ? 0.6 + 0.4 * progress : 1.0;
      _paintTent(
        canvas,
        position,
        problemTents.contains(position) ? colors.problem : colors.tent,
        alpha: appearing ? progress : 1,
        scale: scale * (1 + 0.16 * _pulse(position)),
      );
    }
    for (final MapEntry(key: position, value: markChange) in changes.entries) {
      if (markChange.from == TentsMark.tent &&
          markChange.to != TentsMark.tent) {
        _paintTent(
          canvas,
          position,
          colors.tent,
          alpha: 1 - progress,
          scale: 1 - 0.2 * progress,
        );
      }
    }

    _paintHover(canvas);
    if (focusedCell case final cell?) {
      _paintFocus(canvas, cell);
    }
  }

  double _pulse(Position position) =>
      solveWave?.pulseAt(position, wave.value) ?? 0;

  void _paintGrid(Canvas canvas) {
    final grid = geometry.gridRect;
    final corner = Radius.circular(_cell * 0.16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(grid, corner),
      Paint()..color = colors.board,
    );

    final line = Paint()
      ..color = colors.line
      ..strokeWidth = 1;
    for (var x = 1; x < geometry.width; x++) {
      final dx = grid.left + x * _cell;
      canvas.drawLine(Offset(dx, grid.top), Offset(dx, grid.bottom), line);
    }
    for (var y = 1; y < geometry.height; y++) {
      final dy = grid.top + y * _cell;
      canvas.drawLine(Offset(grid.left, dy), Offset(grid.right, dy), line);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(grid.deflate(0.5), corner),
      Paint()
        ..color = colors.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  /// Soft bands join tents that touch, and a soft ring marks a tent with no
  /// tree beside it, under the tents themselves.
  void _paintProblems(Canvas canvas) {
    final halo = Paint()
      ..color = colors.problemHalo
      ..strokeWidth = _cell * 0.86
      ..strokeCap = StrokeCap.round;
    for (final (first, second) in game.check.touching) {
      canvas.drawLine(
        geometry.centerOf(first),
        geometry.centerOf(second),
        halo,
      );
    }
    for (final tent in game.check.tentsWithoutTree) {
      canvas.drawCircle(
        geometry.centerOf(tent),
        _cell * 0.43,
        Paint()..color = colors.problemHalo,
      );
    }
  }

  void _paintGrass(Canvas canvas, Position position, double alpha) {
    if (alpha <= 0) {
      return;
    }
    final rect = geometry.rectOf(position);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(_cell * 0.06),
        Radius.circular(_cell * 0.1),
      ),
      Paint()..color = colors.grass.withValues(alpha: colors.grass.a * alpha),
    );

    final center = rect.center;
    final base = rect.top + _cell * 0.66;
    final blade = Paint()
      ..color = colors.tuft.withValues(alpha: colors.tuft.a * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, _cell * 0.045)
      ..strokeCap = StrokeCap.round;
    final spread = _cell * 0.13;
    final path = Path()
      ..moveTo(center.dx - spread, base)
      ..quadraticBezierTo(
        center.dx - spread + _cell * 0.02,
        base - _cell * 0.12,
        center.dx - spread - _cell * 0.03,
        base - _cell * 0.2,
      )
      ..moveTo(center.dx, base)
      ..lineTo(center.dx, base - _cell * 0.26)
      ..moveTo(center.dx + spread, base)
      ..quadraticBezierTo(
        center.dx + spread - _cell * 0.02,
        base - _cell * 0.12,
        center.dx + spread + _cell * 0.03,
        base - _cell * 0.2,
      );
    canvas.drawPath(path, blade);
  }

  void _paintTree(Canvas canvas, Position position, double scale) {
    final center = geometry.centerOf(position);
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(scale);
    final trunkWidth = _cell * 0.09;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            -trunkWidth / 2,
            _cell * 0.02,
            trunkWidth / 2,
            _cell * 0.32,
          ),
          Radius.circular(trunkWidth / 2),
        ),
        Paint()..color = colors.trunk,
      )
      ..drawCircle(
        Offset(0, -_cell * 0.07),
        _cell * 0.27,
        Paint()..color = colors.crown,
      )
      ..drawCircle(
        Offset(-_cell * 0.08, -_cell * 0.15),
        _cell * 0.09,
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      )
      ..restore();
  }

  void _paintTent(
    Canvas canvas,
    Position position,
    Color color, {
    required double alpha,
    required double scale,
  }) {
    if (alpha <= 0) {
      return;
    }
    final center = geometry.centerOf(position);
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(scale);
    final ground = _cell * 0.26;
    final body = Path()
      ..moveTo(-_cell * 0.31, ground)
      ..lineTo(0, -_cell * 0.27)
      ..lineTo(_cell * 0.31, ground)
      ..close();
    final fill = color.withValues(alpha: color.a * alpha);
    canvas
      ..drawPath(body, Paint()..color = fill)
      // A stroke of the same color rounds the corners a little.
      ..drawPath(
        body,
        Paint()
          ..color = fill
          ..style = PaintingStyle.stroke
          ..strokeWidth = _cell * 0.05
          ..strokeJoin = StrokeJoin.round,
      );
    final door = Path()
      ..moveTo(-_cell * 0.09, ground)
      ..lineTo(0, -_cell * 0.02)
      ..lineTo(_cell * 0.09, ground)
      ..close();
    canvas
      ..drawPath(
        door,
        Paint()..color = colors.door.withValues(alpha: colors.door.a * alpha),
      )
      ..restore();
  }

  /// Shows the mark a click would leave on the cell under the mouse.
  void _paintHover(Canvas canvas) {
    final position = hover.value;
    if (position == null || drag.value != null) {
      return;
    }
    switch (game.marks[position]) {
      case null:
        _paintGrass(canvas, position, 0.45);
      case TentsMark.grass:
        _paintTent(canvas, position, colors.tent, alpha: 0.35, scale: 1);
      case TentsMark.tent:
        // The next click clears the tent, so a veil of the board's color
        // fades it.
        canvas.drawRect(
          geometry.rectOf(position).deflate(_cell * 0.06),
          Paint()..color = colors.board.withValues(alpha: 0.5),
        );
    }
  }

  void _paintFocus(Canvas canvas, Position position) {
    final width = math.max(2, _cell * 0.06).toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        geometry.rectOf(position).deflate(width / 2 + 1),
        Radius.circular(_cell * 0.12),
      ),
      Paint()
        ..color = colors.focus
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(TentsBoardPainter oldDelegate) =>
      oldDelegate.geometry.cellSize != geometry.cellSize ||
      oldDelegate.game != game ||
      oldDelegate.colors != colors ||
      oldDelegate.changes != changes ||
      oldDelegate.solveWave != solveWave ||
      oldDelegate.focusedCell != focusedCell;
}
