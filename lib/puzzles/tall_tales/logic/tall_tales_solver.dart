import 'package:klura/puzzles/tall_tales/logic/tall_tales_marks.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_puzzle.dart';

/// Finds up to [limit] markings of every fisher that fit [puzzle], in the
/// order of their bit sets of truth-tellers.
///
/// It tries every marking, at most 2^8 = 256 of them, so it knows nothing
/// of how the puzzle was made. A [limit] of 2, the default, is enough to
/// tell whether a puzzle has exactly one solution.
List<TallTalesMarks> solveTallTales(TallTalesPuzzle puzzle, {int limit = 2}) {
  if (limit < 1) {
    throw RangeError.range(limit, 1, null, 'limit');
  }
  final fishers = puzzle.fisherCount;
  final solutions = <TallTalesMarks>[];
  for (var truthful = 0; truthful < 1 << fishers; truthful++) {
    if (puzzle.fits(truthful)) {
      solutions.add(TallTalesMarks.fromTruthful(fishers, truthful));
      if (solutions.length == limit) {
        break;
      }
    }
  }
  return solutions;
}

/// How much reasoning a puzzle needs, from no marks, to solve without
/// trial and error.
///
/// Each level includes the ones before it.
enum TallTalesReasoning {
  /// One statement at a time settles every fisher: a statement decides a
  /// fisher once the others it depends on are known, or on its own, as
  /// `Bo and I are not alike` makes Bo a teller of tall tales.
  basic,

  /// Also needs links between fishers: a statement can show that two
  /// fishers are alike, as `Alva: Bo tells the truth` does, or not alike,
  /// and the link then carries over to other statements.
  advanced,

  /// Also needs lookahead: supposing one fisher's kind, following basic
  /// and advanced reasoning and finding that a statement breaks.
  lookahead,

  /// Needs deeper trial and error, or the puzzle has no single solution.
  search,
}

/// How hard a puzzle is for a person, as measured by [gradeTallTales].
final class TallTalesGrade {
  const TallTalesGrade._({
    required this.reasoning,
    required this.suppositions,
    required this.openAfterBasic,
  });

  /// The least reasoning that solves the puzzle.
  final TallTalesReasoning reasoning;

  /// How many times lookahead had to suppose a fisher's kind, 0 for a
  /// puzzle that needs no lookahead.
  final int suppositions;

  /// How many fishers basic reasoning leaves undecided from no marks: the
  /// fishers a player has to think about rather than read off.
  final int openAfterBasic;

  @override
  String toString() =>
      'TallTalesGrade(${reasoning.name}, $suppositions suppositions, '
      '$openAfterBasic open)';
}

/// Grades [puzzle] by the reasoning it needs and the fishers basic
/// reasoning leaves open.
///
/// Any grade below [TallTalesReasoning.search] also proves that the puzzle
/// has exactly one solution, because every deduction holds for every
/// solution.
TallTalesGrade gradeTallTales(TallTalesPuzzle puzzle) {
  final grader = _Grader(puzzle);
  final knowledge = _Knowledge(puzzle.fisherCount);
  var openAfterBasic = puzzle.fisherCount;
  TallTalesGrade grade(TallTalesReasoning reasoning, int suppositions) =>
      TallTalesGrade._(
        reasoning: reasoning,
        suppositions: suppositions,
        openAfterBasic: openAfterBasic,
      );

  if (!grader.propagate(knowledge, links: false)) {
    return grade(TallTalesReasoning.search, 0);
  }
  openAfterBasic = knowledge.unknownCount;
  if (knowledge.isComplete) {
    return grade(TallTalesReasoning.basic, 0);
  }
  if (!grader.propagate(knowledge, links: true)) {
    return grade(TallTalesReasoning.search, 0);
  }
  if (knowledge.isComplete) {
    return grade(TallTalesReasoning.advanced, 0);
  }

  var suppositions = 0;
  while (!knowledge.isComplete) {
    if (!grader.suppose(knowledge)) {
      return grade(TallTalesReasoning.search, suppositions);
    }
    suppositions++;
  }
  return grade(TallTalesReasoning.lookahead, suppositions);
}

/// A kind that is not known yet.
const int _unknown = -1;

/// The kind of a fisher who tells tall tales.
const int _tallTales = 0;

/// The kind of a fisher who tells the truth.
const int _truth = 1;

/// What reasoning has found out about the fishers: the kind of some, and
/// which fishers are alike or not alike.
///
/// Linked fishers form a group under one leader, each with a flip that is 1
/// if they are not alike the leader. Once one member's kind is known, so is
/// every member's.
final class _Knowledge {
  _Knowledge(int fisherCount)
    : kinds = List.filled(fisherCount, _unknown),
      _leader = [for (var fisher = 0; fisher < fisherCount; fisher++) fisher],
      _flip = List.filled(fisherCount, 0);

  _Knowledge._copy(_Knowledge other)
    : kinds = [...other.kinds],
      _leader = [...other._leader],
      _flip = [...other._flip];

  /// The kind of each fisher: [_truth], [_tallTales] or [_unknown].
  final List<int> kinds;

  final List<int> _leader;
  final List<int> _flip;

  _Knowledge copy() => _Knowledge._copy(this);

  bool get isComplete => !kinds.contains(_unknown);

  int get unknownCount => kinds.where((kind) => kind == _unknown).length;

  /// The fishers known to tell the truth, as a bit set.
  int get truthful {
    var bits = 0;
    for (var fisher = 0; fisher < kinds.length; fisher++) {
      if (kinds[fisher] == _truth) {
        bits |= 1 << fisher;
      }
    }
    return bits;
  }

  /// Whether [a] and [b] are known to be alike or not alike.
  bool isLinked(int a, int b) => _leader[a] == _leader[b];

  /// For linked fishers [a] and [b], 0 if they are alike and 1 if not.
  int difference(int a, int b) => _flip[a] ^ _flip[b];

  /// Records that [fisher] is of [kind], and so every fisher linked to
  /// them. Returns `false` if that contradicts what is known.
  bool setKind(int fisher, int kind) {
    for (var other = 0; other < kinds.length; other++) {
      if (_leader[other] != _leader[fisher]) {
        continue;
      }
      final otherKind = kind ^ difference(fisher, other);
      if (kinds[other] == _unknown) {
        kinds[other] = otherKind;
      } else if (kinds[other] != otherKind) {
        return false;
      }
    }
    return true;
  }

  /// Records that [a] and [b] are alike if [difference] is 0, or not alike
  /// if it is 1. Returns `false` if that contradicts what is known.
  bool link(int a, int b, int difference) {
    if (isLinked(a, b)) {
      return this.difference(a, b) == difference;
    }
    final joining = _leader[b];
    final adjustment = _flip[a] ^ _flip[b] ^ difference;
    for (var other = 0; other < kinds.length; other++) {
      if (_leader[other] == joining) {
        _leader[other] = _leader[a];
        _flip[other] ^= adjustment;
      }
    }
    // A kind known on either side now settles the whole group.
    for (var other = 0; other < kinds.length; other++) {
      if (_leader[other] == _leader[a] && kinds[other] != _unknown) {
        return setKind(other, kinds[other]);
      }
    }
    return true;
  }
}

/// Applies the statements of a puzzle to what is known, the way a person
/// reasons about them.
final class _Grader {
  _Grader(this.puzzle)
    : _dependsOn = [
        for (var speaker = 0; speaker < puzzle.fisherCount; speaker++)
          puzzle.dependsOn(speaker),
      ];

  final TallTalesPuzzle puzzle;
  final List<List<int>> _dependsOn;

  /// Applies the statements one at a time until none settles anything
  /// more. With [links], it also finds fishers that are alike or not alike
  /// and keeps to those links. Returns `false` if a statement cannot fit.
  bool propagate(_Knowledge knowledge, {required bool links}) {
    var changed = true;
    while (changed) {
      changed = false;
      for (var speaker = 0; speaker < puzzle.fisherCount; speaker++) {
        switch (_apply(speaker, knowledge, links: links)) {
          case null:
            return false;
          case true:
            changed = true;
          case false:
            break;
        }
      }
    }
    return true;
  }

  /// Supposes each undecided fisher to be of each kind in turn, until one
  /// supposition leads to a broken statement, and records the other kind.
  /// Returns `false` if no supposition does, or the puzzle has no solution.
  bool suppose(_Knowledge knowledge) {
    for (var fisher = 0; fisher < puzzle.fisherCount; fisher++) {
      if (knowledge.kinds[fisher] != _unknown) {
        continue;
      }
      for (final kind in const [_truth, _tallTales]) {
        final trial = knowledge.copy();
        if (trial.setKind(fisher, kind) && propagate(trial, links: true)) {
          continue;
        }
        return knowledge.setKind(fisher, 1 - kind) &&
            propagate(knowledge, links: true);
      }
    }
    return false;
  }

  /// Applies the statement of [speaker] on its own: every way to complete
  /// the kinds it depends on that fits it, and the links among them with
  /// [links], shows what must hold. Returns whether it settled anything, or
  /// `null` if no way fits.
  bool? _apply(int speaker, _Knowledge knowledge, {required bool links}) {
    final open = [
      for (final fisher in _dependsOn[speaker])
        if (knowledge.kinds[fisher] == _unknown) fisher,
    ];
    final known = knowledge.truthful;
    if (open.isEmpty) {
      return puzzle.fitsSpeaker(speaker, known) ? false : null;
    }

    // The links among the open fishers, which each way must keep.
    final linked = <(int, int, int)>[
      if (links)
        for (var first = 0; first < open.length; first++)
          for (var second = first + 1; second < open.length; second++)
            if (knowledge.isLinked(open[first], open[second]))
              (
                first,
                second,
                knowledge.difference(open[first], open[second]),
              ),
    ];

    var canTruth = 0;
    var canTales = 0;
    // For each open fisher, the later ones seen alike and seen not alike.
    final seenAlike = List.filled(open.length, 0);
    final seenUnlike = List.filled(open.length, 0);
    var anyFits = false;
    for (var way = 0; way < 1 << open.length; way++) {
      var truthful = known;
      for (var index = 0; index < open.length; index++) {
        if ((way >> index) & 1 == 1) {
          truthful |= 1 << open[index];
        }
      }
      if (!puzzle.fitsSpeaker(speaker, truthful) ||
          linked.any(
            (link) => ((way >> link.$1) ^ (way >> link.$2)) & 1 != link.$3,
          )) {
        continue;
      }
      anyFits = true;
      canTruth |= way;
      canTales |= ~way & ((1 << open.length) - 1);
      if (links) {
        for (var first = 0; first < open.length; first++) {
          for (var second = first + 1; second < open.length; second++) {
            if (((way >> first) ^ (way >> second)) & 1 == 0) {
              seenAlike[first] |= 1 << second;
            } else {
              seenUnlike[first] |= 1 << second;
            }
          }
        }
      }
    }
    if (!anyFits) {
      return null;
    }

    var settled = false;
    for (var index = 0; index < open.length; index++) {
      final truth = (canTruth >> index) & 1 == 1;
      final tales = (canTales >> index) & 1 == 1;
      if (truth == tales || knowledge.kinds[open[index]] != _unknown) {
        continue;
      }
      if (!knowledge.setKind(open[index], truth ? _truth : _tallTales)) {
        return null;
      }
      settled = true;
    }
    if (!links) {
      return settled;
    }
    for (var first = 0; first < open.length; first++) {
      for (var second = first + 1; second < open.length; second++) {
        final a = open[first];
        final b = open[second];
        final alike = (seenAlike[first] >> second) & 1 == 1;
        final unlike = (seenUnlike[first] >> second) & 1 == 1;
        if (alike == unlike ||
            knowledge.kinds[a] != _unknown ||
            knowledge.kinds[b] != _unknown ||
            knowledge.isLinked(a, b)) {
          continue;
        }
        if (!knowledge.link(a, b, alike ? 0 : 1)) {
          return null;
        }
        settled = true;
      }
    }
    return settled;
  }
}
