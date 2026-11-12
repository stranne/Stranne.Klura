import 'dart:collection';

import 'package:klura/core/grid.dart';
import 'package:meta/meta.dart';

/// What the player has put on a cell.
enum TentsMark {
  /// Grass: the player has decided that no tent goes here. It is only a
  /// note; the rules ignore it.
  grass,

  /// A tent.
  tent,
}

/// The player's tents and grass on a board.
///
/// Marks are a value. Changing them returns new marks, and two sets of marks
/// are equal when they mark the same cells the same way. They do not know
/// their puzzle; `checkTents` judges them against one.
@immutable
final class TentsMarks {
  /// Creates marks with [marks] on the given cells. Leave a cell out to
  /// leave it empty.
  TentsMarks(Map<Position, TentsMark> marks)
    : _marks = UnmodifiableMapView({
        for (final position in marks.keys.toList()..sort())
          position: marks[position]!,
      });

  /// Creates marks without tents or grass.
  const TentsMarks.empty() : _marks = const {};

  final Map<Position, TentsMark> _marks;

  /// The mark on each marked cell, in reading order.
  Map<Position, TentsMark> get marks => _marks;

  /// The cells with a tent, in reading order.
  Iterable<Position> get tents => _cellsWith(TentsMark.tent);

  /// The cells with grass, in reading order.
  Iterable<Position> get grass => _cellsWith(TentsMark.grass);

  bool get isEmpty => _marks.isEmpty;

  /// The mark on [position], or `null` if it is empty.
  TentsMark? operator [](Position position) => _marks[position];

  /// Returns a copy with [mark] on each of [positions], where `null` empties
  /// them.
  TentsMarks withMark(Iterable<Position> positions, TentsMark? mark) {
    final marks = Map.of(_marks);
    for (final position in positions) {
      if (mark == null) {
        marks.remove(position);
      } else {
        marks[position] = mark;
      }
    }
    return TentsMarks(marks);
  }

  Iterable<Position> _cellsWith(TentsMark mark) => [
    for (final MapEntry(key: position, value: cellMark) in _marks.entries)
      if (cellMark == mark) position,
  ];

  @override
  bool operator ==(Object other) {
    if (other is! TentsMarks || other._marks.length != _marks.length) {
      return false;
    }
    for (final MapEntry(key: position, value: mark) in _marks.entries) {
      if (other._marks[position] != mark) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
    for (final MapEntry(key: position, value: mark) in _marks.entries) ...[
      position,
      mark,
    ],
  ]);

  @override
  String toString() => 'TentsMarks($_marks)';
}
