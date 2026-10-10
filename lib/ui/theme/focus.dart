import 'package:flutter/material.dart';

import 'sefer_colors.dart';

/// Whether a control in [states] should show its keyboard focus ring: it has
/// focus and the user is navigating with a keyboard, not touch. Material
/// reports [WidgetState.focused] in touch mode too (an autofocused button,
/// say), where a ring would only be noise.
bool showsFocusRing(Set<WidgetState> states) =>
    states.contains(WidgetState.focused) && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

/// Keeps keyboard focus rings in step with the focus highlight mode: place it
/// in `MaterialApp.builder`.
///
/// Buttons, chips, segmented buttons and the FAB pick their shape with
/// [showsFocusRing] as they build, but Material rebuilds them only when their
/// own states change, and a switch between touch and keyboard is not one of
/// them. A button tabbed to would keep its ring after the page is scrolled by
/// touch, and one focused by touch would get none after a key press. So this
/// scope adds the mode to the theme ([FocusHighlight]); a change of mode is
/// then a change of theme, which rebuilds everything that reads it.
class FocusHighlightScope extends StatefulWidget {
  const FocusHighlightScope({super.key, required this.child});

  final Widget child;

  @override
  State<FocusHighlightScope> createState() => _FocusHighlightScopeState();
}

class _FocusHighlightScopeState extends State<FocusHighlightScope> {
  FocusHighlightMode _mode = FocusManager.instance.highlightMode;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_modeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_modeChanged);
    super.dispose();
  }

  void _modeChanged(FocusHighlightMode mode) {
    if (mode != _mode) setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlight = FocusHighlight(keyboard: _mode == FocusHighlightMode.traditional);
    return Theme(
      data: theme.copyWith(extensions: [...theme.extensions.values, highlight]),
      child: widget.child,
    );
  }
}

/// Whether keyboard focus is being shown, as [FocusHighlightScope] records it
/// in the theme.
@immutable
class FocusHighlight extends ThemeExtension<FocusHighlight> {
  const FocusHighlight({required this.keyboard});

  /// The user is navigating with a keyboard rather than by touch.
  final bool keyboard;

  @override
  FocusHighlight copyWith({bool? keyboard}) => FocusHighlight(keyboard: keyboard ?? this.keyboard);

  @override
  FocusHighlight lerp(FocusHighlight? other, double t) => t < 0.5 || other == null ? this : other;

  @override
  bool operator ==(Object other) => other is FocusHighlight && other.keyboard == keyboard;

  @override
  int get hashCode => keyboard.hashCode;
}

/// A rounded rectangle that also draws the keyboard focus ring
/// (docs/DESIGN_SYSTEM.md §6.1): a 2 px band of [gap] just outside the shape
/// (and outside its border, if that is drawn outside), then a 3 px [ring]
/// beyond it.
///
/// The ring sits on the surface around the control rather than on its fill,
/// so it shows just as well on a filled button as on a text button. Buttons
/// switch to this shape while focused; their `animationDuration` must be zero,
/// or Material's shape tween would blend it away.
class FocusRingBorder extends RoundedRectangleBorder {
  const FocusRingBorder({super.side, super.borderRadius, required this.ring, required this.gap});

  final Color ring;
  final Color gap;

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    super.paint(canvas, rect, textDirection: textDirection);
    final rrect = borderRadius.resolve(textDirection).toRRect(rect).inflate(side.strokeOutset);
    canvas
      ..drawRRect(
        rrect.inflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = gap,
      )
      ..drawRRect(
        rrect.inflate(3.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = ring,
      );
  }

  @override
  FocusRingBorder copyWith({BorderSide? side, BorderRadiusGeometry? borderRadius}) => FocusRingBorder(
        side: side ?? this.side,
        borderRadius: borderRadius ?? this.borderRadius,
        ring: ring,
        gap: gap,
      );

  @override
  FocusRingBorder scale(double t) =>
      FocusRingBorder(side: side.scale(t), borderRadius: borderRadius * t, ring: ring, gap: gap);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is RoundedRectangleBorder) {
      return FocusRingBorder(
        side: BorderSide.lerp(a.side, side, t),
        borderRadius: BorderRadiusGeometry.lerp(a.borderRadius, borderRadius, t)!,
        ring: a is FocusRingBorder ? Color.lerp(a.ring, ring, t)! : ring,
        gap: a is FocusRingBorder ? Color.lerp(a.gap, gap, t)! : gap,
      );
    }
    return _keepRing(super.lerpFrom(a, t));
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is RoundedRectangleBorder) {
      return FocusRingBorder(
        side: BorderSide.lerp(side, b.side, t),
        borderRadius: BorderRadiusGeometry.lerp(borderRadius, b.borderRadius, t)!,
        ring: b is FocusRingBorder ? Color.lerp(ring, b.ring, t)! : ring,
        gap: b is FocusRingBorder ? Color.lerp(gap, b.gap, t)! : gap,
      );
    }
    return _keepRing(super.lerpTo(b, t));
  }

  ShapeBorder? _keepRing(ShapeBorder? lerped) => lerped is RoundedRectangleBorder && lerped is! FocusRingBorder
      ? FocusRingBorder(side: lerped.side, borderRadius: lerped.borderRadius, ring: ring, gap: gap)
      : lerped;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is FocusRingBorder &&
      other.side == side &&
      other.borderRadius == borderRadius &&
      other.ring == ring &&
      other.gap == gap;

  @override
  int get hashCode => Object.hash(side, borderRadius, ring, gap);

  @override
  String toString() => 'FocusRingBorder($side, $borderRadius, ring: $ring, gap: $gap)';
}

/// An [InkWell] for cards, rows, week-strip days and map tiles
/// (docs/DESIGN_SYSTEM.md §6.1). While it has keyboard focus it draws a 3 px
/// ring in [SeferColors.focus] just outside its bounds, instead of tinting
/// its content.
///
/// The ring is painted outside the widget, so nothing between it and the
/// ink well's [Material] may clip; [borderRadius] should match the corners of
/// the shape it sits on.
class SeferInkWell extends StatefulWidget {
  const SeferInkWell({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
  });

  final Widget child;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final BorderRadius borderRadius;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;

  @override
  State<SeferInkWell> createState() => _SeferInkWellState();
}

class _SeferInkWellState extends State<SeferInkWell> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_highlightModeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_highlightModeChanged);
    super.dispose();
  }

  // A tap after tabbing switches to touch mode, which hides the ring; a key
  // press brings it back.
  void _highlightModeChanged(FocusHighlightMode mode) {
    if (_focused) setState(() {});
  }

  void _focusChanged(bool focused) {
    setState(() => _focused = focused);
    widget.onFocusChange?.call(focused);
  }

  @override
  Widget build(BuildContext context) {
    final showRing = _focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return DecoratedBox(
      // Always present, so that showing the ring never rebuilds the ink well
      // (and drops its focus).
      position: DecorationPosition.foreground,
      decoration: showRing
          ? ShapeDecoration(
              shape: RoundedRectangleBorder(
                borderRadius: widget.borderRadius,
                side: BorderSide(
                  color: SeferColors.of(context).focus,
                  width: 3,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
              ),
            )
          : const BoxDecoration(),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onFocusChange: _focusChanged,
        borderRadius: widget.borderRadius,
        // The ring marks focus; a tint as well would only muddy the content.
        focusColor: Colors.transparent,
        child: widget.child,
      ),
    );
  }
}

/// A slider's overlay: Material's translucent halo while it is hovered or
/// dragged, and the focus ring (§6.1) around its round thumb while it has
/// keyboard focus.
///
/// A slider shape is told the overlay colour but not the state, so the theme
/// resolves the focused overlay colour to exactly [ring]; every other state
/// is translucent and gets the halo.
class FocusRingSliderOverlay extends SliderComponentShape {
  const FocusRingSliderOverlay({required this.ring, required this.gap, this.thumbRadius = 10});

  final Color ring;
  final Color gap;

  /// The radius of the thumb the ring goes around.
  final double thumbRadius;

  static const _halo = RoundSliderOverlayShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => _halo.getPreferredSize(isEnabled, isDiscrete);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    if (sliderTheme.overlayColor != ring) {
      _halo.paint(
        context,
        center,
        activationAnimation: activationAnimation,
        enableAnimation: enableAnimation,
        isDiscrete: isDiscrete,
        labelPainter: labelPainter,
        parentBox: parentBox,
        sliderTheme: sliderTheme,
        textDirection: textDirection,
        value: value,
        textScaleFactor: textScaleFactor,
        sizeWithOverflow: sizeWithOverflow,
      );
      return;
    }
    // The same geometry as FocusRingBorder, and like it, no animation: the
    // ring is there the moment focus arrives.
    context.canvas
      ..drawCircle(
        center,
        thumbRadius + 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = gap,
      )
      ..drawCircle(
        center,
        thumbRadius + 3.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = ring,
      );
  }
}
