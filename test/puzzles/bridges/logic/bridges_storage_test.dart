import 'package:klura/core/local_store.dart';
import 'package:klura/core/solve_history.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_save.dart';
import 'package:klura/puzzles/bridges/logic/bridges_storage.dart';
import 'package:klura/puzzles/bridges/logic/bridges_text.dart';
import 'package:test/test.dart';

void main() {
  final today = DateTime(2026, 11, 12);
  final yesterday = DateTime(2026, 11, 11);
  final small = parseBridges('''
3=2
...
1..
''');

  BridgesSave saveOf(
    BridgesLevel level,
    DateTime date, {
    Duration playedTime = const Duration(seconds: 30),
    bool wasSolved = false,
  }) => BridgesSave(
    level: level,
    date: date,
    seedKey: 'test',
    puzzle: small.puzzle,
    arrangement: small.arrangement,
    playedTime: playedTime,
    wasSolved: wasSolved,
  );

  test('keeps each game under a key of its own', () {
    final store = MemoryLocalStore();
    final storage = BridgesStorage(store);
    final normal = saveOf(BridgesLevel.normal, today);
    final hard = saveOf(BridgesLevel.hard, today);

    storage
      ..saveGame(normal)
      ..saveGame(hard)
      ..saveGame(saveOf(BridgesLevel.normal, yesterday));

    expect(
      store.keys,
      unorderedEquals([
        'klura.bridges.normal.2026-11-12',
        'klura.bridges.hard.2026-11-12',
        'klura.bridges.normal.2026-11-11',
      ]),
    );
    expect(storage.loadGame(BridgesLevel.normal, today), normal);
    expect(
      storage.loadGame(BridgesLevel.hard, DateTime(2026, 11, 12, 9)),
      hard,
    );
    expect(storage.loadGame(BridgesLevel.hard, yesterday), isNull);
  });

  test('replaces a game when it is saved again', () {
    final storage = BridgesStorage(MemoryLocalStore());
    final later = saveOf(
      BridgesLevel.normal,
      today,
      playedTime: const Duration(minutes: 2),
    );

    storage
      ..saveGame(saveOf(BridgesLevel.normal, today))
      ..saveGame(later);

    expect(storage.loadGame(BridgesLevel.normal, today), later);
  });

  test('treats a damaged game as missing', () {
    final store = MemoryLocalStore({
      'klura.bridges.normal.2026-11-12': '{"format": 1, "level": "nor',
    });

    expect(BridgesStorage(store).loadGame(BridgesLevel.normal, today), isNull);
  });

  test("treats a game under another game's key as missing", () {
    final store = MemoryLocalStore({
      BridgesStorage.gameKey(BridgesLevel.normal, today): encodeBridgesSave(
        saveOf(BridgesLevel.hard, today),
      ),
      BridgesStorage.gameKey(BridgesLevel.hard, today): encodeBridgesSave(
        saveOf(BridgesLevel.hard, yesterday),
      ),
    });
    final storage = BridgesStorage(store);

    expect(storage.loadGame(BridgesLevel.normal, today), isNull);
    expect(storage.loadGame(BridgesLevel.hard, today), isNull);
  });

  group('history', () {
    test('is empty when missing or damaged', () {
      final damaged = MemoryLocalStore({BridgesStorage.historyKey: 'oops'});

      for (final store in [MemoryLocalStore(), damaged]) {
        final history = BridgesStorage(store).loadHistory();

        expect(
          encodeSolveHistory(history, BridgesLevel.values),
          '{"format":1,"solved":{}}',
        );
      }
    });

    test('records the first solve of each puzzle', () {
      final storage = BridgesStorage(MemoryLocalStore());

      storage
        ..recordSolve(BridgesLevel.normal, today, const Duration(seconds: 80))
        ..recordSolve(BridgesLevel.normal, today, const Duration(seconds: 20));
      final history = storage.recordSolve(
        BridgesLevel.hard,
        yesterday,
        const Duration(minutes: 7),
      );

      for (final read in [history, storage.loadHistory()]) {
        expect(
          read.solveTime(BridgesLevel.normal, today),
          const Duration(seconds: 80),
        );
        expect(
          read.solveTime(BridgesLevel.hard, yesterday),
          const Duration(minutes: 7),
        );
      }
    });

    test('keeps solves another tab recorded meanwhile', () {
      final store = MemoryLocalStore();
      final first = BridgesStorage(store);
      final second = BridgesStorage(store);

      first.recordSolve(BridgesLevel.normal, yesterday, Duration.zero);
      final history = second.recordSolve(
        BridgesLevel.hard,
        today,
        Duration.zero,
      );

      expect(history.solveTime(BridgesLevel.normal, yesterday), Duration.zero);
      expect(history.solveTime(BridgesLevel.hard, today), Duration.zero);
    });
  });

  group('removeGamesBefore', () {
    test('removes earlier games and records their solves', () {
      final store = MemoryLocalStore();
      final storage = BridgesStorage(store);
      final twoDaysAgo = DateTime(2026, 11, 10);
      storage
        ..saveGame(
          saveOf(
            BridgesLevel.normal,
            twoDaysAgo,
            playedTime: const Duration(seconds: 65),
            wasSolved: true,
          ),
        )
        ..saveGame(saveOf(BridgesLevel.hard, yesterday))
        ..saveGame(saveOf(BridgesLevel.normal, today))
        ..saveGame(saveOf(BridgesLevel.hard, DateTime(2026, 11, 13)));

      final history = storage.removeGamesBefore(today);

      expect(
        store.keys,
        unorderedEquals([
          'klura.bridges.normal.2026-11-12',
          'klura.bridges.hard.2026-11-13',
          BridgesStorage.historyKey,
        ]),
      );
      expect(history.solveTime(BridgesLevel.hard, yesterday), isNull);
      expect(
        storage.loadHistory().solveTime(BridgesLevel.normal, twoDaysAgo),
        const Duration(seconds: 65),
      );
    });

    test('keeps a solve already in the history', () {
      final storage = BridgesStorage(MemoryLocalStore())
        ..recordSolve(
          BridgesLevel.normal,
          yesterday,
          const Duration(minutes: 1),
        )
        ..saveGame(
          saveOf(
            BridgesLevel.normal,
            yesterday,
            playedTime: const Duration(minutes: 3),
            wasSolved: true,
          ),
        );

      final history = storage.removeGamesBefore(today);

      expect(
        history.solveTime(BridgesLevel.normal, yesterday),
        const Duration(minutes: 1),
      );
    });

    test('removes damaged earlier games and leaves other keys alone', () {
      final store = MemoryLocalStore({
        'klura.bridges.normal.2026-11-01': 'damaged',
        'klura.bridges.easy.2026-11-01': 'a level this version lacks',
        'klura.showTimer': 'false',
        'another-app': 'theirs',
      });

      BridgesStorage(store).removeGamesBefore(today);

      expect(
        store.keys,
        unorderedEquals([
          'klura.bridges.easy.2026-11-01',
          'klura.showTimer',
          'another-app',
        ]),
      );
    });
  });
}
