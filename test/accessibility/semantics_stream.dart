import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// The semantics updates the app sends the platform, applied to a tree as
/// the desktop engines' accessibility bridge applies them.
///
/// On Windows (and macOS and Linux) the engine keeps a tree of its own
/// (Chromium's ui::AXTree), each node holding its children in traversal
/// order, and applies each update to it. A node an update sends that no
/// parent then holds, and that isn't the root, can't go in: the bridge logs
/// "Failed to update ui::AXTree, error: N will not be in the tree and is not
/// the new root", and from then on the screen reader's tree goes stale, each
/// later update failing on a node that is left (the PC test of build #49,
/// from the first time the display sheet opened). A node moved from one
/// parent to another the bridge takes in two steps, first out of the old
/// parent and then into the new one, and a screen reader may lose its place
/// on it meanwhile: [moves] lists those.
///
/// Use it from a test file whose `main` first calls
/// [SemanticsStreamBinding.ensureInitialized], and [SemanticsStream.start]
/// once semantics are on (`tester.ensureSemantics()`).
class SemanticsStream {
  SemanticsStream._();

  static SemanticsStream? _current;

  /// Starts applying the updates sent from now on to a tree of its own,
  /// which begins empty, as the platform's does when semantics are turned
  /// on.
  static SemanticsStream start() {
    final stream = SemanticsStream._();
    _current = stream;
    addTearDown(() {
      if (identical(_current, stream)) _current = null;
    });
    return stream;
  }

  /// The tree as the platform holds it: each node's children, by id.
  final _children = <int, List<int>>{};

  /// What the platform's tree couldn't take, in the order it happened: each
  /// says what went wrong, and in which update (counted from 1).
  final problems = <String>[];

  /// The nodes an update gave another parent than the one they had, in the
  /// order it happened.
  final moves = <String>[];

  /// How many updates have been received.
  int updates = 0;

  void _receive(List<(int, List<int>)> nodes) {
    updates++;
    final parents = {
      for (final MapEntry(key: id, value: children) in _children.entries)
        for (final child in children) child: id,
    };
    for (final (id, children) in nodes) {
      for (final child in children) {
        if (parents[child] case final from? when from != id) {
          moves.add('update $updates: node $child moves from parent $from to $id');
        }
      }
    }
    final next = {..._children};
    for (final (id, children) in nodes) {
      next[id] = children;
    }
    // What the update leaves in the tree: the nodes reachable from the root.
    final reached = <int>{};
    void visit(int id) {
      if (!reached.add(id)) return;
      next[id]?.forEach(visit);
    }

    if (next.containsKey(0)) visit(0);
    for (final (id, _) in nodes) {
      if (id != 0 && !reached.contains(id)) {
        problems.add('update $updates: node $id will not be in the tree and is not the new root');
      }
    }
    for (final id in reached) {
      if (!next.containsKey(id)) problems.add('update $updates: node $id is a child, but was never sent');
    }
    _children
      ..clear()
      ..addAll({for (final id in reached) id: ?next[id]});
  }
}

/// The test binding, whose semantics updates [SemanticsStream] hears as they
/// are built.
class SemanticsStreamBinding extends AutomatedTestWidgetsFlutterBinding {
  static SemanticsStreamBinding? _instance;

  /// Makes this the test binding. Call it first in `main`, before any test
  /// runs, so that no other binding is made in its place.
  static SemanticsStreamBinding ensureInitialized() => _instance ??= SemanticsStreamBinding();

  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() => _RecordingBuilder(super.createSemanticsUpdateBuilder());
}

/// Records each node an update holds, with its children in traversal order,
/// and builds the update as [_inner] does.
class _RecordingBuilder implements ui.SemanticsUpdateBuilder {
  _RecordingBuilder(this._inner);

  final ui.SemanticsUpdateBuilder _inner;
  final _nodes = <(int, List<int>)>[];

  @override
  Object? noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #updateNode:
        final args = invocation.namedArguments;
        _nodes.add((args[#id]! as int, List<int>.of(args[#childrenInTraversalOrder]! as Int32List)));
        return Function.apply(_inner.updateNode, const [], args);
      case #updateCustomAction:
        return Function.apply(_inner.updateCustomAction, const [], invocation.namedArguments);
      case #build:
        SemanticsStream._current?._receive(_nodes);
        return _inner.build();
    }
    return super.noSuchMethod(invocation);
  }
}
