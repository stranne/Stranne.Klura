import 'package:meta/meta.dart';

/// What a fisher is, or what the player has marked them as.
enum TallTalesMark {
  /// Always tells the truth, so their statement is true.
  truth,

  /// Always tells tall tales, so their statement is false.
  tallTales,
}

/// A mark, or none, for each fisher on the jetty, in the order they sit.
///
/// Marks are a value. Changing them returns new marks, and two sets of marks
/// are equal when they mark the same fishers the same way. They do not know
/// their puzzle; `checkTallTales` judges them against one.
@immutable
final class TallTalesMarks {
  /// Creates marks with `marks[i]` on the fisher at place i, where `null`
  /// leaves the fisher unmarked.
  TallTalesMarks(List<TallTalesMark?> marks)
    : _marks = List.unmodifiable(marks);

  /// Creates marks for [fisherCount] fishers, none of them marked.
  TallTalesMarks.empty(int fisherCount)
    : _marks = List.unmodifiable(
        List<TallTalesMark?>.filled(fisherCount, null),
      );

  /// Creates marks for every one of [fisherCount] fishers, those in the bit
  /// set [truthful] marked as telling the truth and the rest as telling tall
  /// tales.
  TallTalesMarks.fromTruthful(int fisherCount, int truthful)
    : _marks = List.unmodifiable([
        for (var fisher = 0; fisher < fisherCount; fisher++)
          if ((truthful >> fisher) & 1 == 1)
            TallTalesMark.truth
          else
            TallTalesMark.tallTales,
      ]);

  final List<TallTalesMark?> _marks;

  /// The mark on each fisher, in the order they sit.
  List<TallTalesMark?> get marks => _marks;

  /// The number of fishers.
  int get length => _marks.length;

  /// Whether no fisher is marked.
  bool get isEmpty => _marks.every((mark) => mark == null);

  /// Whether every fisher is marked.
  bool get isComplete => _marks.every((mark) => mark != null);

  /// The fishers marked as telling the truth, as a bit set.
  int get truthful => _bitsWhere((mark) => mark == TallTalesMark.truth);

  /// The marked fishers, as a bit set.
  int get marked => _bitsWhere((mark) => mark != null);

  /// The mark on [fisher], or `null` if they are unmarked.
  TallTalesMark? operator [](int fisher) => _marks[fisher];

  /// Returns a copy with [mark] on [fisher], where `null` clears the mark.
  TallTalesMarks withMark(int fisher, TallTalesMark? mark) =>
      TallTalesMarks([..._marks]..[fisher] = mark);

  int _bitsWhere(bool Function(TallTalesMark? mark) test) {
    var bits = 0;
    for (var fisher = 0; fisher < _marks.length; fisher++) {
      if (test(_marks[fisher])) {
        bits |= 1 << fisher;
      }
    }
    return bits;
  }

  @override
  bool operator ==(Object other) {
    if (other is! TallTalesMarks || other._marks.length != _marks.length) {
      return false;
    }
    for (var fisher = 0; fisher < _marks.length; fisher++) {
      if (other._marks[fisher] != _marks[fisher]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_marks);

  @override
  String toString() => 'TallTalesMarks($_marks)';
}
