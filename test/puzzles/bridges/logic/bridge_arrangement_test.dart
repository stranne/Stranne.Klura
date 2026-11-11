import 'package:klura/puzzles/bridges/logic/bridge_arrangement.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';
import 'package:test/test.dart';

void main() {
  final top = Connection(const Position(0, 0), const Position(4, 0));
  final left = Connection(const Position(0, 0), const Position(0, 2));
  final across = Connection(const Position(0, 2), const Position(4, 2));
  final through = Connection(const Position(2, 0), const Position(2, 4));

  test('starts empty', () {
    const arrangement = BridgeArrangement.empty();

    expect(arrangement.isEmpty, isTrue);
    expect(arrangement[top], 0);
  });

  test('reports the bridges on each connection', () {
    final arrangement = BridgeArrangement({top: 2, left: 1});

    expect(arrangement[top], 2);
    expect(arrangement[left], 1);
    expect(arrangement[across], 0);
  });

  test('keeps its connections in order', () {
    final arrangement = BridgeArrangement({across: 1, left: 2, top: 1});

    expect(arrangement.connections, [top, left, across]);
  });

  test('changes bridges without modifying the original', () {
    final original = BridgeArrangement({top: 1});

    final added = original.withBridges(left, 2);
    final doubled = original.withBridges(top, 2);
    final removed = original.withBridges(top, 0);

    expect(original, BridgeArrangement({top: 1}));
    expect(added, BridgeArrangement({top: 1, left: 2}));
    expect(doubled, BridgeArrangement({top: 2}));
    expect(removed, const BridgeArrangement.empty());
  });

  test('equals an arrangement with the same bridges in any order', () {
    final first = BridgeArrangement({top: 1, left: 2});
    final second = BridgeArrangement({left: 2, top: 1});

    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(first, isNot(BridgeArrangement({top: 2, left: 2})));
  });

  test('rejects bridge counts other than one or two', () {
    expect(() => BridgeArrangement({top: 0}), throwsArgumentError);
    expect(() => BridgeArrangement({top: 3}), throwsArgumentError);
    expect(
      () => const BridgeArrangement.empty().withBridges(top, 3),
      throwsArgumentError,
    );
  });

  test('counts the bridges touching a position', () {
    final arrangement = BridgeArrangement({top: 2, left: 1, across: 1});

    expect(arrangement.bridgesTouching(const Position(0, 0)), 3);
    expect(arrangement.bridgesTouching(const Position(0, 2)), 2);
    expect(arrangement.bridgesTouching(const Position(2, 0)), 0);
  });

  test('finds the bridges a connection would cross', () {
    final arrangement = BridgeArrangement({top: 1, left: 1, across: 2});

    expect(arrangement.bridgesCrossing(through), [across]);
    expect(arrangement.bridgesCrossing(left), isEmpty);
  });
}
