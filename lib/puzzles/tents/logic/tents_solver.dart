import 'dart:typed_data';

import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/tents/logic/pairing.dart';
import 'package:klura/puzzles/tents/logic/tents_marks.dart';
import 'package:klura/puzzles/tents/logic/tents_puzzle.dart';
import 'package:klura/puzzles/tents/logic/tents_rules.dart';

/// Finds up to [limit] distinct sets of tents that solve [puzzle], each as
/// marks with tents only.
///
/// The search enforces every rule: the row and column numbers, no tents
/// touching and a tent of its own for each tree. It knows nothing of how the
/// puzzle was made. A [limit] of 2, the default, is enough to tell whether a
/// puzzle has exactly one solution.
///
/// The search is deterministic: the same puzzle always gives the same
/// solutions in the same order.
List<TentsMarks> solveTents(TentsPuzzle puzzle, {int limit = 2}) {
  if (limit < 1) {
    throw RangeError.range(limit, 1, null, 'limit');
  }
  return _Rules(puzzle).solve(limit);
}

/// How much reasoning a puzzle needs, from an empty board, to solve without
/// trial and error.
///
/// Each level includes the ones before it.
enum TentsReasoning {
  /// One rule at a time settles every cell: no tent away from the trees or
  /// beside another tent, rows and columns that are full or have just
  /// enough room, and a tree with a single free cell beside it.
  basic,

  /// Also needs to combine rules: how many tents fit in the free stretches
  /// of a row or column, and which tree each tent belongs to.
  advanced,

  /// Also needs lookahead: trying a tent or grass on one cell, following
  /// its consequences and finding that it breaks a rule.
  lookahead,

  /// Needs deeper trial and error, or the puzzle has no single solution.
  search,
}

/// How hard a puzzle is for a person, as measured by [gradeTents].
final class TentsGrade {
  const TentsGrade._({required this.reasoning, required this.openAfterBasic});

  /// The least reasoning that solves the puzzle.
  final TentsReasoning reasoning;

  /// How many cells that could hold a tent basic reasoning leaves open on
  /// an empty board: the choices a player has to think about rather than
  /// see at once.
  final int openAfterBasic;

  @override
  String toString() => 'TentsGrade(${reasoning.name}, $openAfterBasic open)';
}

/// Grades [puzzle] by the reasoning it needs and the choices it leaves open.
///
/// Any grade below [TentsReasoning.search] also proves that the puzzle has
/// exactly one solution, because every deduction holds for every solution.
TentsGrade gradeTents(TentsPuzzle puzzle) => _Rules(puzzle).grade();

/// A cell that may still hold a tent or not.
const int _open = 0;

/// A cell with a tent.
const int _tent = 1;

/// A cell that holds no tent: away from the trees, a tree itself, or ruled
/// out.
const int _empty = 2;

/// What is known about each cell, and which trees and tents are known to
/// belong together.
final class _State {
  _State(int cellCount, int treeCount, Iterable<int> candidates)
    : cells = Uint8List(cellCount)..fillRange(0, cellCount, _empty),
      pairOfTree = Int32List(treeCount)..fillRange(0, treeCount, -1),
      pairOfCell = Int32List(cellCount)..fillRange(0, cellCount, -1) {
    for (final cell in candidates) {
      cells[cell] = _open;
    }
  }

  _State.copy(_State other)
    : cells = Uint8List.fromList(other.cells),
      pairOfTree = Int32List.fromList(other.pairOfTree),
      pairOfCell = Int32List.fromList(other.pairOfCell),
      changes = other.changes;

  /// [_open], [_tent] or [_empty] for each cell, indexed by row, then by
  /// column.
  final Uint8List cells;

  /// The tent cell each tree is known to own, or -1.
  final Int32List pairOfTree;

  /// The tree each tent cell is known to belong to, or -1.
  final Int32List pairOfCell;

  /// Counts every change, so propagation can tell when it has settled.
  int changes = 0;

  void pair(int tree, int cell) {
    pairOfTree[tree] = cell;
    pairOfCell[cell] = tree;
    changes++;
  }
}

/// The rules of one puzzle, as constraints on which cells hold tents.
///
/// Cells are indexed by row, then by column, and trees like
/// [TentsPuzzle.trees]. Only cells beside a tree can ever hold a tent; they
/// are the candidates. Propagation applies the rules until nothing changes,
/// and the solver then branches on the most constrained open cell.
final class _Rules {
  factory _Rules(TentsPuzzle puzzle) {
    final width = puzzle.width;
    final height = puzzle.height;
    final cellCount = width * height;
    final treeIndexes = {
      for (final (index, tree) in puzzle.trees.indexed) tree: index,
    };
    final treesBeside = [
      for (var cell = 0; cell < cellCount; cell++)
        Int32List.fromList([
          if (!puzzle.hasTree(_positionOf(cell, width)))
            for (final tree in puzzle.treesBeside(_positionOf(cell, width)))
              treeIndexes[tree]!,
        ]),
    ];
    final candidates = [
      for (var cell = 0; cell < cellCount; cell++)
        if (treesBeside[cell].isNotEmpty) cell,
    ];
    final cellsBeside = [
      for (final tree in puzzle.trees)
        Int32List.fromList([
          for (final direction in Direction.values)
            if (tree.step(direction) case final cell
                when puzzle.canHoldTent(cell))
              cell.y * width + cell.x,
        ]),
    ];
    final around = [
      for (var cell = 0; cell < cellCount; cell++)
        Int32List.fromList([
          for (final other in candidates)
            if (_positionOf(cell, width).touches(_positionOf(other, width)))
              other,
        ]),
    ];

    return _Rules._(
      puzzle: puzzle,
      candidates: Int32List.fromList(candidates),
      treesBeside: treesBeside,
      cellsBeside: cellsBeside,
      around: around,
      lines: [
        for (var y = 0; y < height; y++)
          Int32List.fromList([for (var x = 0; x < width; x++) y * width + x]),
        for (var x = 0; x < width; x++)
          Int32List.fromList([for (var y = 0; y < height; y++) y * width + x]),
      ],
      lineTents: Int32List.fromList([
        ...puzzle.rowTents,
        ...puzzle.columnTents,
      ]),
    );
  }

  _Rules._({
    required this._puzzle,
    required this._candidates,
    required this._treesBeside,
    required this._cellsBeside,
    required this._around,
    required this._lines,
    required this._lineTents,
  });

  final TentsPuzzle _puzzle;

  /// The cells beside a tree, the only ones that can hold a tent.
  final Int32List _candidates;

  /// The trees directly beside each cell.
  final List<Int32List> _treesBeside;

  /// The candidate cells directly beside each tree.
  final List<Int32List> _cellsBeside;

  /// The candidate cells touching each cell, diagonals included.
  final List<Int32List> _around;

  /// The cells of each row from the top, then of each column from the left,
  /// in order along the line.
  final List<Int32List> _lines;

  /// The number of tents in each line of [_lines].
  final Int32List _lineTents;

  int get _width => _puzzle.width;

  /// Whether [line] in [_lines] is a row.
  bool _isRow(int line) => line < _puzzle.height;

  _State _initial() =>
      _State(_width * _puzzle.height, _puzzle.trees.length, _candidates);

  List<TentsMarks> solve(int limit) {
    final solutions = <TentsMarks>[];

    void search(_State state) {
      if (solutions.length >= limit ||
          !_propagate(state, advanced: true) ||
          !_canPair(state)) {
        return;
      }
      final cell = _branchCell(state);
      if (cell == -1) {
        final marks = _marksOf(state);
        if (checkTents(_puzzle, marks).isSolved) {
          solutions.add(marks);
        }
        return;
      }
      final withTent = _State.copy(state);
      if (_placeTent(withTent, cell)) {
        search(withTent);
      }
      if (_clear(state, cell)) {
        search(state);
      }
    }

    search(_initial());
    return solutions;
  }

  TentsGrade grade() {
    final state = _initial();
    if (!_propagate(state, advanced: false)) {
      return const TentsGrade._(
        reasoning: TentsReasoning.search,
        openAfterBasic: 0,
      );
    }
    final openAfterBasic = _openCount(state);

    TentsGrade graded(TentsReasoning reasoning) => TentsGrade._(
      reasoning: _openCount(state) == 0 && _isSolution(state)
          ? reasoning
          : TentsReasoning.search,
      openAfterBasic: openAfterBasic,
    );

    if (openAfterBasic == 0) {
      return graded(TentsReasoning.basic);
    }
    if (!_propagate(state, advanced: true)) {
      return graded(TentsReasoning.search);
    }
    if (_openCount(state) == 0) {
      return graded(TentsReasoning.advanced);
    }
    if (!_lookahead(state)) {
      return graded(TentsReasoning.search);
    }
    return graded(TentsReasoning.lookahead);
  }

  /// Tries a tent and grass on each open cell in turn, settling every cell
  /// where one of them breaks a rule. Returns `false` if both do.
  bool _lookahead(_State state) {
    var progress = true;
    while (progress && _openCount(state) > 0) {
      progress = false;
      for (final cell in _candidates) {
        if (state.cells[cell] != _open) {
          continue;
        }
        final withTent = _State.copy(state);
        if (!_placeTent(withTent, cell) ||
            !_propagate(withTent, advanced: true)) {
          if (!_clear(state, cell) || !_propagate(state, advanced: true)) {
            return false;
          }
          progress = true;
          continue;
        }
        final withoutTent = _State.copy(state);
        if (!_clear(withoutTent, cell) ||
            !_propagate(withoutTent, advanced: true)) {
          if (!_placeTent(state, cell) || !_propagate(state, advanced: true)) {
            return false;
          }
          progress = true;
        }
      }
    }
    return true;
  }

  /// Applies the rules until nothing changes: the basic ones, and with
  /// [advanced] also those that combine rules. Returns `false` if a rule is
  /// broken, which means no solution follows from [state].
  bool _propagate(_State state, {required bool advanced}) {
    var before = -1;
    while (before != state.changes) {
      before = state.changes;
      for (var line = 0; line < _lines.length; line++) {
        if (!_applyLine(state, line, advanced: advanced)) {
          return false;
        }
      }
      for (var tree = 0; tree < _cellsBeside.length; tree++) {
        if (!_applyLonelyTree(state, tree)) {
          return false;
        }
      }
      if (advanced && !_applyPairing(state)) {
        return false;
      }
    }
    return true;
  }

  /// A line with all its tents has no more; a line with just enough open
  /// cells has a tent on each. With [advanced], also counts how many tents
  /// fit in each stretch of open cells.
  bool _applyLine(_State state, int line, {required bool advanced}) {
    final cells = _lines[line];
    var tents = 0;
    var open = 0;
    for (final cell in cells) {
      switch (state.cells[cell]) {
        case _tent:
          tents++;
        case _open:
          open++;
      }
    }
    final needed = _lineTents[line] - tents;
    if (needed < 0 || needed > open) {
      return false;
    }
    if (open == 0) {
      return true;
    }
    if (needed == 0 || needed == open) {
      for (final cell in cells) {
        if (state.cells[cell] == _open &&
            !(needed == 0 ? _clear(state, cell) : _placeTent(state, cell))) {
          return false;
        }
      }
      return true;
    }
    return !advanced || _applyStretches(state, line, needed);
  }

  /// Tents never touch, so a stretch of n open cells in a line holds at
  /// most (n + 1) / 2 of them. When the stretches can hold no more than the
  /// line needs, each holds that many: an odd stretch then has a tent on
  /// every other cell from its ends, and a stretch of two has one tent,
  /// which rules out the cells beside both of its cells in the next lines.
  bool _applyStretches(_State state, int line, int needed) {
    final cells = _lines[line];
    final stretches = <(int, int)>[];
    var room = 0;
    var start = 0;
    for (var index = 0; index <= cells.length; index++) {
      if (index < cells.length && state.cells[cells[index]] == _open) {
        continue;
      }
      final length = index - start;
      if (length > 0) {
        stretches.add((start, length));
        room += (length + 1) ~/ 2;
      }
      start = index + 1;
    }
    if (room < needed) {
      return false;
    }
    if (room > needed) {
      return true;
    }
    for (final (start, length) in stretches) {
      if (length.isOdd) {
        for (var offset = 0; offset < length; offset++) {
          final cell = cells[start + offset];
          if (!(offset.isEven
              ? _placeTent(state, cell)
              : _clear(state, cell))) {
            return false;
          }
        }
      } else if (length == 2) {
        for (final cell in _besideBoth(line, cells[start], cells[start + 1])) {
          if (!_clear(state, cell)) {
            return false;
          }
        }
      }
    }
    return true;
  }

  /// The cells in the lines on either side of [line] that touch both
  /// [first] and [second], which lie next to each other in [line].
  Iterable<int> _besideBoth(int line, int first, int second) sync* {
    final steps = _isRow(line)
        ? const [Direction.up, Direction.down]
        : const [Direction.left, Direction.right];
    for (final direction in steps) {
      for (final cell in [first, second]) {
        final beside = _positionOf(cell, _width).step(direction);
        if (_puzzle.contains(beside)) {
          yield beside.y * _width + beside.x;
        }
      }
    }
  }

  /// A tree without a tent beside it needs one on a free cell beside it, so
  /// a single free cell must hold it.
  bool _applyLonelyTree(_State state, int tree) {
    var open = -1;
    var openCount = 0;
    for (final cell in _cellsBeside[tree]) {
      switch (state.cells[cell]) {
        case _tent:
          return true;
        case _open:
          open = cell;
          openCount++;
      }
    }
    return switch (openCount) {
      0 => false,
      1 => _placeTent(state, open),
      _ => true,
    };
  }

  /// Works out which trees and tents belong together:
  ///
  /// - a tent with a single tree beside it that has no other tent belongs
  ///   to that tree;
  /// - a tree with a single cell beside it that could still be its tent
  ///   gets that tent;
  /// - an open cell whose trees all have their tents holds none.
  bool _applyPairing(_State state) {
    for (final cell in _candidates) {
      if (state.cells[cell] != _tent || state.pairOfCell[cell] != -1) {
        continue;
      }
      var free = -1;
      var freeCount = 0;
      for (final tree in _treesBeside[cell]) {
        if (state.pairOfTree[tree] == -1) {
          free = tree;
          freeCount++;
        }
      }
      if (freeCount == 0) {
        return false;
      }
      if (freeCount == 1) {
        state.pair(free, cell);
      }
    }

    for (var tree = 0; tree < _cellsBeside.length; tree++) {
      if (state.pairOfTree[tree] != -1) {
        continue;
      }
      var option = -1;
      var optionCount = 0;
      for (final cell in _cellsBeside[tree]) {
        final value = state.cells[cell];
        if (value == _open ||
            (value == _tent && state.pairOfCell[cell] == -1)) {
          option = cell;
          optionCount++;
        }
      }
      if (optionCount == 0) {
        return false;
      }
      if (optionCount == 1) {
        if (!_placeTent(state, option)) {
          return false;
        }
        state.pair(tree, option);
      }
    }

    for (final cell in _candidates) {
      if (state.cells[cell] == _open &&
          _treesBeside[cell].every((tree) => state.pairOfTree[tree] != -1) &&
          !_clear(state, cell)) {
        return false;
      }
    }
    return true;
  }

  /// Puts a tent on [cell] and rules out the cells touching it. Returns
  /// `false` if [cell] holds no tent or touches one.
  bool _placeTent(_State state, int cell) {
    switch (state.cells[cell]) {
      case _tent:
        return true;
      case _empty:
        return false;
    }
    state
      ..cells[cell] = _tent
      ..changes += 1;
    for (final other in _around[cell]) {
      if (state.cells[other] == _tent) {
        return false;
      }
      state.cells[other] = _empty;
    }
    return true;
  }

  /// Rules out a tent on [cell]. Returns `false` if it has one.
  bool _clear(_State state, int cell) {
    switch (state.cells[cell]) {
      case _empty:
        return true;
      case _tent:
        return false;
    }
    state
      ..cells[cell] = _empty
      ..changes += 1;
    return true;
  }

  /// Whether the trees can still each have a tent of their own among the
  /// tents and open cells, and the tents each a tree of their own.
  bool _canPair(_State state) {
    final cellsOfTree = [
      for (final cells in _cellsBeside)
        [
          for (final cell in cells)
            if (state.cells[cell] != _empty) cell,
        ],
    ];
    if (countPairs(cellsOfTree, state.cells.length) < cellsOfTree.length) {
      return false;
    }
    final treesOfTent = [
      for (final cell in _candidates)
        if (state.cells[cell] == _tent) _treesBeside[cell].toList(),
    ];
    return countPairs(treesOfTent, _cellsBeside.length) == treesOfTent.length;
  }

  /// The open cell to branch on: one beside the tree with the fewest open
  /// cells, or -1 if no cell is open.
  int _branchCell(_State state) {
    var best = -1;
    var bestCount = 0;
    for (var tree = 0; tree < _cellsBeside.length; tree++) {
      if (state.pairOfTree[tree] != -1) {
        continue;
      }
      var first = -1;
      var count = 0;
      for (final cell in _cellsBeside[tree]) {
        if (state.cells[cell] == _open) {
          first = first == -1 ? cell : first;
          count++;
        }
      }
      if (count > 0 && (best == -1 || count < bestCount)) {
        best = first;
        bestCount = count;
      }
    }
    if (best != -1) {
      return best;
    }
    for (final cell in _candidates) {
      if (state.cells[cell] == _open) {
        return cell;
      }
    }
    return -1;
  }

  int _openCount(_State state) {
    var count = 0;
    for (final cell in _candidates) {
      if (state.cells[cell] == _open) {
        count++;
      }
    }
    return count;
  }

  bool _isSolution(_State state) =>
      checkTents(_puzzle, _marksOf(state)).isSolved;

  TentsMarks _marksOf(_State state) => TentsMarks({
    for (final cell in _candidates)
      if (state.cells[cell] == _tent) _positionOf(cell, _width): TentsMark.tent,
  });
}

Position _positionOf(int cell, int width) =>
    Position(cell % width, cell ~/ width);
