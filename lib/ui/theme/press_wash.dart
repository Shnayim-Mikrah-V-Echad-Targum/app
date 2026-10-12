import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';

/// The press feedback where ink doesn't spread (docs/DESIGN_SYSTEM.md §8):
/// on Apple platforms, as their controls darken while pressed, and wherever
/// motion is reduced. A wash of the ink well's splash colour (a control's
/// pressed overlay, 10% of its ink; ThemeData.splashColor elsewhere) fills
/// its whole shape at once, as the finger lands, and doesn't grow.
///
/// A quick tap in a scroll view is pressed and released in one frame, before
/// the ink well's highlight has faded in, so the wash holds for a few frames
/// after the press ends and then fades over [Motion.short]; with [reduced]
/// motion it holds a little longer and then goes at once.
class PressWash extends InteractiveInkFeatureFactory {
  const PressWash({this.reduced = false});

  /// Whether motion is reduced: the wash goes without fading.
  final bool reduced;

  /// How long the wash stays at its full strength once the press ends.
  static const hold = Duration(milliseconds: 50);

  /// How long it stays, with motion reduced, before it goes at once.
  static const reducedHold = Duration(milliseconds: 100);

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) =>
      _PressWashFeature(
        controller: controller,
        referenceBox: referenceBox,
        color: color,
        textDirection: textDirection,
        containedInkWell: containedInkWell,
        rectCallback: rectCallback,
        borderRadius: borderRadius ?? BorderRadius.zero,
        customBorder: customBorder,
        radius: radius,
        onRemoved: onRemoved,
        reduced: reduced,
      );
}

class _PressWashFeature extends InteractiveInkFeature {
  _PressWashFeature({
    required MaterialInkController controller,
    required super.referenceBox,
    required super.color,
    required this.textDirection,
    required bool containedInkWell,
    required RectCallback? rectCallback,
    required this.borderRadius,
    required super.customBorder,
    required this.radius,
    required super.onRemoved,
    required bool reduced,
  })  : // Within the ink well, its shape; otherwise (an icon button's
        // InkResponse) a circle about its middle, as its highlight is.
        _clip = rectCallback ?? (containedInkWell ? () => Offset.zero & referenceBox.size : null),
        super(controller: controller) {
    if (!reduced) {
      // Full strength through the hold, then fading out.
      final total = PressWash.hold + Motion.short;
      final fade = AnimationController(duration: total, vsync: controller.vsync)
        ..addListener(controller.markNeedsPaint)
        ..addStatusListener((status) {
          if (status.isCompleted) dispose();
        });
      _fade = fade;
      _strength = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(
        parent: fade,
        curve: Interval(PressWash.hold.inMicroseconds / total.inMicroseconds, 1, curve: Curves.easeOut),
      ));
    }
    controller.addInkFeature(this);
  }

  final TextDirection textDirection;
  final BorderRadius borderRadius;

  /// The circle's radius, outside an ink well's shape.
  final double? radius;

  final RectCallback? _clip;

  /// The fade, where motion isn't reduced.
  AnimationController? _fade;
  Animation<double> _strength = const AlwaysStoppedAnimation(1);

  /// With motion reduced, the hold at full strength, after which the wash
  /// goes at once: a timer, as nothing moves.
  Timer? _hold;

  @override
  void confirm() => _end();

  @override
  void cancel() => _end();

  void _end() {
    final fade = _fade;
    if (fade == null) {
      _hold ??= Timer(PressWash.reducedHold, dispose);
    } else if (!fade.isAnimating && !fade.isCompleted) {
      fade.forward();
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    _fade?.dispose();
    super.dispose();
  }

  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    final strength = _strength.value;
    if (strength <= 0) return;
    final paint = Paint()..color = color.withValues(alpha: color.a * strength);
    final clip = _clip;
    final Offset center;
    final double circle;
    if (clip != null) {
      // A circle over the whole of the shape, which the shape clips.
      final rect = clip();
      center = rect.center;
      circle = math.sqrt(rect.width * rect.width + rect.height * rect.height) / 2;
    } else {
      center = referenceBox.size.center(Offset.zero);
      circle = radius ?? Material.defaultSplashRadius;
    }
    paintInkCircle(
      canvas: canvas,
      transform: transform,
      paint: paint,
      center: center,
      radius: circle,
      textDirection: textDirection,
      customBorder: customBorder,
      borderRadius: borderRadius,
      clipCallback: clip,
    );
  }
}
