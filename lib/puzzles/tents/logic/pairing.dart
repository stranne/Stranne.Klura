/// Counts the most pairs that can be formed between two groups, where each
/// item of the first group pairs with at most one item of the second and
/// the other way round.
///
/// [partners] lists, for each item of the first group, the indexes of the
/// items of the second group it may pair with; [secondCount] is the size of
/// the second group. It uses augmenting paths (Kuhn's algorithm), which is
/// plenty for the few dozen trees and tents of a board.
int countPairs(List<List<int>> partners, int secondCount) {
  final pairOfSecond = List.filled(secondCount, -1);
  var pairs = 0;
  for (var first = 0; first < partners.length; first++) {
    final visited = List.filled(secondCount, false);
    if (_augment(first, partners, pairOfSecond, visited)) {
      pairs++;
    }
  }
  return pairs;
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
