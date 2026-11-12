/// Counts the most pairs that can be formed between two groups, where each
/// item of the first group pairs with at most one item of the second and
/// the other way round.
///
/// [partners] lists, for each item of the first group, the indexes of the
/// items of the second group it may pair with; [secondCount] is the size of
/// the second group. It uses augmenting paths (Kuhn's algorithm), which is
/// plenty for the few dozen trees and tents of a board.
int countPairs(List<List<int>> partners, int secondCount) =>
    _largestPairing(partners, secondCount).where((first) => first != -1).length;

/// Finds the items of the first group that some largest pairing leaves
/// without a partner, in increasing order, with [partners] and
/// [secondCount] as for [countPairs].
///
/// The result is empty exactly when every item of the first group can have
/// a partner of its own. Otherwise its items have fewer partners between
/// them than their number, so at least one must go without, and any of
/// them could be that one. The result does not depend on which largest
/// pairing the search finds: from each item left over, it follows the
/// item's partners and the items paired with them, as far as that leads.
List<int> findUnpaired(List<List<int>> partners, int secondCount) {
  final pairOfSecond = _largestPairing(partners, secondCount);
  final reached = List.filled(partners.length, true);
  for (final first in pairOfSecond) {
    if (first != -1) {
      reached[first] = false;
    }
  }

  final pending = [
    for (final (first, isReached) in reached.indexed)
      if (isReached) first,
  ];
  final visited = List.filled(secondCount, false);
  while (pending.isNotEmpty) {
    for (final second in partners[pending.removeLast()]) {
      if (visited[second]) {
        continue;
      }
      visited[second] = true;
      // The pairing is the largest, so a partner reached this way is always
      // paired; otherwise the path to it would make one more pair.
      final next = pairOfSecond[second];
      if (!reached[next]) {
        reached[next] = true;
        pending.add(next);
      }
    }
  }
  return [
    for (final (first, isReached) in reached.indexed)
      if (isReached) first,
  ];
}

/// Pairs as many items as possible and returns, for each item of the second
/// group, the index of its partner in the first, or -1 if it has none.
List<int> _largestPairing(List<List<int>> partners, int secondCount) {
  final pairOfSecond = List.filled(secondCount, -1);
  for (var first = 0; first < partners.length; first++) {
    final visited = List.filled(secondCount, false);
    _augment(first, partners, pairOfSecond, visited);
  }
  return pairOfSecond;
}

/// Pairs [first] with a free item of the second group, moving earlier pairs
/// aside along an alternating path if needed. Returns whether it succeeded.
bool _augment(
  int first,
  List<List<int>> partners,
  List<int> pairOfSecond,
  List<bool> visited,
) {
  for (final second in partners[first]) {
    if (visited[second]) {
      continue;
    }
    visited[second] = true;
    final previous = pairOfSecond[second];
    if (previous == -1 || _augment(previous, partners, pairOfSecond, visited)) {
      pairOfSecond[second] = first;
      return true;
    }
  }
  return false;
}
