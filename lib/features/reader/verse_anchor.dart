import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Marks the verse the reader was opened at, from a search result, Go to
/// verse or a link (docs/DESIGN_SYSTEM.md §4.7): the whole verse, with its
/// Targum and translation, on the gold wash search marks matches with, and a
/// rule in gold ink at the edge where the verse begins, beside its number.
///
/// The mark is painted around [child], [bleed] past it on each side, so the
/// text doesn't move when the mark goes.
class TargetVerseMark extends StatelessWidget {
  const TargetVerseMark({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  /// How far the wash reaches past the text: within the reader's side
  /// padding, and the gap between verses.
  static const bleed = EdgeInsets.symmetric(horizontal: 8, vertical: 4);

  static const _radius = Radius.circular(8);

  /// The rule's width: as focus mode's, so it reads at a glance, and its
  /// shape tells the mark apart where the wash is close to the paper (the
  /// high-contrast themes).
  static const _rule = 3.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The same widgets with the mark or without, so that what [child] holds
    // (an ink splash, say) stays as the mark goes.
    return CustomPaint(
      painter: active ? _MarkPainter(wash: scheme.secondaryContainer, rule: scheme.secondary) : null,
      child: child,
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.wash, required this.rule});

  final Color wash;
  final Color rule;

  @override
  void paint(Canvas canvas, Size size) {
    final area = TargetVerseMark.bleed.inflateRect(Offset.zero & size);
    final shape = RRect.fromRectAndRadius(area, TargetVerseMark._radius);
    canvas.drawRRect(shape, Paint()..color = wash);
    // A verse begins on the right, as Hebrew does, in either language of the
    // app. The rule follows the wash's rounded corners.
    canvas
      ..save()
      ..clipRRect(shape)
      ..drawRect(
        Rect.fromLTRB(area.right - TargetVerseMark._rule, area.top, area.right, area.bottom),
        Paint()..color = rule,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.wash != wash || old.rule != rule;
}

/// Calls [onTap] when a pointer goes up close to where it went down, as a tap
/// does, without taking part in the gesture arena: the taps and scrolls of
/// what lies beneath work as before. A drag that scrolls is not a tap.
class TapObserver extends StatefulWidget {
  const TapObserver({super.key, required this.onTap, required this.child});

  /// Null to observe nothing.
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<TapObserver> createState() => _TapObserverState();
}

class _TapObserverState extends State<TapObserver> {
  final _down = <int, Offset>{};

  // Always a listener, whether or not there is anything to observe: were it
  // to come and go, what lies beneath would be built afresh, and a scroll
  // view would lose its place.
  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => _down[e.pointer] = e.position,
        onPointerCancel: (e) => _down.remove(e.pointer),
        onPointerUp: (e) {
          final start = _down.remove(e.pointer);
          final slop = computeHitSlop(e.kind, MediaQuery.maybeGestureSettingsOf(context));
          if (start != null && (e.position - start).distance <= slop) widget.onTap?.call();
        },
        child: widget.child,
      );
}
