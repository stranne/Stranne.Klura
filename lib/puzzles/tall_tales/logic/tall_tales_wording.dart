import 'package:klura/puzzles/tall_tales/logic/tall_tales_puzzle.dart';
import 'package:meta/meta.dart';

/// A piece of a statement as the player reads it: words, or the name of a
/// fisher.
@immutable
sealed class StatementPart {
  const StatementPart();
}

/// Words of a statement, such as ` tells the truth.`
final class StatementWords extends StatementPart {
  const StatementWords(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is StatementWords && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'StatementWords($text)';
}

/// The name of the fisher at place [fisher] in a statement.
final class StatementName extends StatementPart {
  const StatementName(this.fisher);

  final int fisher;

  /// The fisher's name, such as `Alva`.
  String get name => tallTalesNames[fisher];

  @override
  bool operator ==(Object other) =>
      other is StatementName && other.fisher == fisher;

  @override
  int get hashCode => fisher.hashCode;

  @override
  String toString() => 'StatementName($name)';
}

/// The words of [statement] as the player reads it, with the names of the
/// fishers it names as parts of their own, such as `Bo`, ` and `, `Dag`
/// and ` are alike.`
///
/// The speaker is `I` or `me`, and `us` is every fisher on the jetty.
List<StatementPart> statementParts(TallTalesStatement statement) {
  final names = [for (final fisher in statement.named) StatementName(fisher)];
  StatementName name(int index) => names[index];

  return switch (statement.claim) {
    TallTalesClaim.truthful => [name(0), const StatementWords(_tellsTruth)],
    TallTalesClaim.tallTales => [name(0), const StatementWords(_tellsTales)],
    TallTalesClaim.alike => [
      name(0),
      const StatementWords(' and '),
      name(1),
      const StatementWords(' are alike.'),
    ],
    TallTalesClaim.notAlike => [
      name(0),
      const StatementWords(' and '),
      name(1),
      const StatementWords(' are not alike.'),
    ],
    TallTalesClaim.bothTruthful => [
      name(0),
      const StatementWords(' and '),
      name(1),
      const StatementWords(' both tell the truth.'),
    ],
    TallTalesClaim.bothTallTales => [
      name(0),
      const StatementWords(' and '),
      name(1),
      const StatementWords(' both tell tall tales.'),
    ],
    TallTalesClaim.eitherTruthful => [
      const StatementWords('At least one of '),
      name(0),
      const StatementWords(' and '),
      name(1),
      const StatementWords(_tellsTruth),
    ],
    TallTalesClaim.ifTruthful => [
      const StatementWords('If '),
      name(0),
      const StatementWords(' tells the truth, so does '),
      name(1),
      const StatementWords('.'),
    ],
    TallTalesClaim.oneOfThreeTruthful => [
      const StatementWords('Exactly one of '),
      name(0),
      const StatementWords(', '),
      name(1),
      const StatementWords(' and '),
      name(2),
      const StatementWords(_tellsTruth),
    ],
    TallTalesClaim.countTruthful => [
      StatementWords(
        'Exactly ${_count(statement.count)} of us '
        '${statement.count == 1 ? 'tells' : 'tell'} the truth.',
      ),
    ],
    TallTalesClaim.countTallTales => [
      StatementWords(
        'Exactly ${_count(statement.count)} of us '
        '${statement.count == 1 ? 'tells' : 'tell'} tall tales.',
      ),
    ],
    TallTalesClaim.alikeMe => [
      name(0),
      const StatementWords(' and I are alike.'),
    ],
    TallTalesClaim.notAlikeMe => [
      name(0),
      const StatementWords(' and I are not alike.'),
    ],
    TallTalesClaim.bothTallTalesMe => [
      name(0),
      const StatementWords(' and I both tell tall tales.'),
    ],
    TallTalesClaim.eitherTallTalesMe => [
      const StatementWords('At least one of '),
      name(0),
      const StatementWords(' and me'),
      const StatementWords(_tellsTales),
    ],
  };
}

/// The words of [statement] as the player reads it, such as `Bo and Dag
/// are alike.`
String statementText(TallTalesStatement statement) => [
  for (final part in statementParts(statement))
    switch (part) {
      StatementWords(:final text) => text,
      final StatementName name => name.name,
    },
].join();

const String _tellsTruth = ' tells the truth.';
const String _tellsTales = ' tells tall tales.';

const List<String> _numbers = [
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
];

/// [count] in words, from `one` to `seven`, or in digits beyond.
String _count(int count) =>
    count >= 1 && count <= _numbers.length ? _numbers[count - 1] : '$count';
