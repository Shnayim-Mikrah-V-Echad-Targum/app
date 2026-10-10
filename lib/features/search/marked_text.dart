import 'dart:ui' as ui show BoxHeightStyle;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Text with parts of it marked as a highlighter marks a page: a wash behind
/// each of [marks], as tall as the letters rather than the line, so that
/// Hebrew, set with the generous leading its vowels need, keeps the marks on
/// one line apart from those on the next. A [TextStyle.backgroundColor] would
/// fill the whole line box.
///
/// It has no semantics of its own: whatever shows it gives the label.
class MarkedText extends LeafRenderObjectWidget {
  const MarkedText(
    this.text, {
    super.key,
    required this.marks,
    required this.color,
    this.outline,
    required this.textDirection,
    this.locale,
  });

  final TextSpan text;

  /// Ranges of [text]'s characters to mark.
  final List<TextRange> marks;

  /// The wash behind them.
  final Color color;

  /// A line drawn around each wash, if any: a cue that needs neither the
  /// wash's colour nor the marked letters' weight.
  final Color? outline;

  final TextDirection textDirection;
  final Locale? locale;

  /// [text] over the ambient style, made bold where the platform asks for
  /// bold text, as [Text] would set it.
  TextSpan _effective(BuildContext context) {
    var style = DefaultTextStyle.of(context).style.merge(text.style);
    if (MediaQuery.boldTextOf(context)) style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
    return TextSpan(style: style, children: text.children, text: text.text);
  }

  @override
  RenderMarkedText createRenderObject(BuildContext context) => RenderMarkedText(
        text: _effective(context),
        marks: marks,
        color: color,
        outline: outline,
        textDirection: textDirection,
        textScaler: MediaQuery.textScalerOf(context),
        locale: locale ?? Localizations.maybeLocaleOf(context),
      );

  @override
  void updateRenderObject(BuildContext context, RenderMarkedText renderObject) {
    renderObject
      ..text = _effective(context)
      ..marks = marks
      ..color = color
      ..outline = outline
      ..textDirection = textDirection
      ..textScaler = MediaQuery.textScalerOf(context)
      ..locale = locale ?? Localizations.maybeLocaleOf(context);
  }
}

// Like RenderParagraph, it lays the text out again when the system's fonts
// change: a font loaded after the first layout (on the web, or one the
// reader has just chosen) has other metrics, and the washes would no longer
// lie under their letters.
class RenderMarkedText extends RenderBox with RelayoutWhenSystemFontsChangeMixin {
  RenderMarkedText({
    required TextSpan text,
    required this._marks,
    required this._color,
    this._outline,
    required TextDirection textDirection,
    required TextScaler textScaler,
    Locale? locale,
  }) : _painter = TextPainter(text: text, textDirection: textDirection, textScaler: textScaler, locale: locale);

  final TextPainter _painter;

  @override
  void systemFontsDidChange() {
    super.systemFontsDidChange();
    _painter.markNeedsLayout();
  }

  set text(TextSpan value) {
    final old = _painter.text!;
    if (old == value) return;
    final change = old.compareTo(value);
    _painter.text = value;
    if (change.index >= RenderComparison.layout.index) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
  }

  List<TextRange> _marks;
  set marks(List<TextRange> value) {
    if (listEquals(_marks, value)) return;
    _marks = value;
    markNeedsPaint();
  }

  Color _color;
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  Color? _outline;
  set outline(Color? value) {
    if (_outline == value) return;
    _outline = value;
    markNeedsPaint();
  }

  set textDirection(TextDirection value) {
    if (_painter.textDirection == value) return;
    _painter.textDirection = value;
    markNeedsLayout();
  }

  set textScaler(TextScaler value) {
    if (_painter.textScaler == value) return;
    _painter.textScaler = value;
    markNeedsLayout();
  }

  set locale(Locale? value) {
    if (_painter.locale == value) return;
    _painter.locale = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    _painter.layout();
    return _painter.minIntrinsicWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    _painter.layout();
    return _painter.maxIntrinsicWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _painter.layout(maxWidth: width);
    return _painter.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    _layout(constraints);
    return _painter.computeDistanceToActualBaseline(baseline);
  }

  /// Lays the text out across [constraints]: as wide as the box when it must
  /// fill it, so that the text's alignment places it in the box.
  void _layout(BoxConstraints constraints) =>
      _painter.layout(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    _layout(constraints);
    return constraints.constrain(_painter.size);
  }

  @override
  void performLayout() {
    _layout(constraints);
    size = constraints.constrain(_painter.size);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    // Measuring at another width since layout leaves the painter laid out
    // for that one.
    _layout(constraints);
    final canvas = context.canvas;
    final wash = Paint()..color = _color;
    final outline = _outline == null
        ? null
        : (Paint()
          ..color = _outline!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    for (final mark in _marks) {
      final boxes = _painter.getBoxesForSelection(
        TextSelection(baseOffset: mark.start, extentOffset: mark.end),
        boxHeightStyle: ui.BoxHeightStyle.tight,
      );
      for (final box in boxes) {
        final rect = Rect.fromLTRB(box.left - 2, box.top, box.right + 2, box.bottom).shift(offset);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
        canvas.drawRRect(rrect, wash);
        if (outline != null) canvas.drawRRect(rrect.deflate(0.75), outline);
      }
    }
    _painter.paint(canvas, offset);
  }

  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
  }
}
