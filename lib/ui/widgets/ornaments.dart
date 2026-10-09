import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/sefer_colors.dart';
import '../theme/typography.dart';

// The book's ornaments (docs/DESIGN_SYSTEM.md §7). They decorate and never
// inform: each is hidden from assistive technology, and a screen uses two at
// most. High contrast draws them all in onSurface, and its hairlines are 2 px.

/// The colour an ornament draws in: [normal], or onSurface in high contrast.
Color _ink(BuildContext context, Color normal) =>
    SeferColors.of(context).isHighContrast ? Theme.of(context).colorScheme.onSurface : normal;

/// The small line above a title, in gold ink: small caps in the English UI
/// (§4.5). Never put digits in it; old-style small-cap figures make "1" read
/// as "I".
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.textAlign});

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final type = SeferType.of(context);
    return Text(type.eyebrowText(text), style: type.eyebrow, textAlign: textAlign);
  }
}

/// A lozenge, the book's one motif: the diamond M4,0 L8,4 L4,8 L0,4 Z of an
/// 8×8 box, scaled to [size]. Gold leaf by default.
class Lozenge extends StatelessWidget {
  const Lozenge({super.key, this.size = small, this.color, this.outlined = false, this.ringed = false})
      : assert(size > 0);

  /// The two sizes it comes in: a divider's centre or a Record row, and
  /// onboarding steps and pass pips.
  static const double small = 8;
  static const double large = 12;

  final double size;

  /// Gold leaf (onSurface in high contrast) unless given.
  final Color? color;

  /// A 1.5 px outline, as big as the filled lozenge, instead of a fill.
  final bool outlined;

  /// An extra 2 px ring around it, marking the current step. The ring is
  /// drawn outside the box, so leave a few pixels free around it.
  final bool ringed;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(size),
          painter: _LozengePainter(
            color: color ?? _ink(context, SeferColors.of(context).goldLeaf),
            outlined: outlined,
            ringed: ringed,
          ),
        ),
      );
}

class _LozengePainter extends CustomPainter {
  const _LozengePainter({required this.color, required this.outlined, required this.ringed});

  final Color color;
  final bool outlined;
  final bool ringed;

  static const outline = 1.5;
  static const ringGap = 1.5;
  static const ring = 2.0;

  /// The lozenge filling [box], with its edges moved [offset] outward (or
  /// inward, if negative).
  static Path diamond(Rect box, [double offset = 0]) {
    final c = box.center;
    // Each edge runs at 45°, so a vertex moves √2 times as far as its edges.
    final h = box.shortestSide / 2 + offset * math.sqrt2;
    return Path()
      ..moveTo(c.dx, c.dy - h)
      ..lineTo(c.dx + h, c.dy)
      ..lineTo(c.dx, c.dy + h)
      ..lineTo(c.dx - h, c.dy)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    if (outlined) {
      // Stroked inside the box, so an outlined lozenge is as big as a filled
      // one.
      canvas.drawPath(
        diamond(box, -outline / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = outline
          ..color = color,
      );
    } else {
      canvas.drawPath(diamond(box), Paint()..color = color);
    }
    if (ringed) {
      canvas.drawPath(
        diamond(box, ringGap + ring / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_LozengePainter old) => old.color != color || old.outlined != outlined || old.ringed != ringed;
}

/// Where a reading pass stands, for [PassPips].
enum PipState { pending, done }

/// Three lozenges for the three readings of an aliyah, in reading order:
/// Mikra, Mikra again, then Targum. They follow the text direction, so in
/// Hebrew the first reading is the rightmost.
///
/// A done reading is filled in its ring colour and a pending one outlined;
/// [current] marks the reading under way with a ring. Purely visual: the
/// row's own label says what they show.
class PassPips extends StatelessWidget {
  const PassPips({super.key, required this.states, this.size = full, this.current})
      : assert(size == full || size == mini, 'Pips are 12 or 6 (mini)'),
        assert(current == null || size == full, 'Mini pips mark no current reading (§7.5)');

  /// A parsha row's pips, and the mini pips of an aliyah tab.
  static const double full = 12;
  static const double mini = 6;

  final List<PipState> states;
  final double size;

  /// The index of the reading under way, if any.
  final int? current;

  double get gap => size == mini ? 3 : 8;

  @override
  Widget build(BuildContext context) {
    // Checked here, since a const constructor can't read a list's length.
    assert(states.length == 3, 'One state per reading');
    final sefer = SeferColors.of(context);
    final colors = [sefer.ringMikra1, sefer.ringMikra2, sefer.ringTargum];
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Lozenge(
              size: size,
              color: _ink(context, colors[i]),
              outlined: states[i] == PipState.pending,
              ringed: current == i,
            ),
          ],
        ],
      ),
    );
  }
}

/// A centred rule with a lozenge at its heart, between hero sections, in
/// finished panels and empty states, and between long-form sections. Never
/// between list rows.
///
/// It is 16 high and, unless given a [width], 45% of the column at most 200
/// wide. The hairlines stop 10 short of the centre, either side of an 8 px
/// gold-leaf lozenge.
class SeferDivider extends StatelessWidget {
  const SeferDivider({super.key, this.width, this.progress = 1}) : assert(progress >= 0 && progress <= 1);

  static const double maxWidth = 200;
  static const double height = 16;

  /// A fixed width, such as the finished panel's 200.
  final double? width;

  /// How far the hairlines have drawn outward from the lozenge, from 0 (the
  /// lozenge alone) to 1, for the completion animation (§8).
  final double progress;

  @override
  Widget build(BuildContext context) {
    final sefer = SeferColors.of(context);
    final painter = CustomPaint(
      painter: _DividerPainter(
        rule: _ink(context, sefer.hairline),
        ruleWidth: sefer.hairlineWidth,
        lozenge: _ink(context, sefer.goldLeaf),
        progress: progress,
      ),
    );
    return ExcludeSemantics(
      child: Center(
        heightFactor: 1,
        child: width == null
            ? _ShareOfWidth(fraction: 0.45, maxWidth: maxWidth, height: height, child: painter)
            : SizedBox(width: width, height: height, child: painter),
      ),
    );
  }
}

class _DividerPainter extends CustomPainter {
  const _DividerPainter({required this.rule, required this.ruleWidth, required this.lozenge, required this.progress});

  final Color rule;
  final double ruleWidth;
  final Color lozenge;
  final double progress;

  /// How far short of the centre each hairline stops.
  static const clearance = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    // On whole pixels, so a 1 px hairline stays crisp on a 1x screen, with
    // the lozenge centred on it.
    final top = (size.height / 2 - ruleWidth / 2).floorToDouble();
    final c = Offset(size.width / 2, top + ruleWidth / 2);
    final reach = (c.dx - clearance) * progress;
    if (reach > 0) {
      final paint = Paint()..color = rule;
      canvas
        ..drawRect(Rect.fromLTWH(c.dx - clearance - reach, top, reach, ruleWidth), paint)
        ..drawRect(Rect.fromLTWH(c.dx + clearance, top, reach, ruleWidth), paint);
    }
    final box = Rect.fromCenter(center: c, width: Lozenge.small, height: Lozenge.small);
    canvas.drawPath(_LozengePainter.diamond(box), Paint()..color = lozenge);
  }

  @override
  bool shouldRepaint(_DividerPainter old) =>
      old.rule != rule || old.ruleWidth != ruleWidth || old.lozenge != lozenge || old.progress != progress;
}

/// Sizes its child [fraction] of the width it is offered, at most [maxWidth],
/// by [height] (or [maxWidth] wide when the width is unbounded). Unlike a
/// LayoutBuilder it can report its intrinsic size, so a divider may sit in a
/// dialog or an IntrinsicHeight row.
class _ShareOfWidth extends SingleChildRenderObjectWidget {
  const _ShareOfWidth({required this.fraction, required this.maxWidth, required this.height, super.child});

  final double fraction;
  final double maxWidth;
  final double height;

  @override
  _RenderShareOfWidth createRenderObject(BuildContext context) =>
      _RenderShareOfWidth(fraction: fraction, maxWidth: maxWidth, height: height);

  @override
  void updateRenderObject(BuildContext context, _RenderShareOfWidth renderObject) => renderObject
    ..fraction = fraction
    ..maxWidth = maxWidth
    ..height = height;
}

class _RenderShareOfWidth extends RenderProxyBox {
  _RenderShareOfWidth({required this._fraction, required this._maxWidth, required this._height});

  double _fraction;
  set fraction(double value) {
    if (value == _fraction) return;
    _fraction = value;
    markNeedsLayout();
  }

  double _maxWidth;
  set maxWidth(double value) {
    if (value == _maxWidth) return;
    _maxWidth = value;
    markNeedsLayout();
  }

  double _height;
  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  Size _sizeFor(BoxConstraints constraints) => constraints.constrain(Size(
        constraints.hasBoundedWidth ? math.min(_maxWidth, _fraction * constraints.maxWidth) : _maxWidth,
        _height,
      ));

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => _maxWidth;

  @override
  double computeMinIntrinsicHeight(double width) => _height;

  @override
  double computeMaxIntrinsicHeight(double width) => _height;

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints);

  @override
  void performLayout() {
    size = _sizeFor(constraints);
    child?.layout(BoxConstraints.tight(size));
  }
}

/// Which break in the text a [SectionBreakMark] shows: an open (פ) or a
/// closed (ס) section.
enum SectionBreak { petuchah, setumah }

/// The mark between sections of the Torah text in full-text reading: פ or ס
/// in gold ink, flanked by 40 px hairlines.
class SectionBreakMark extends StatelessWidget {
  const SectionBreakMark(this.kind, {super.key, required this.verseSize});

  final SectionBreak kind;

  /// The verse font size; the letter is 0.55 of it, like a verse number.
  final double verseSize;

  @override
  Widget build(BuildContext context) {
    final sefer = SeferColors.of(context);
    final rule = SizedBox(width: 40, height: sefer.hairlineWidth, child: ColoredBox(color: _ink(context, sefer.hairline)));
    // Frank Ruhl Libre 600 (700 in high contrast, as every Frank Ruhl role),
    // never an interface font: those have no Hebrew.
    final style = SeferType.of(context).hebrewDisplay.copyWith(
          fontSize: 0.55 * verseSize,
          fontWeight: sefer.isHighContrast ? FontWeight.w700 : FontWeight.w600,
          color: _ink(context, Theme.of(context).colorScheme.secondary),
        );
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          rule,
          const SizedBox(width: 8),
          Text(
            kind == SectionBreak.petuchah ? 'פ' : 'ס',
            style: style,
            textDirection: TextDirection.rtl,
            locale: const Locale('he'),
          ),
          const SizedBox(width: 8),
          rule,
        ],
      ),
    );
  }
}

/// A title page's double frame: a hairline at radius 12 around paper, and a
/// gold-leaf rule inset 6 within it at radius 8. High contrast keeps a single
/// 2 px outline.
///
/// Only for the Today hero, the Welcome title block and the About header at
/// 600 dp and wider.
class TitlePageFrame extends StatelessWidget {
  const TitlePageFrame({super.key, required this.child, this.padding = const EdgeInsets.all(24), this.drawProgress})
      : assert(drawProgress == null || (drawProgress >= 0 && drawProgress <= 1));

  final Widget child;

  /// Between the outer edge and [child].
  final EdgeInsetsGeometry padding;

  /// How much of the inner rule is drawn, clockwise from the top centre, for
  /// the parsha-complete animation (§8). Null draws it whole.
  final double? drawProgress;

  static const double radius = 12;
  static const double ruleInset = 6;
  static const double ruleRadius = 8;

  @override
  Widget build(BuildContext context) {
    final sefer = SeferColors.of(context);
    return Material(
      color: sefer.paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(radius)),
        side: BorderSide(color: _ink(context, sefer.hairline), width: sefer.hairlineWidth),
      ),
      // Not clipped, so the focus ring of a control inside always shows whole.
      child: CustomPaint(
        painter: sefer.isHighContrast ? null : _InnerRulePainter(color: sefer.goldLeaf, progress: drawProgress ?? 1),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _InnerRulePainter extends CustomPainter {
  const _InnerRulePainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  static const width = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    // The stroke's outer edge lies on the inset, and its corners on the radius.
    const half = width / 2;
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(TitlePageFrame.ruleInset + half),
      const Radius.circular(TitlePageFrame.ruleRadius - half),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    if (progress >= 1) {
      canvas.drawRRect(rrect, paint);
      return;
    }
    final outline = _clockwiseFromTop(rrect);
    final metric = outline.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
  }

  /// [r]'s outline as one contour from the middle of its top edge. Like the
  /// parsha rings, it runs clockwise in both text directions: a frame is not
  /// text.
  static Path _clockwiseFromTop(RRect r) {
    final k = Radius.circular(r.tlRadiusX);
    return Path()
      ..moveTo(r.center.dx, r.top)
      ..lineTo(r.right - k.x, r.top)
      ..arcToPoint(Offset(r.right, r.top + k.y), radius: k)
      ..lineTo(r.right, r.bottom - k.y)
      ..arcToPoint(Offset(r.right - k.x, r.bottom), radius: k)
      ..lineTo(r.left + k.x, r.bottom)
      ..arcToPoint(Offset(r.left, r.bottom - k.y), radius: k)
      ..lineTo(r.left, r.top + k.y)
      ..arcToPoint(Offset(r.left + k.x, r.top), radius: k)
      ..close();
  }

  @override
  bool shouldRepaint(_InnerRulePainter old) => old.color != color || old.progress != progress;
}
