import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// The layout of a guided step that fills the page on a large screen
// (docs/DESIGN_SYSTEM.md §9, Reader, guided): the step's verse among its
// neighbours, as many of them as fit whole.
//
// The page's height comes down as a minimum height: ColumnToPage gives its
// last child what its other children leave of it, and FitsWhole fills that
// with the neighbours that fit, so that they never make the step scroll.

/// A column of [children], each as wide as the column, whose last child is
/// at least as tall as the room the others leave of the column's minimum
/// height: the page's height, passed down to what fills it.
class ColumnToPage extends MultiChildRenderObjectWidget {
  const ColumnToPage({super.key, required super.children});

  @override
  RenderColumnToPage createRenderObject(BuildContext context) => RenderColumnToPage();
}

class _PageParentData extends ContainerBoxParentData<RenderBox> {}

class RenderColumnToPage extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _PageParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _PageParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PageParentData) child.parentData = _PageParentData();
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    assert(width.isFinite, 'A ColumnToPage needs a bounded width.');
    var y = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final room = child == lastChild ? math.max(0.0, constraints.minHeight - y) : 0.0;
      child.layout(BoxConstraints(minWidth: width, maxWidth: width, minHeight: room), parentUsesSize: true);
      (child.parentData! as _PageParentData).offset = Offset(0, y);
      y += child.size.height;
    }
    size = constraints.constrain(Size(width, y));
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// A step's [lead] (its title), then its [main] text, with what it can
/// hold of its neighbours on the page, its minimum height: [before], above
/// [main], [beforeGap] from it, where [main] still fits whole beneath it;
/// then as many of [after], in order, as fit whole beneath [main],
/// [firstGap] after it and [gap] after each other. A neighbour that doesn't
/// fit is left out, and every one after it: none is ever cut off at the
/// page's foot, nor makes the page scroll. Each child is as wide as the
/// whole.
///
/// What is left out is neither painted, hit nor heard.
class FitsWhole extends MultiChildRenderObjectWidget {
  FitsWhole({
    super.key,
    required Widget lead,
    Widget? before,
    required Widget main,
    List<Widget> after = const [],
    this.beforeGap = 0,
    this.firstGap = 0,
    this.gap = 0,
  })  : hasBefore = before != null,
        super(children: [lead, ?before, main, ...after]);

  final bool hasBefore;
  final double beforeGap;
  final double firstGap;
  final double gap;

  @override
  RenderFitsWhole createRenderObject(BuildContext context) => RenderFitsWhole(hasBefore, beforeGap, firstGap, gap);

  @override
  void updateRenderObject(BuildContext context, RenderFitsWhole renderObject) => renderObject
    ..hasBefore = hasBefore
    ..beforeGap = beforeGap
    ..firstGap = firstGap
    ..gap = gap;
}

class RenderFitsWhole extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _PageParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _PageParentData> {
  RenderFitsWhole(this._hasBefore, this._beforeGap, this._firstGap, this._gap);

  bool get hasBefore => _hasBefore;
  bool _hasBefore;
  set hasBefore(bool value) {
    if (value == _hasBefore) return;
    _hasBefore = value;
    markNeedsLayout();
  }

  double get beforeGap => _beforeGap;
  double _beforeGap;
  set beforeGap(double value) {
    if (value == _beforeGap) return;
    _beforeGap = value;
    markNeedsLayout();
  }

  double get firstGap => _firstGap;
  double _firstGap;
  set firstGap(double value) {
    if (value == _firstGap) return;
    _firstGap = value;
    markNeedsLayout();
  }

  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  /// The children shown, in order: those laid out within the page.
  List<RenderBox> get shown => List.unmodifiable(_shown);
  final _shown = <RenderBox>[];

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PageParentData) child.parentData = _PageParentData();
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    assert(width.isFinite, 'A FitsWhole needs a bounded width.');
    final page = constraints.minHeight;
    // Every child is laid out, so that each has a size, shown or not.
    final children = getChildrenAsList();
    for (final child in children) {
      child.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
    }
    final lead = children.first;
    final before = hasBefore ? children[1] : null;
    final main = children[hasBefore ? 2 : 1];
    final after = children.skip(hasBefore ? 3 : 2);
    // A hair's tolerance, for heights that add up to the page's.
    bool fits(double bottom) => bottom <= page + 0.01;

    _shown
      ..clear()
      ..add(lead);
    var y = lead.size.height;
    if (before != null && fits(y + before.size.height + beforeGap + main.size.height)) {
      _place(before, y);
      y += before.size.height + beforeGap;
    }
    _place(main, y);
    y += main.size.height;
    var next = firstGap;
    for (final child in after) {
      if (!fits(y + next + child.size.height)) break;
      _place(child, y + next);
      y += next + child.size.height;
      next = gap;
    }
    (lead.parentData! as _PageParentData).offset = Offset.zero;
    size = constraints.constrain(Size(width, y));
    // What is left out waits below the page, out of the way.
    for (final child in children) {
      if (!_shown.contains(child)) (child.parentData! as _PageParentData).offset = Offset(0, size.height);
    }
  }

  void _place(RenderBox child, double y) {
    (child.parentData! as _PageParentData).offset = Offset(0, y);
    _shown.add(child);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => firstChild?.getDistanceToActualBaseline(baseline);

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in _shown) {
      context.paintChild(child, offset + (child.parentData! as _PageParentData).offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in _shown.reversed) {
      final hit = result.addWithPaintOffset(
        offset: (child.parentData! as _PageParentData).offset,
        position: position,
        hitTest: (result, transformed) => child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) => _shown.forEach(visitor);
}
