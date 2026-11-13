import 'package:klura/core/local_store.dart';
import 'package:klura/puzzles/logjam/logic/logjam_board.dart';
import 'package:klura/puzzles/logjam/logic/logjam_generator.dart';
import 'package:klura/puzzles/logjam/logic/logjam_save.dart';
import 'package:klura/puzzles/logjam/logic/logjam_storage.dart';
import 'package:klura/puzzles/logjam/logic/logjam_text.dart';
import 'package:test/test.dart';

void main() {
  final today = DateTime(2026, 11, 12);
  final yesterday = DateTime(2026, 11, 11);
  final puzzle = parseLogjam('''
A...
A**B>
...B
CC..
''');

  LogjamSave saveOf(
    LogjamLevel level,
    DateTime date, {
    bool wasSolved = false,
  }) => LogjamSave(
    level: level,
    date: date,
    seedKey: 'test',
    puzzle: puzzle,
    fewestMoves: 2,
    moves: const [LogjamMove(piece: 3, to: 1)],
    playedTime: const Duration(seconds: 30),
    wasSolved: wasSolved,
  );

  test('keeps each game under a key of its own', () {
    final store = MemoryLocalStore();
    final storage = LogjamStorage(store);
    final normal = saveOf(LogjamLevel.normal, today);
    final hard = saveOf(LogjamLevel.hard, today);

    storage
      ..saveGame(normal)
      ..saveGame(hard);

    expect(
      store.keys,
      unorderedEquals([
        'klura.logjam.normal.2026-11-12',
        'klura.logjam.hard.2026-11-12',
      ]),
    );
    expect(LogjamStorage.gameKey(LogjamLevel.hard, today), store.keys.last);
    expect(storage.loadGame(LogjamLevel.normal, today), normal);
    expect(storage.loadGame(LogjamLevel.hard, today), hard);
    expect(storage.loadGame(LogjamLevel.normal, yesterday), isNull);
  });

  test("keeps yesterday's solve in the history of its own", () {
    final store = MemoryLocalStore();
    final storage = LogjamStorage(store)
      ..saveGame(saveOf(LogjamLevel.hard, yesterday, wasSolved: true));

    final history = storage.removeGamesBefore(today);

    expect(store.keys, [LogjamStorage.historyKey]);
    expect(LogjamStorage.historyKey, 'klura.logjam.history');
    expect(
      history.solveTime(LogjamLevel.hard, yesterday),
      const Duration(seconds: 30),
    );
  });
}
