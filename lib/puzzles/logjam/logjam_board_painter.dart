import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/logjam/logic/logjam_board.dart';
import 'package:klura/puzzles/logjam/logjam_board_geometry.dart';
import 'package:material_ui/material_ui.dart';

/// The colors of everything the board paints.
typedef LogjamColors = ({
  Color water,
  Color current,
  Color dot,
  Color boom,
  Color bark,
  Color barkLine,
  Color face,
  Color ring,
  Color highlight,
  Color shadow,
  Color liftShadow,
  Color marked,
  Color markedFace,
  Color markedRing,
  Color markedLine,
  Color chevron,
  Color lane,
  Color ripple,
  Color focus,
  Color problem,
  Color halo,
});

/// A log the player drags: its index and where along its line it shows,
/// between the lowest and highest offset it can reach.
typedef LogDrag = ({int piece, double offset});

/// A slide that something stopped: the log, the side it pushed toward, -1
/// for left or up and 1 for right or down, the log in its way or `null`
/// for the bank, and whether a key pushed it, which nudges it.
typedef LogBlock = ({int piece, int side, int? blocker, bool byKey});

/// The thickness of a log, in cells. The rest of its cell is water, so a
/// log reads as floating rather than as a block.
const double _thickness = 0.66;

/// The water between a log's end and the edge of its cell, in cells.
const double _endGap = 0.07;

/// How far the marked log drifts past the boom as it floats out, in cells.
const double _floatDistance = 2.6;

/// The share of the solve animation the marked log takes to float out.
const double _floatShare = 0.75;

/// Paints the river, the boom, the logs and every mark of play: the lane a
/// log can slide along, where a dragged log would settle, what stopped a
/// slide, the keyboard focus and the marked log floating out when the
/// puzzle is solved.
///
/// The river and its logs are seen from above. Logs lie in the water with
/// their bark and a cut end facing the light; the marked log is painted in
/// the theme's primary color and carries chevrons toward the exit.
class LogjamBoardPainter extends CustomPainter {
  LogjamBoardPainter({
    required this.geometry,
    required this.board,
    required this.colors,
    required this.glideFrom,
    required this.glide,
    required this.drag,
    required this.lane,
    required this.laneOpacity,
    required this.blocked,
    required this.blockedAnimation,
    required this.focusedPiece,
    required this.solve,
    required this.reduceMotion,
  }) : _exit = geometry.exitPoint(board.exitRow),
       super(
         repaint: Listenable.merge([
           glide,
           drag,
           laneOpacity,
           blockedAnimation,
           solve,
         ]),
       );

  final LogjamBoardGeometry geometry;
  final LogjamBoard board;
  final LogjamColors colors;

  /// Where each log that the last change moved glides from, as offsets
  /// along its line.
  final Map<int, double> glideFrom;

  /// The progress of the glide, from 0 to 1.
  final Animation<double> glide;

  final ValueListenable<LogDrag?> drag;

  /// The log whose lane shows, if any.
  final int? lane;

  /// How strongly the lane shows, from 0 to 1.
  final Animation<double> laneOpacity;

  final LogBlock? blocked;

  /// The progress of the marks of a stopped slide, which hold for a moment
  /// and then fade.
  final Animation<double> blockedAnimation;

  /// The log with the keyboard focus ring, if it shows.
  final int? focusedPiece;

  /// The progress of the solve, as the marked log floats out, from 0 to 1.
  final Animation<double> solve;

  /// Whether to leave out motion: the lift of a dragged log, the nudge of a
  /// stopped one and the float-out, which leaves the marked log in the gap.
  final bool reduceMotion;

  final Offset _exit;

  double get _cell => geometry.cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    _paintRiver(canvas, size);
    _paintBoom(canvas);
    _paintLane(canvas);
    _paintRipples(canvas);

    final dragged = drag.value?.piece;
    final floatsOut = board.isSolved && !reduceMotion;
    for (final (index, piece) in board.pieces.indexed) {
      if (index == dragged || (index == 0 && floatsOut)) {
        continue;
      }
      _paintLog(
        canvas,
        piece,
        geometry.pieceRect(piece, _offsetOf(index) + _nudgeOf(index)),
        marked: index == 0,
        scale: 1 + 0.06 * _pulseOf(piece),
      );
    }

    _paintBlocked(canvas);
    _paintFocus(canvas);
    _paintDrag(canvas);
    _paintFloater(canvas);
  }

  /// Where the log at [index] shows along its line: under the finger while
  /// dragged, on its way while it glides, otherwise where it lies.
  double _offsetOf(int index) {
    final drag = this.drag.value;
    if (drag != null && drag.piece == index) {
      return drag.offset;
    }
    final to = board.pieces[index].offset.toDouble();
    final from = glideFrom[index];
    if (from == null) {
      return to;
    }
    return lerpDouble(from, to, Curves.easeOutCubic.transform(glide.value))!;
  }

  /// How far a key pushes the log at [index] toward what stopped it, in
  /// cells, before it settles back.
  double _nudgeOf(int index) {
    final blocked = this.blocked;
    if (reduceMotion ||
        blocked == null ||
        !blocked.byKey ||
        blocked.piece != index) {
      return 0;
    }
    final time = blockedAnimation.value / 0.3;
    return time >= 1 ? 0 : blocked.side * 0.07 * math.sin(time * math.pi);
  }

  /// How far the wave from the exit lifts [piece] at this moment of the
  /// solve, from 0 to 1.
  double _pulseOf(LogjamPiece piece) {
    final time = solve.value;
    if (!board.isSolved || reduceMotion || time >= 1) {
      return 0;
    }
    final grid = geometry.gridRect;
    final reach = math.max(
      (grid.topLeft - _exit).distance,
      (grid.bottomLeft - _exit).distance,
    );
    final distance = (geometry.pieceRect(piece).center - _exit).distance;
    const span = 0.35;
    final start = 0.15 + distance / reach * (0.85 - span);
    final local = (time - start) / span;
    return local <= 0 || local >= 1 ? 0 : math.sin(local * math.pi);
  }

  /// The water, with faint dots where cells meet and small ripples of the
  /// current. Past the boom the river fades out.
  void _paintRiver(Canvas canvas, Size size) {
    final grid = geometry.gridRect;
    final corner = Radius.circular(_cell * 0.18);
    final riverEnd = geometry.boomX + _cell * 0.15;
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        grid.left,
        grid.top,
        riverEnd,
        grid.bottom,
        topLeft: corner,
        bottomLeft: corner,
      ),
      Paint()..color = colors.water,
    );
    final outflow = Rect.fromLTRB(riverEnd, grid.top, size.width, grid.bottom);
    canvas.drawRect(
      outflow,
      Paint()
        ..shader = LinearGradient(
          colors: [colors.water, colors.water.withValues(alpha: 0)],
        ).createShader(outflow),
    );

    final dot = Paint()..color = colors.dot;
    final dotRadius = math.max(1.2, _cell * 0.031);
    for (var x = 1; x < geometry.width; x++) {
      for (var y = 1; y < geometry.height; y++) {
        canvas.drawCircle(
          Offset(grid.left + x * _cell, grid.top + y * _cell),
          dotRadius,
          dot,
        );
      }
    }

    // One ripple in each cell, placed to look scattered but the same every
    // time, and two running out through the gap.
    final current = Path();
    for (var x = 0; x < geometry.width; x++) {
      for (var y = 0; y < geometry.height; y++) {
        _addRipple(
          current,
          Offset(
            grid.left + (x + 0.14 + (x * 7 + y * 3) % 5 * 0.1) * _cell,
            grid.top + (y + 0.22 + (x * 3 + y * 5) % 4 * 0.17) * _cell,
          ),
          humps: 2,
          width: _cell * 0.12,
        );
      }
    }
    final exitTop = grid.top + board.exitRow * _cell;
    _addRipple(
      current,
      Offset(geometry.boomX + _cell * 0.22, exitTop + _cell * 0.36),
      humps: 3,
      width: _cell * 0.148,
    );
    _addRipple(
      current,
      Offset(geometry.boomX + _cell * 0.09, exitTop + _cell * 0.64),
      humps: 2,
      width: _cell * 0.148,
    );
    canvas.drawPath(
      current,
      Paint()
        ..color = colors.current
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, _cell * 0.028)
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Adds a ripple of [humps] small waves, each [width] wide, from [start].
  void _addRipple(
    Path path,
    Offset start, {
    required int humps,
    required double width,
  }) {
    final height = _cell * 0.042;
    path.moveTo(start.dx, start.dy);
    for (var hump = 0; hump < humps; hump++) {
      final left = start.dx + hump * width;
      path.quadraticBezierTo(
        left + width / 2,
        start.dy + (hump.isEven ? -height : height),
        left + width,
        start.dy,
      );
    }
  }

  /// The boom along the right edge: a float beside each row but the exit
  /// row, joined by chain links, with a post at each side of the gap.
  void _paintBoom(Canvas canvas) {
    final grid = geometry.gridRect;
    final x = geometry.boomX;
    final exit = board.exitRow;
    final half = _cell * 0.1;
    final inset = _cell * 0.074;
    final fill = Paint()..color = colors.boom;
    for (var row = 0; row < geometry.height; row++) {
      if (row == exit) {
        continue;
      }
      final top = grid.top + row * _cell;
      canvas.drawRRect(
        RRect.fromLTRBR(
          x - half,
          top + inset,
          x + half,
          top + _cell - inset,
          Radius.circular(half),
        ),
        fill,
      );
    }

    final link = Paint()
      ..color = colors.boom
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, _cell * 0.03);
    for (var row = 1; row < geometry.height; row++) {
      if (row == exit || row - 1 == exit) {
        continue;
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, grid.top + row * _cell),
            width: _cell * 0.096,
            height: _cell * 0.2,
          ),
          Radius.circular(_cell * 0.048),
        ),
        link,
      );
    }

    final post = _cell * 0.085;
    if (exit > 0) {
      canvas.drawCircle(
        Offset(x, grid.top + exit * _cell - _cell * 0.02),
        post,
        fill,
      );
    }
    if (exit < geometry.height - 1) {
      canvas.drawCircle(
        Offset(x, grid.top + (exit + 1) * _cell + _cell * 0.02),
        post,
        fill,
      );
    }
  }

  /// A soft band over the cells the log with the lane can reach.
  void _paintLane(Canvas canvas) {
    final index = lane;
    final opacity = laneOpacity.value;
    if (index == null || opacity <= 0) {
      return;
    }
    final piece = board.pieces[index];
    final first = geometry.pieceRect(
      piece,
      board.lowestOffset(index).toDouble(),
    );
    final last = geometry.pieceRect(
      piece,
      board.highestOffset(index).toDouble(),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        first.expandToInclude(last).deflate(_cell * 0.056),
        Radius.circular(_cell * 0.3),
      ),
      Paint()..color = colors.lane.withValues(alpha: colors.lane.a * opacity),
    );
  }

  /// Rings spreading from the gap as the marked log floats out.
  void _paintRipples(Canvas canvas) {
    final time = solve.value;
    if (!board.isSolved || reduceMotion || time >= 1) {
      return;
    }
    for (var ripple = 0; ripple < 3; ripple++) {
      final local = (time - 0.05 - 0.15 * ripple) / 0.55;
      if (local <= 0 || local >= 1) {
        continue;
      }
      canvas.drawCircle(
        _exit,
        _cell * 0.42 * (0.3 + 3.1 * Curves.easeOut.transform(local)),
        Paint()
          ..color = colors.ripple.withValues(
            alpha: colors.ripple.a * 0.85 * (1 - local),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, _cell * 0.03),
      );
    }
  }

  /// Paints [piece] lying in [rect], [scale]d about its middle.
  ///
  /// A [lifted] log, under the finger, casts a softer, wider shadow.
  void _paintLog(
    Canvas canvas,
    LogjamPiece piece,
    Rect rect, {
    required bool marked,
    double scale = 1,
    double opacity = 1,
    bool lifted = false,
  }) {
    final halfLength =
        (piece.isHorizontal ? rect.width : rect.height) / 2 - _cell * _endGap;
    final halfThickness = _cell * _thickness / 2;
    final end = halfThickness * 0.4;

    canvas
      ..save()
      ..translate(rect.center.dx, rect.center.dy);
    // Drawn along a row; a log along a column is the same turned a quarter
    // clockwise, so its cut end faces up and its light falls from the left.
    if (!piece.isHorizontal) {
      canvas.rotate(math.pi / 2);
    }
    canvas.scale(scale);
    if (opacity < 1) {
      canvas.saveLayer(
        null,
        Paint()..color = Colors.black.withValues(alpha: opacity),
      );
    }

    // Shadows fall down the screen whichever way the log lies.
    Offset down(double distance) =>
        piece.isHorizontal ? Offset(0, distance) : Offset(distance, 0);
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(-halfLength, -halfThickness, halfLength, halfThickness),
      Radius.elliptical(end, halfThickness),
    );
    if (lifted) {
      canvas.drawRRect(
        body.shift(down(_cell * 0.074)),
        Paint()
          ..color = colors.liftShadow
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _cell * 0.074),
      );
    } else {
      canvas.drawRRect(
        body.shift(down(_cell * 0.046)),
        Paint()..color = colors.shadow,
      );
    }
    canvas.drawRRect(
      body,
      Paint()..color = marked ? colors.marked : colors.bark,
    );
    if (marked) {
      _paintChevrons(canvas, halfLength);
    } else {
      _paintBark(
        canvas,
        halfLength,
        halfThickness,
        end,
        piece.isHorizontal ? 1 : -1,
      );
    }

    final face = Rect.fromCenter(
      center: Offset(-halfLength + end, 0),
      width: 2 * end,
      height: 2 * halfThickness,
    );
    final ring = marked ? colors.markedRing : colors.ring;
    canvas
      ..drawOval(
        face,
        Paint()..color = marked ? colors.markedFace : colors.face,
      )
      ..drawOval(
        face,
        Paint()
          ..color = marked ? colors.markedLine : colors.barkLine
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.8, _cell * 0.019),
      )
      ..drawOval(
        Rect.fromCenter(
          center: face.center,
          width: face.width * 0.6,
          height: face.height * 0.6,
        ),
        Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.8, _cell * 0.02),
      )
      ..drawOval(
        Rect.fromCenter(
          center: face.center,
          width: face.width * 0.24,
          height: face.height * 0.24,
        ),
        Paint()..color = ring,
      );

    if (opacity < 1) {
      canvas.restore();
    }
    canvas.restore();
  }

  /// The grain of the bark and a streak of light along the side that faces
  /// up or left, which [side] gives as 1 or -1.
  void _paintBark(
    Canvas canvas,
    double halfLength,
    double halfThickness,
    double end,
    double side,
  ) {
    final across = halfThickness * side;
    final grain = Path()
      ..moveTo(-halfLength + 2.6 * end, -across * 0.3)
      ..cubicTo(
        -halfLength * 0.3,
        -across * 0.4,
        halfLength * 0.3,
        -across * 0.2,
        halfLength - 1.6 * end,
        -across * 0.32,
      )
      ..moveTo(-halfLength + 3.4 * end, across * 0.3)
      ..lineTo(halfLength * 0.12, across * 0.25)
      ..moveTo(halfLength * 0.3, across * 0.32)
      ..lineTo(halfLength - 1.8 * end, across * 0.26);
    canvas
      ..drawPath(
        grain,
        Paint()
          ..color = colors.barkLine.withValues(alpha: colors.barkLine.a * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, _cell * 0.026)
          ..strokeCap = StrokeCap.round,
      )
      ..drawLine(
        Offset(-halfLength + 2.4 * end, -across * 0.66),
        Offset(halfLength - 2 * end, -across * 0.66),
        Paint()
          ..color = colors.highlight
          ..strokeWidth = _cell * 0.044
          ..strokeCap = StrokeCap.round,
      );
  }

  /// Three chevrons pointing toward the exit, so the marked log differs by
  /// shape as well as color.
  void _paintChevrons(Canvas canvas, double halfLength) {
    final path = Path();
    for (var index = 0; index < 3; index++) {
      final x = -halfLength + 2 * halfLength * (0.43 + 0.14 * index);
      path
        ..moveTo(x - _cell * 0.074, -_cell * 0.13)
        ..lineTo(x + _cell * 0.056, 0)
        ..lineTo(x - _cell * 0.074, _cell * 0.13);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.chevron
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, _cell * 0.048)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// The outline of [piece] lying in [rect], grown by [grow] on every side
  /// into a pill.
  RRect _outline(LogjamPiece piece, Rect rect, {double grow = 0}) {
    final length =
        (piece.isHorizontal ? rect.width : rect.height) -
        2 * _cell * _endGap +
        2 * grow;
    final thickness = _cell * _thickness + 2 * grow;
    final end = grow == 0 ? thickness * 0.2 : thickness / 2;
    return piece.isHorizontal
        ? RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: rect.center,
              width: length,
              height: thickness,
            ),
            Radius.elliptical(end, thickness / 2),
          )
        : RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: rect.center,
              width: thickness,
              height: length,
            ),
            Radius.elliptical(thickness / 2, end),
          );
  }

  /// What stopped a slide: a stop bar where the log met it and hatching on
  /// the end of the log in its way, both in the error color, fading after
  /// a moment. The bar and hatching tell it apart without color too.
  void _paintBlocked(Canvas canvas) {
    final blocked = this.blocked;
    if (blocked == null) {
      return;
    }
    final strength =
        1 -
        const Interval(
          0.35,
          1,
          curve: Curves.easeIn,
        ).transform(blockedAnimation.value);
    if (strength <= 0) {
      return;
    }
    final index = blocked.piece;
    final piece = board.pieces[index];
    final edge = blocked.side > 0
        ? board.highestOffset(index) + piece.length
        : board.lowestOffset(index);
    final grid = geometry.gridRect;

    if (blocked.blocker case final blocker?) {
      final along = blocked.side > 0 ? edge : edge - 1;
      final cell = geometry.rectOf(
        piece.isHorizontal
            ? Position(along, piece.y)
            : Position(piece.x, along),
      );
      final other = board.pieces[blocker];
      final hatch = Path();
      final spacing = _cell * 0.1;
      for (var x = cell.left - _cell; x < cell.right; x += spacing) {
        hatch
          ..moveTo(x, cell.top)
          ..lineTo(x + _cell, cell.bottom);
      }
      canvas
        ..save()
        ..clipRect(cell)
        ..clipRRect(_outline(other, geometry.pieceRect(other)))
        ..drawRect(
          cell,
          Paint()..color = colors.problem.withValues(alpha: 0.14 * strength),
        )
        ..drawPath(
          hatch,
          Paint()
            ..color = colors.problem.withValues(alpha: 0.85 * strength)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, _cell * 0.03),
        )
        ..restore();
    }

    final middle = piece.isHorizontal
        ? grid.top + (piece.y + 0.5) * _cell
        : grid.left + (piece.x + 0.5) * _cell;
    final at =
        (piece.isHorizontal ? grid.left : grid.top) +
        (edge + blocked.side * 0.09) * _cell;
    final reach = _cell * 0.42;
    final (from, to) = piece.isHorizontal
        ? (Offset(at, middle - reach), Offset(at, middle + reach))
        : (Offset(middle - reach, at), Offset(middle + reach, at));
    canvas
      ..drawLine(
        from,
        to,
        Paint()
          ..color = colors.halo.withValues(alpha: strength)
          ..strokeWidth = _cell * 0.11
          ..strokeCap = StrokeCap.round,
      )
      ..drawLine(
        from,
        to,
        Paint()
          ..color = colors.problem.withValues(alpha: strength)
          ..strokeWidth = _cell * 0.055
          ..strokeCap = StrokeCap.round,
      );
  }

  /// A ring around the log with the keyboard focus, with an arrowhead at
  /// each end it can slide toward.
  void _paintFocus(Canvas canvas) {
    final index = focusedPiece;
    if (index == null || drag.value?.piece == index) {
      return;
    }
    final piece = board.pieces[index];
    final rect = geometry.pieceRect(
      piece,
      _offsetOf(index) + _nudgeOf(index),
    );
    final paint = Paint()..color = colors.focus;
    canvas.drawRRect(
      _outline(piece, rect, grow: _cell * 0.093),
      Paint()
        ..color = colors.focus
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, _cell * 0.048),
    );

    final halfLength =
        (piece.isHorizontal ? rect.width : rect.height) / 2 - _cell * _endGap;
    // From along and across the log to the board, as the log lies.
    Offset point(double along, double across) =>
        rect.center +
        (piece.isHorizontal ? Offset(along, across) : Offset(-across, along));
    for (final side in const [-1, 1]) {
      final canSlide = side < 0
          ? board.lowestOffset(index) < piece.offset
          : board.highestOffset(index) > piece.offset;
      if (!canSlide) {
        continue;
      }
      final base = side * (halfLength + _cell * 0.22);
      canvas.drawPath(
        Path()..addPolygon([
          point(base - side * _cell * 0.056, -_cell * 0.12),
          point(base + side * _cell * 0.083, 0),
          point(base - side * _cell * 0.056, _cell * 0.12),
        ], true),
        paint,
      );
    }
  }

  /// The dragged log under the finger, lifted a little, over a dashed
  /// outline where it would settle.
  void _paintDrag(Canvas canvas) {
    final drag = this.drag.value;
    if (drag == null) {
      return;
    }
    final piece = board.pieces[drag.piece];
    final target = _outline(
      piece,
      geometry.pieceRect(piece, drag.offset.roundToDouble()),
    );
    canvas
      ..drawRRect(
        target,
        Paint()..color = colors.focus.withValues(alpha: 0.1),
      )
      ..drawPath(
        _dashed(Path()..addRRect(target)),
        Paint()
          ..color = colors.focus
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.4, _cell * 0.037),
      );
    _paintLog(
      canvas,
      piece,
      geometry.pieceRect(piece, drag.offset),
      marked: drag.piece == 0,
      scale: reduceMotion ? 1 : 1.04,
      lifted: !reduceMotion,
    );
  }

  /// [source] as dashes.
  Path _dashed(Path source) {
    final dash = _cell * 0.093;
    final gap = _cell * 0.074;
    final dashes = Path();
    for (final metric in source.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += dash + gap) {
        dashes.addPath(
          metric.extractPath(start, math.min(start + dash, metric.length)),
          Offset.zero,
        );
      }
    }
    return dashes;
  }

  /// The marked log drifting out through the gap and fading, once it has
  /// reached the exit.
  void _paintFloater(Canvas canvas) {
    final time = solve.value;
    if (!board.isSolved || reduceMotion || time >= 1) {
      return;
    }
    final drift = Curves.easeIn.transform(
      math.min(1, time / _floatShare).toDouble(),
    );
    if (drift >= 1) {
      return;
    }
    final piece = board.marked;
    _paintLog(
      canvas,
      piece,
      geometry.pieceRect(piece, _offsetOf(0) + _floatDistance * drift),
      marked: true,
      opacity: 1 - drift,
    );
  }

  @override
  bool shouldRepaint(LogjamBoardPainter oldDelegate) =>
      oldDelegate.geometry.cellSize != geometry.cellSize ||
      oldDelegate.board != board ||
      oldDelegate.colors != colors ||
      oldDelegate.glideFrom != glideFrom ||
      oldDelegate.lane != lane ||
      oldDelegate.blocked != blocked ||
      oldDelegate.focusedPiece != focusedPiece ||
      oldDelegate.reduceMotion != reduceMotion;
}
