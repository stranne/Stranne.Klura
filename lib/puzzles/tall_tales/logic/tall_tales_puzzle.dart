import 'package:meta/meta.dart';

/// The names of the fishers, in the order they sit on the jetty.
///
/// A puzzle of n fishers has the first n. Each name starts with a letter of
/// its own, from A on, so the fishers are easy to tell apart.
const List<String> tallTalesNames = [
  'Alva',
  'Bo',
  'Cajsa',
  'Dag',
  'Ebba',
  'Frej',
  'Greta',
  'Hugo',
];

/// What a statement claims, with `X`, `Y` and `Z` for the fishers it names
/// and `N` for its count.
///
/// Two fishers are alike when both tell the truth or both tell tall tales.
/// `Us` is every fisher on the jetty, the speaker included.
enum TallTalesClaim {
  /// `X tells the truth.`
  truthful(named: 1, weight: 3),

  /// `X tells tall tales.`
  tallTales(named: 1, weight: 3),

  /// `X and Y are alike.`
  alike(named: 2, weight: 2),

  /// `X and Y are not alike.`
  notAlike(named: 2, weight: 2),

  /// `X and Y both tell the truth.`
  bothTruthful(named: 2, weight: 2),

  /// `X and Y both tell tall tales.`
  bothTallTales(named: 2, weight: 2),

  /// `At least one of X and Y tells the truth.`
  eitherTruthful(named: 2, weight: 2),

  /// `If X tells the truth, so does Y.`
  ifTruthful(named: 2, weight: 2),

  /// `Exactly one of X, Y and Z tells the truth.`
  oneOfThreeTruthful(named: 3, weight: 1),

  /// `Exactly N of us tell the truth.`
  countTruthful(named: 0, weight: 1),

  /// `Exactly N of us tell tall tales.`
  countTallTales(named: 0, weight: 1),

  /// `X and I are alike.`
  alikeMe(named: 1, weight: 1),

  /// `X and I are not alike.`
  notAlikeMe(named: 1, weight: 1),

  /// `X and I both tell tall tales.`
  bothTallTalesMe(named: 1, weight: 1),

  /// `At least one of X and me tells tall tales.`
  eitherTallTalesMe(named: 1, weight: 1);

  const TallTalesClaim({required this.named, required this.weight});

  /// How many fishers other than the speaker the claim names.
  final int named;

  /// How often the generator picks the claim, relative to the others.
  final int weight;

  /// Whether the claim counts every fisher rather than naming some.
  bool get isCount => this == countTruthful || this == countTallTales;

  /// Whether the claim is about the speaker too.
  ///
  /// Each of these settles the fisher it names on its own, whatever the
  /// speaker is, so they are the usual way into a puzzle.
  bool get isAboutSpeaker => switch (this) {
    alikeMe || notAlikeMe || bothTallTalesMe || eitherTallTalesMe => true,
    _ => false,
  };

  /// Whether the order of the named fishers makes no difference, in which
  /// case statements name them in the order they sit.
  bool get isSymmetric => named >= 2 && this != ifTruthful;
}

/// What one fisher says: a [claim] about the fishers [named], by their
/// place on the jetty, or about how many fishers [count] of a kind.
///
/// A statement does not know who makes it; it is the statement of the
/// fisher at its place in a [TallTalesPuzzle].
@immutable
final class TallTalesStatement {
  /// Creates a statement that makes [claim] about the fishers [named], in
  /// the order given.
  ///
  /// Throws an [ArgumentError] if [claim] counts fishers, or [named] holds
  /// the wrong number of fishers or one of them twice.
  TallTalesStatement(this.claim, List<int> named)
    : named = List.unmodifiable(named),
      count = 0 {
    if (claim.isCount) {
      throw ArgumentError.value(claim, 'claim', 'Needs a count');
    }
    if (named.length != claim.named || named.toSet().length != named.length) {
      throw ArgumentError.value(
        named,
        'named',
        'Must name ${claim.named} different fishers',
      );
    }
  }

  /// Creates a statement that [count] fishers are of the kind [claim]
  /// counts.
  ///
  /// Throws an [ArgumentError] if [claim] names fishers or [count] is below
  /// 1.
  TallTalesStatement.count(this.claim, this.count) : named = const [] {
    if (!claim.isCount) {
      throw ArgumentError.value(claim, 'claim', 'Must count fishers');
    }
    if (count < 1) {
      throw ArgumentError.value(count, 'count', 'Must be at least 1');
    }
  }

  final TallTalesClaim claim;

  /// The fishers the statement names, apart from the speaker.
  final List<int> named;

  /// How many fishers a counting claim counts, otherwise 0.
  final int count;

  /// Whether the statement is true when made by [speaker] among
  /// [fisherCount] fishers, of whom those in the bit set [truthful] tell the
  /// truth.
  bool isTrue(int speaker, int truthful, int fisherCount) {
    bool tellsTruth(int fisher) => (truthful >> fisher) & 1 == 1;

    final me = tellsTruth(speaker);
    final x = named.isNotEmpty && tellsTruth(named[0]);
    final y = named.length > 1 && tellsTruth(named[1]);
    return switch (claim) {
      TallTalesClaim.truthful => x,
      TallTalesClaim.tallTales => !x,
      TallTalesClaim.alike => x == y,
      TallTalesClaim.notAlike => x != y,
      TallTalesClaim.bothTruthful => x && y,
      TallTalesClaim.bothTallTales => !x && !y,
      TallTalesClaim.eitherTruthful => x || y,
      TallTalesClaim.ifTruthful => !x || y,
      TallTalesClaim.oneOfThreeTruthful => named.where(tellsTruth).length == 1,
      TallTalesClaim.countTruthful => _bitCount(truthful) == count,
      TallTalesClaim.countTallTales =>
        fisherCount - _bitCount(truthful) == count,
      TallTalesClaim.alikeMe => x == me,
      TallTalesClaim.notAlikeMe => x != me,
      TallTalesClaim.bothTallTalesMe => !x && !me,
      TallTalesClaim.eitherTallTalesMe => !x || !me,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is TallTalesStatement &&
      other.claim == claim &&
      other.count == count &&
      _sameList(other.named, named);

  @override
  int get hashCode => Object.hash(claim, count, Object.hashAll(named));

  @override
  String toString() => claim.isCount
      ? 'TallTalesStatement(${claim.name}, $count)'
      : 'TallTalesStatement(${claim.name}, $named)';
}

/// A puzzle of Tall Tales: the fishers on the jetty, each with one
/// statement.
///
/// Every fisher either always tells the truth or always tells tall tales.
/// A truth-teller's statement is true and a teller of tall tales' statement
/// is false. A puzzle is solved by the marking of every fisher under which
/// all the statements fit.
///
/// Kinds are passed around as bit sets: bit i of `truthful` is set when the
/// fisher at place i tells the truth. With at most [maxFishers] fishers,
/// they stay far within 32 bits.
@immutable
final class TallTalesPuzzle {
  /// Creates a puzzle where the fisher at place i makes `statements[i]`.
  ///
  /// Throws an [ArgumentError] if there are fewer than [minFishers] or more
  /// than [maxFishers] fishers, a statement names its speaker or a fisher
  /// who is not on the jetty, or a count is not below the number of
  /// fishers.
  TallTalesPuzzle(List<TallTalesStatement> statements)
    : statements = List.unmodifiable(statements) {
    final fishers = statements.length;
    if (fishers < minFishers || fishers > maxFishers) {
      throw ArgumentError.value(
        fishers,
        'statements',
        'Needs $minFishers to $maxFishers fishers',
      );
    }
    for (var speaker = 0; speaker < fishers; speaker++) {
      final statement = statements[speaker];
      for (final fisher in statement.named) {
        if (fisher < 0 || fisher >= fishers || fisher == speaker) {
          throw ArgumentError.value(
            statement,
            'statements',
            'Must name other fishers on the jetty',
          );
        }
      }
      if (statement.count >= fishers) {
        throw ArgumentError.value(
          statement,
          'statements',
          'Must count fewer than all $fishers fishers',
        );
      }
    }
  }

  static const int minFishers = 3;

  /// The most fishers a puzzle may have, one for each name.
  static final int maxFishers = tallTalesNames.length;

  /// The statement of each fisher, in the order they sit.
  final List<TallTalesStatement> statements;

  int get fisherCount => statements.length;

  /// Whether the statement of [speaker] is true when the fishers in the bit
  /// set [truthful] tell the truth.
  bool isTrue(int speaker, int truthful) =>
      statements[speaker].isTrue(speaker, truthful, fisherCount);

  /// Whether the statement of [speaker] fits the bit set [truthful]: true if
  /// [speaker] tells the truth and false if not.
  bool fitsSpeaker(int speaker, int truthful) =>
      isTrue(speaker, truthful) == ((truthful >> speaker) & 1 == 1);

  /// Whether every statement fits the bit set [truthful].
  bool fits(int truthful) {
    for (var speaker = 0; speaker < fisherCount; speaker++) {
      if (!fitsSpeaker(speaker, truthful)) {
        return false;
      }
    }
    return true;
  }

  /// The fishers whose kinds decide whether the statement of [speaker]
  /// fits, in the order they sit: [speaker] and the fishers it names, or
  /// every fisher for a count.
  List<int> dependsOn(int speaker) {
    final statement = statements[speaker];
    if (statement.claim.isCount) {
      return [for (var fisher = 0; fisher < fisherCount; fisher++) fisher];
    }
    return {speaker, ...statement.named}.toList()..sort();
  }

  @override
  bool operator ==(Object other) =>
      other is TallTalesPuzzle && _sameList(other.statements, statements);

  @override
  int get hashCode => Object.hashAll(statements);

  @override
  String toString() => 'TallTalesPuzzle($statements)';
}

/// Every statement the fisher at [speaker] can make among [fisherCount]
/// fishers, claim by claim in the order of [TallTalesClaim].
///
/// A symmetric claim names its fishers in the order they sit, and a count
/// is below [fisherCount].
List<TallTalesStatement> possibleStatements(int speaker, int fisherCount) {
  final others = [
    for (var fisher = 0; fisher < fisherCount; fisher++)
      if (fisher != speaker) fisher,
  ];
  final pairs = [
    for (final x in others)
      for (final y in others)
        if (x != y) [x, y],
  ];
  final triples = [
    for (final [x, y] in pairs)
      for (final z in others)
        if (x < y && y < z) [x, y, z],
  ];

  List<List<int>> namedBy(TallTalesClaim claim) => switch (claim.named) {
    1 => [
      for (final x in others) [x],
    ],
    2 => [
      for (final pair in pairs)
        if (!claim.isSymmetric || pair[0] < pair[1]) pair,
    ],
    _ => triples,
  };

  return [
    for (final claim in TallTalesClaim.values)
      if (claim.isCount)
        for (var count = 1; count < fisherCount; count++)
          TallTalesStatement.count(claim, count)
      else
        for (final named in namedBy(claim)) TallTalesStatement(claim, named),
  ];
}

int _bitCount(int bits) {
  var count = 0;
  for (var rest = bits; rest != 0; rest &= rest - 1) {
    count++;
  }
  return count;
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}
