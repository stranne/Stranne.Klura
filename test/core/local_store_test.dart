import 'package:klura/core/local_store.dart';
import 'package:test/test.dart';

void main() {
  test('MemoryLocalStore reads, writes and removes values', () {
    final store = MemoryLocalStore({'a': '1'});

    store
      ..write('b', '2')
      ..write('a', '3');

    expect(store.read('a'), '3');
    expect(store.read('b'), '2');
    expect(store.read('c'), isNull);
    expect(store.keys, unorderedEquals(['a', 'b']));

    store.remove('a');

    expect(store.read('a'), isNull);
    expect(store.keys, ['b']);
  });

  test('MemoryLocalStore lists keys that later changes do not affect', () {
    final store = MemoryLocalStore({'a': '1', 'b': '2'});

    for (final key in store.keys) {
      store.remove(key);
    }

    expect(store.keys, isEmpty);
  });
}
