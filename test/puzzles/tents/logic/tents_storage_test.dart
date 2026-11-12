import 'package:klura/core/local_store.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_storage.dart';
import 'package:klura/puzzles/tents/logic/tents_generator.dart';
import 'package:klura/puzzles/tents/logic/tents_save.dart';
import 'package:klura/puzzles/tents/logic/tents_storage.dart';
import 'package:klura/puzzles/tents/logic/tents_text.dart';
import 'package:test/test.dart';

void main() {
  final today = DateTime(2026, 11, 12);
  final yesterday = DateTime(2026, 11, 11);
  final (puzzle, marks) = parseTents('''
  0002
1 -.T^
0 ....
1 ..T.
''');

  TentsSave saveOf(TentsLevel level, DateTime date, {bool wasSolved = false}) =>
      TentsSave(
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
    final storage = TentsStorage(store);
    final normal = saveOf(TentsLevel.normal, today);
    final hard = saveOf(TentsLevel.hard, today);

    storage
      ..saveGame(normal)
      ..saveGame(hard);

    expect(
      store.keys,
      unorderedEquals([
        'klura.tents.normal.2026-11-12',
        'klura.tents.hard.2026-11-12',
      ]),
    );
    expect(TentsStorage.gameKey(TentsLevel.hard, today), store.keys.last);
    expect(storage.loadGame(TentsLevel.normal, today), normal);
    expect(storage.loadGame(TentsLevel.hard, today), hard);
    expect(storage.loadGame(TentsLevel.normal, yesterday), isNull);
  });

  test('records solves in a history of its own', () {
    final store = MemoryLocalStore();
    final storage = TentsStorage(store);

    final history = storage.recordSolve(
      TentsLevel.normal,
      today,
      const Duration(seconds: 80),
    );

    expect(TentsStorage.historyKey, 'klura.tents.history');
    expect(store.keys, [TentsStorage.historyKey]);
    expect(
      history.solveTime(TentsLevel.normal, today),
      const Duration(seconds: 80),
    );
  });

  test('shares a store with Bridges without either touching the other', () {
    final store = MemoryLocalStore();
    final tents = TentsStorage(store);
    final bridges = BridgesStorage(store);
    tents
      ..saveGame(saveOf(TentsLevel.normal, yesterday, wasSolved: true))
      ..saveGame(saveOf(TentsLevel.normal, today));
    bridges.recordSolve(BridgesLevel.normal, today, Duration.zero);
    store.write(BridgesStorage.gameKey(BridgesLevel.hard, yesterday), '{}');

    final history = tents.removeGamesBefore(today);

    expect(
      store.keys,
      unorderedEquals([
        'klura.tents.normal.2026-11-12',
        'klura.tents.history',
        'klura.bridges.history',
        'klura.bridges.hard.2026-11-11',
      ]),
    );
    expect(
      history.solveTime(TentsLevel.normal, yesterday),
      const Duration(seconds: 30),
    );
    expect(
      bridges.loadHistory().solveTime(BridgesLevel.normal, today),
      Duration.zero,
    );
  });
}
