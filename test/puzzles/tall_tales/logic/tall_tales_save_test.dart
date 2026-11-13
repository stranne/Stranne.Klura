import 'dart:convert';

import 'package:klura/puzzles/tall_tales/logic/tall_tales_generator.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_marks.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_save.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_text.dart';
import 'package:test/test.dart';

void main() {
  final (puzzle, marks) = parseTallTales('''
+ Alva: Exactly two of us tell tall tales.
. Bo: If Cajsa tells the truth, so does Alva.
- Cajsa: Alva and Bo are alike.
''');
  final save = TallTalesSave(
    level: TallTalesLevel.hard,
    date: DateTime(2026, 11, 13, 21, 5),
    seedKey: 'tall-tales-hard:v1:2026-11-13',
    puzzle: puzzle,
    marks: marks,
    playedTime: const Duration(minutes: 3, milliseconds: 250),
    wasSolved: true,
  );

  /// [save] as JSON, with [change] applied to it.
  String changed(void Function(Map<String, Object?> json) change) {
    final json = jsonDecode(encodeTallTalesSave(save)) as Map<String, Object?>;
    change(json);
    return jsonEncode(json);
  }

  test('keeps only the date of the day', () {
    expect(save.date, DateTime(2026, 11, 13));
  });

  test('writes the puzzle, marks, time and solve as JSON', () {
    expect(jsonDecode(encodeTallTalesSave(save)), {
      'format': 1,
      'level': 'hard',
      'date': '2026-11-13',
      'seedKey': 'tall-tales-hard:v1:2026-11-13',
      'statements': [
        {'claim': 'countTallTales', 'count': 2},
        {
          'claim': 'ifTruthful',
          'named': [2, 0],
        },
        {
          'claim': 'alike',
          'named': [0, 1],
        },
      ],
      'marks': ['truth', null, 'tallTales'],
      'playedMs': 180250,
      'solved': true,
    });
  });

  test('reads back what it writes', () {
    final read = decodeTallTalesSave(encodeTallTalesSave(save));

    expect(read, save);
    expect(read.hashCode, save.hashCode);
  });

  test('rejects marks for another number of fishers', () {
    expect(
      () => TallTalesSave(
        level: TallTalesLevel.normal,
        date: DateTime(2026, 11, 13),
        seedKey: 'test',
        puzzle: puzzle,
        marks: TallTalesMarks.empty(4),
      ),
      throwsArgumentError,
    );
  });

  test('rejects a negative time', () {
    expect(
      () => TallTalesSave(
        level: TallTalesLevel.normal,
        date: DateTime(2026, 11, 13),
        seedKey: 'test',
        puzzle: puzzle,
        marks: marks,
        playedTime: const Duration(seconds: -1),
      ),
      throwsArgumentError,
    );
  });

  group('reads as missing', () {
    final cases = {
      'text that is not JSON': '{"format": 1',
      'another format version': changed((json) => json['format'] = 2),
      'an unknown level': changed((json) => json['level'] = 'easy'),
      'a date that does not exist': changed(
        (json) => json['date'] = '2026-02-30',
      ),
      'a negative time': changed((json) => json['playedMs'] = -1),
      'a missing field': changed((json) => json.remove('solved')),
      'an unknown mark': changed(
        (json) => json['marks'] = ['truth', 'maybe', null],
      ),
      'marks for too few fishers': changed(
        (json) => json['marks'] = ['truth', null],
      ),
      'an unknown claim': changed(
        (json) => (json['statements']! as List<Object?>)[0] = {
          'claim': 'fibs',
          'count': 2,
        },
      ),
      'a statement that names its speaker': changed(
        (json) => (json['statements']! as List<Object?>)[2] = {
          'claim': 'alike',
          'named': [1, 2],
        },
      ),
      'a statement that names too few fishers': changed(
        (json) => (json['statements']! as List<Object?>)[2] = {
          'claim': 'alike',
          'named': [0],
        },
      ),
      'a count of every fisher': changed(
        (json) => (json['statements']! as List<Object?>)[0] = {
          'claim': 'countTruthful',
          'count': 3,
        },
      ),
      'a fisher who is not a number': changed(
        (json) => (json['statements']! as List<Object?>)[2] = {
          'claim': 'alike',
          'named': ['Alva', 'Bo'],
        },
      ),
      'too few fishers': changed(
        (json) => json
          ..['statements'] = (json['statements']! as List<Object?>).sublist(1)
          ..['marks'] = [null, null],
      ),
    };

    for (final MapEntry(key: description, value: text) in cases.entries) {
      test(description, () {
        expect(decodeTallTalesSave(text), isNull);
      });
    }
  });
}
