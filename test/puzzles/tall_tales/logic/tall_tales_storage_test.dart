import 'package:klura/core/local_store.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_generator.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_save.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_storage.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_text.dart';
import 'package:test/test.dart';

void main() {
  final today = DateTime(2026, 11, 13);
  final yesterday = DateTime(2026, 11, 12);
  final (puzzle, marks) = parseTallTales('''
+ Alva: Bo and I are not alike.
. Bo: Cajsa tells the truth.
. Cajsa: Alva tells tall tales.
''');

  TallTalesSave saveOf(
    TallTalesLevel level,
    DateTime date, {
    bool wasSolved = false,
  }) => TallTalesSave(
    level: level,
    date: date,
    seedKey: 'test',
    puzzle: puzzle,
    marks: marks,
    playedTime: const Duration(seconds: 30),
    wasSolved: wasSolved,
  );

  test('keeps each game under a key of its own', () {
    final store = MemoryLocalStore();
    final storage = TallTalesStorage(store);
    final normal = saveOf(TallTalesLevel.normal, today);
    final hard = saveOf(TallTalesLevel.hard, today);

    storage
      ..saveGame(normal)
      ..saveGame(hard);

    expect(
      store.keys,
      unorderedEquals([
        'klura.tall-tales.normal.2026-11-13',
        'klura.tall-tales.hard.2026-11-13',
      ]),
    );
    expect(
      TallTalesStorage.gameKey(TallTalesLevel.hard, today),
      store.keys.last,
    );
    expect(storage.loadGame(TallTalesLevel.normal, today), normal);
    expect(storage.loadGame(TallTalesLevel.hard, today), hard);
    expect(storage.loadGame(TallTalesLevel.normal, yesterday), isNull);
  });

  test("keeps yesterday's solve in the history of its own", () {
    final store = MemoryLocalStore();
    final storage = TallTalesStorage(store)
      ..saveGame(saveOf(TallTalesLevel.hard, yesterday, wasSolved: true));

    final history = storage.removeGamesBefore(today);

    expect(store.keys, [TallTalesStorage.historyKey]);
    expect(TallTalesStorage.historyKey, 'klura.tall-tales.history');
    expect(
      history.solveTime(TallTalesLevel.hard, yesterday),
      const Duration(seconds: 30),
    );
  });
}
