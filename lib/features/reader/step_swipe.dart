import 'package:flutter/widgets.dart';

/// Swipes between a guided step's pages, as its Next and Back buttons do. A
/// swipe towards the next page goes on, and the other way goes back: towards
/// the left in a left-to-right text, and towards the right in Hebrew, where the
/// next page lies to the left.
class StepSwipe extends StatelessWidget {
  const StepSwipe({super.key, required this.child, required this.onNext, required this.onBack});

  final Widget child;
  final VoidCallback onNext;
  final VoidCallback onBack;

  /// The speed, in logical pixels a second, from which a drag is a swipe; a
  /// slower one is a scroll, or a selection.
  static const minVelocity = 300.0;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return GestureDetector(
      // Translucent: the whole step is swipeable, and the text in it still takes taps.
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < minVelocity) return;
        final towardsNext = rtl ? velocity > 0 : velocity < 0;
        if (towardsNext) {
          onNext();
        } else {
          onBack();
        }
      },
      child: child,
    );
  }
}
