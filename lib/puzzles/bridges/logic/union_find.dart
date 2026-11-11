import 'dart:typed_data';

/// Disjoint groups of the items `0` to `count - 1`, for tracking which
/// islands bridges link.
final class UnionFind {
  UnionFind(int count)
    : _parents = Int32List.fromList(List.generate(count, (item) => item)),
      _groupCount = count;

  final Int32List _parents;
  int _groupCount;

  /// The number of separate groups.
  int get groupCount => _groupCount;

  /// The representative item of the group containing [item].
  int find(int item) {
    var current = item;
    while (_parents[current] != current) {
      final grandparent = _parents[_parents[current]];
      _parents[current] = grandparent;
      current = grandparent;
    }
    return current;
  }

  /// Joins the groups of [first] and [second]. Returns `false` if they were
  /// already in one group.
  bool union(int first, int second) {
    final firstRoot = find(first);
    final secondRoot = find(second);
    if (firstRoot == secondRoot) {
      return false;
    }
    _parents[secondRoot] = firstRoot;
    _groupCount--;
    return true;
  }

  /// Whether [first] and [second] are in one group.
  bool connects(int first, int second) => find(first) == find(second);
}
