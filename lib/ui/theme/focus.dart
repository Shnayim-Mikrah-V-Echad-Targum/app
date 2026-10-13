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
///
/// Only the ink well's own focus is ringed: a control inside it, such as a
/// paper row's trailing menu button, shows just its own ring when it takes
/// focus, not a second one around the whole row.
class SeferInkWell extends StatefulWidget {
  const SeferInkWell({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.longPressFeedback = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
  });

  final Widget child;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;

  /// Whether a long press gives the platform's feedback (on Android, its
  /// long-press pulse). False where [onLongPress] gives its own, as one
  /// that keeps to the reader's Haptic feedback does; a tap still clicks.
  final bool longPressFeedback;
  final BorderRadius borderRadius;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;

  @override
  State<SeferInkWell> createState() => _SeferInkWellState();
}

class _SeferInkWellState extends State<SeferInkWell> {
  FocusNode? _ownFocusNode;
  bool _focused = false;

  /// The ink well's node: the caller's, or one of its own, so that its own
  /// focus can be told apart from a descendant's.
  FocusNode get _focusNode => widget.focusNode ?? (_ownFocusNode ??= FocusNode(debugLabel: 'SeferInkWell'));

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_highlightModeChanged);
  }

  @override
  void didUpdateWidget(SeferInkWell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != null && _ownFocusNode != null) {
      // The caller's node takes over once the ink well has moved to it.
      final own = _ownFocusNode!;
      _ownFocusNode = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => own.dispose());
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_highlightModeChanged);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  // A tap after tabbing switches to touch mode, which hides the ring; a key
  // press brings it back.
  void _highlightModeChanged(FocusHighlightMode mode) {
    if (_focused) setState(() {});
  }

  // Called when focus enters or leaves the ink well or anything inside it,
  // and whenever it moves between the two.
  void _focusChanged(bool hasFocus) {
    final focused = hasFocus && _focusNode.hasPrimaryFocus;
    if (focused != _focused) setState(() => _focused = focused);
    widget.onFocusChange?.call(hasFocus);
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
        onTap: switch (widget.onTap) {
          final onTap? when !widget.longPressFeedback => () {
              Feedback.forTap(context);
              onTap();
            },
          final onTap => onTap,
        },
        onLongPress: widget.onLongPress,
        enableFeedback: widget.longPressFeedback,
        focusNode: _focusNode,
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

/// Rebuilds a focus ring as the user switches between keyboard and touch,
/// which changes no focus. The rings ask the focus manager for the mode
/// rather than reading [FocusHighlight], as a popup menu keeps the theme it
/// was opened with.
mixin _KeyboardHighlight<T extends StatefulWidget> on State<T> {
  /// Whether keyboard focus is being shown.
  bool get keyboardHighlight => FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  /// Whether the ring would show in keyboard mode, and so must be rebuilt
  /// when the mode changes.
  bool get ringFocused;

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

  void _highlightModeChanged(FocusHighlightMode mode) {
    if (ringFocused) setState(() {});
  }
}

/// The keyboard focus ring (§6.1) of a navigation bar or rail destination,
/// around its indicator: the destination's icon and selected icon go in it.
///
/// While the destination has keyboard focus, it paints [FocusRingBorder]'s
/// gap and ring around a rounded rectangle of the [indicator]'s size and
/// [radius], centred on the icon as the indicator is, whether or not the
/// indicator shows. Material marks the focus only with a wash over the
/// indicator, too faint to see, and in the light themes darker than the
/// selected indicator; the ring reads as focus, never as selection.
///
/// The ring reaches 5 px past the indicator, so nothing between the icon and
/// the bar may clip it.
class IndicatorFocusRing extends StatefulWidget {
  const IndicatorFocusRing({super.key, required this.child, required this.indicator, required this.radius});

  final Widget child;

  /// The size of the indicator that the ring goes around.
  final Size indicator;

  /// The indicator's corner radius.
  final double radius;

  @override
  State<IndicatorFocusRing> createState() => _IndicatorFocusRingState();
}

class _IndicatorFocusRingState extends State<IndicatorFocusRing> with _KeyboardHighlight {
  // The destination's ink well is the nearest focus node above its icon.
  bool _destinationFocused({bool createDependency = true}) =>
      Focus.maybeOf(context, createDependency: createDependency)?.hasPrimaryFocus ?? false;

  @override
  bool get ringFocused => _destinationFocused(createDependency: false);

  @override
  Widget build(BuildContext context) {
    final sefer = SeferColors.of(context);
    return CustomPaint(
      // Only the painter changes, so showing the ring never rebuilds the icon.
      foregroundPainter: _destinationFocused() && keyboardHighlight
          ? _IndicatorRingPainter(
              indicator: widget.indicator,
              radius: widget.radius,
              ring: sefer.focus,
              gap: sefer.focusGap,
            )
          : null,
      child: widget.child,
    );
  }
}

class _IndicatorRingPainter extends CustomPainter {
  const _IndicatorRingPainter({required this.indicator, required this.radius, required this.ring, required this.gap});

  final Size indicator;
  final double radius;
  final Color ring;
  final Color gap;

  @override
  void paint(Canvas canvas, Size size) {
    // FocusRingBorder's own gap and ring, as every other control draws them.
    FocusRingBorder(borderRadius: BorderRadius.all(Radius.circular(radius)), ring: ring, gap: gap).paint(
      canvas,
      Rect.fromCenter(center: size.center(Offset.zero), width: indicator.width, height: indicator.height),
    );
  }

  @override
  bool shouldRepaint(_IndicatorRingPainter old) =>
      old.indicator != indicator || old.radius != radius || old.ring != ring || old.gap != gap;
}

/// A popup menu item's content, laid out as Material lays it out (12 in from
/// the start, centred in 48 at least), which draws the keyboard focus ring
/// (§6.1) while the item has keyboard focus: 3 px, 4 px in from the item's
/// edges, radius 8. It lies inside the item, as the menu's own edges are
/// near. The content is kept 10 clear of the item's top and bottom, so that
/// a label that large text sets on two lines clears the ring too (and the
/// labels around it); one line at the usual size still makes an item 48
/// high.
///
/// It fills the item, which must have no padding of its own: [SeferMenuItem]
/// puts it in one.
class MenuItemFocusRing extends StatefulWidget {
  const MenuItemFocusRing({super.key, required this.child});

  final Widget child;

  @override
  State<MenuItemFocusRing> createState() => _MenuItemFocusRingState();
}

class _MenuItemFocusRingState extends State<MenuItemFocusRing> with _KeyboardHighlight {
  // The item's ink well is the nearest focus node above its content.
  bool _itemFocused({bool createDependency = true}) =>
      Focus.maybeOf(context, createDependency: createDependency)?.hasPrimaryFocus ?? false;

  @override
  bool get ringFocused => _itemFocused(createDependency: false);

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: _itemFocused() && keyboardHighlight
            ? _InsetRingPainter(ring: SeferColors.of(context).focus, inset: const EdgeInsets.all(4))
            : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
          child: SizedBox(
            width: double.infinity,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: widget.child),
            ),
          ),
        ),
      );
}

/// A 3 px [ring] whose outer edge lies [inset] in from the edges of what it
/// is painted over (out from an edge whose inset is negative), its corners
/// of [radius].
class _InsetRingPainter extends CustomPainter {
  const _InsetRingPainter({required this.ring, required this.inset, this.radius = 8});

  final Color ring;
  final EdgeInsets inset;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(radius)),
      side: BorderSide(color: ring, width: 3, strokeAlign: BorderSide.strokeAlignInside),
    ).paint(canvas, inset.deflateRect(Offset.zero & size));
  }

  @override
  bool shouldRepaint(_InsetRingPainter old) => old.ring != ring || old.inset != inset || old.radius != radius;
}

/// A [PopupMenuItem] that shows keyboard focus with a [MenuItemFocusRing]
/// alone. Material would also wash the item in ThemeData.focusColor, which
/// muddies the ring, and on the speech rates' menu would look like the
/// chosen rate's highlight.
class SeferMenuItem<T> extends PopupMenuItem<T> {
  const SeferMenuItem({super.key, super.value, super.onTap, super.enabled, required Widget super.child})
      : super(padding: EdgeInsets.zero);

  @override
  PopupMenuItemState<T, SeferMenuItem<T>> createState() => _SeferMenuItemState<T>();
}

class _SeferMenuItemState<T> extends PopupMenuItemState<T, SeferMenuItem<T>> {
  @override
  Widget buildChild() => MenuItemFocusRing(child: widget.child!);

  @override
  Widget build(BuildContext context) => Theme(
        // For the item's ink well, which Material gives no focus colour of
        // its own.
        data: Theme.of(context).copyWith(focusColor: Colors.transparent),
        // A Theme also resets the icon theme, which stays the menu's.
        child: IconTheme(data: IconTheme.of(context), child: super.build(context)),
      );
}

/// A [ListTile], or a CheckboxListTile or RadioListTile, that shows keyboard
/// focus with a 3 px ring in [SeferColors.focus], as [SeferInkWell] does,
/// instead of Material's wash, which it clears.
///
/// The ring lies inside the tile, 4 px in from its edges as a menu item's
/// is, clear of the edges (and the high-contrast outline) of a sheet that
/// the tile spans. Or, [outside], it stands 4 px out from the tile's sides,
/// and spans its height: for a tile with no content padding, in a dialog's
/// padded content, whose text and icons are at its sides. (Its height
/// leaves room enough above and below them.)
class TileFocusRing extends StatefulWidget {
  const TileFocusRing({super.key, required this.child, this.radius = 8, this.outside = false});

  final Widget child;

  /// The ring's outer corner radius.
  final double radius;

  /// Whether the ring stands out from the tile's sides rather than inside it.
  final bool outside;

  @override
  State<TileFocusRing> createState() => _TileFocusRingState();
}

class _TileFocusRingState extends State<TileFocusRing> with _KeyboardHighlight {
  /// Inside: 4 px in all round. Outside: a 4 px gap beside the tile, then
  /// the ring.
  static const _inside = EdgeInsets.all(4);
  static const _outside = EdgeInsets.symmetric(horizontal: -(4 + 3.0));

  bool _focused = false;

  @override
  bool get ringFocused => _focused;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomPaint(
      // Only the painter changes, so showing the ring never rebuilds the tile
      // (and drops its focus).
      foregroundPainter: _focused && keyboardHighlight
          ? _InsetRingPainter(
              ring: SeferColors.of(context).focus,
              inset: widget.outside ? _outside : _inside,
              radius: widget.radius,
            )
          : null,
      // Told whenever the tile's own focus node, inside it, gains or loses
      // focus.
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onFocusChange: (focused) {
          if (focused != _focused) setState(() => _focused = focused);
        },
        child: Theme(data: theme.copyWith(focusColor: Colors.transparent), child: widget.child),
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
