import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'fonts_change_scope.dart';

/// [parts] between middle dots, as many to a line as fit, so that a line
/// breaks between two parts rather than inside one ("Read on Shabbat,
/// October / 10"). A line that starts after a break starts with its part,
/// not with a dot. A part too long for a line on its own wraps after a comma
/// in it ("Read on Shabbat, / October 10") before it wraps anywhere else.
///
/// Each line is a text of its own, whose words are kept whole ([WholeWords]).
class DotLine extends StatelessWidget {
  const DotLine(this.parts, {super.key, required this.style, this.textAlign = TextAlign.start});

  final List<String> parts;
  final TextStyle? style;
  final TextAlign textAlign;

  static const separator = ' · ';
  static const nbsp = '\u00A0';

  @override
  Widget build(BuildContext context) {
    // Measured again when a font arrives.
    FontsChangeScope.watch(context);
    return LayoutBuilder(builder: (context, constraints) {
      final bold = MediaQuery.boldTextOf(context) ? const TextStyle(fontWeight: FontWeight.bold) : null;
      final painter = TextPainter(
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
        maxLines: 1,
      );
      bool fits(String text) {
        painter
          ..text = TextSpan(text: text, style: style?.merge(bold) ?? bold)
          ..layout(maxWidth: constraints.maxWidth);
        return !painter.didExceedMaxLines;
      }

      // Each clause of a part too long for a line, kept whole where it fits
      // on one.
      String wrappable(String part) {
        if (fits(part)) return part;
        return [for (final clause in part.split(', ')) fits(clause) ? clause.replaceAll(' ', nbsp) : clause]
            .join(', ');
      }

      final lines = <String>[];
      for (final part in parts) {
        if (lines.isNotEmpty && fits('${lines.last}$separator$part')) {
          lines.last = '${lines.last}$separator$part';
        } else {
          lines.add(wrappable(part));
        }
      }
      painter.dispose();
      // A part with a word too wide for the line even so, at the largest
      // text sizes, is set just small enough for it.
      Widget line(String text) => WholeWords(text, style: style, textAlign: textAlign, breakAtHyphens: true);
      if (lines.length == 1) return line(lines.single);
      return Column(
        crossAxisAlignment: textAlign == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [for (final text in lines) line(text)],
      );
    });
  }
}

/// [text] with each spaced em dash held to the word before it, so that no
/// line starts with a dash.
String dashHeldToWord(String text) => text.replaceAll(' — ', '${DotLine.nbsp}— ');

/// [text] wrapped between its words, never inside one: a word too wide for
/// the line on its own, as with large text, is set just small enough to fit.
/// Centred unless [textAlign] says otherwise. Its [style] is merged with the
/// ambient one, as a [Text]'s is, so it can label a button.
///
/// A word joined by a hyphen, a dash or a maqaf, as a name of two parshiyot
/// is ("Matot-Masei"), is kept whole too: measured whole, and set with a word
/// joiner after the hyphen, so that no line ends there, even among other
/// words ("Acharei" over "Mot-Kedoshim"). Unless [breakAtHyphens]: then a
/// line may end after the hyphen, as in a sentence that names one.
///
/// With a [minFontSize], a word is never set smaller than that: one that
/// would have to be, as a long email address on a phone, wraps instead.
///
/// It answers intrinsic size queries, unlike a [LayoutBuilder], so it may
/// stand in a row that is as tall as its tallest cell ([IntrinsicHeight]).
class WholeWords extends StatelessWidget {
  const WholeWords(
    String this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.textDirection,
    this.locale,
    this.semanticsLabel,
    this.breakAtHyphens = false,
    this.minFontSize,
  }) : textSpan = null;

  /// [textSpan] set as a [Text.rich] sets it, each word measured in the
  /// style of its own span (a widget in it is no word). Its hyphens are left
  /// as they are, as with [breakAtHyphens].
  const WholeWords.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.textDirection,
    this.locale,
    this.semanticsLabel,
    this.minFontSize,
  })  : text = null,
        breakAtHyphens = true;

  final String? text;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final Locale? locale;

  /// What a screen reader says instead of [text], as [Text.semanticsLabel].
  /// It hears [text] as it is written otherwise, without the joiners set to
  /// keep its words whole.
  final String? semanticsLabel;

  /// Whether a line may end after a hyphen, a dash or a maqaf within a word:
  /// not one that a word joiner holds to the word after it, as the dash of
  /// a range kept whole ("2:20–3:21").
  final bool breakAtHyphens;

  /// The smallest size a word is set at, in logical pixels as drawn (the
  /// text scale applied); none if null.
  final double? minFontSize;

  /// labelSmall's size, the smallest the interface is set at anywhere
  /// (docs/DESIGN_SYSTEM.md §4.3): a [minFontSize] for words that may be of
  /// any length, as a member's name or email address.
  static const smallestSize = 12.0;

  static final _words = RegExp(r'[^ ]+');
  static final _hyphenated = RegExp(r'(?:[^ \-–—־]|[\-–—־]\u2060)+[\-–—־]?|[\-–—־]');
  static final _hyphen = RegExp(r'[\-–—־]');

  /// [text] with a word joiner after each hyphen, dash or maqaf, and before
  /// an em dash, which a line may also end before: a line breaks at none of
  /// them.
  static String unbroken(String text) =>
      text.replaceAllMapped(_hyphen, (m) => m[0] == '—' ? '\u2060—\u2060' : '${m[0]}\u2060');

  @override
  Widget build(BuildContext context) {
    // Measured again when a font arrives.
    FontsChangeScope.watch(context);
    var effective = DefaultTextStyle.of(context).style.merge(style);
    if (MediaQuery.boldTextOf(context)) effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
    final scaler = MediaQuery.textScalerOf(context);
    final direction = textDirection ?? Directionality.of(context);
    var widest = 0.0;
    void measure(String text, TextStyle style) {
      for (final word in (breakAtHyphens ? _hyphenated : _words).allMatches(text)) {
        final painter = TextPainter(
          text: TextSpan(text: word.group(0), style: style),
          textDirection: direction,
          textScaler: scaler,
          locale: locale,
          maxLines: 1,
        )..layout();
        widest = math.max(widest, painter.width);
        painter.dispose();
      }
    }

    // In each span's own style, merged down from the paragraph's. A word
    // that runs on from one span into the next is measured in parts.
    void measureSpan(InlineSpan span, TextStyle inherited) {
      if (span is! TextSpan) return;
      final style = inherited.merge(span.style);
      if (span.text case final text?) measure(text, style);
      for (final child in span.children ?? const <InlineSpan>[]) {
        measureSpan(child, style);
      }
    }

    final floor = minFontSize;
    final size = scaler.scale(effective.fontSize ?? kDefaultFontSize);
    final minScale = floor == null || size <= 0 ? 0.0 : math.min(1.0, floor / size);
    if (textSpan case final span?) {
      measureSpan(span, effective);
      return _FitWord(
        word: widest,
        minScale: minScale,
        child: Text.rich(
          span,
          style: style,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          semanticsLabel: semanticsLabel,
        ),
      );
    }
    final text = this.text!;
    measure(text, effective);
    final shown = breakAtHyphens ? text : unbroken(text);
    return _FitWord(
      word: widest,
      minScale: minScale,
      child: Text(
        shown,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        semanticsLabel: semanticsLabel ?? (shown == text ? null : text),
      ),
    );
  }
}

/// Lays its child out as it is when a [word] of its text fits the width it
/// is given, and otherwise scales it down, as a smaller text size would, so
/// that the word just fits, or to [minScale] at least.
class _FitWord extends SingleChildRenderObjectWidget {
  const _FitWord({required this.word, this.minScale = 0, required super.child});

  /// The width of the widest word.
  final double word;

  /// The smallest scale it is set at: below it, the text wraps.
  final double minScale;

  @override
  _RenderFitWord createRenderObject(BuildContext context) => _RenderFitWord(word, minScale);

  @override
  void updateRenderObject(BuildContext context, _RenderFitWord renderObject) => renderObject
    ..word = word
    ..minScale = minScale;
}

class _RenderFitWord extends RenderProxyBox {
  _RenderFitWord(this._word, this._minScale);

  double get word => _word;
  double _word;
  set word(double value) {
    if (value == _word) return;
    _word = value;
    markNeedsLayout();
  }

  double get minScale => _minScale;
  double _minScale;
  set minScale(double value) {
    if (value == _minScale) return;
    _minScale = value;
    markNeedsLayout();
  }

  double _scale = 1;

  /// The scale at which the widest word fits [width]: a hair under, so that
  /// rounding never breaks the word after all; but no smaller than
  /// [minScale], where the word wraps. None where the width is a pixel or
  /// less (a label squeezed to nothing, as in a collapse): no word fits
  /// there at any size, and the text wraps as a plain Text would.
  double _scaleFor(double width) =>
      width.isFinite && width > 1 && _word > width ? math.max((width - 1) / _word, _minScale) : 1;

  BoxConstraints _unscaled(BoxConstraints c, double scale) => scale == 1 ? c : c / scale;

  Matrix4 get _transform => Matrix4.diagonal3Values(_scale, _scale, 1);

  @override
  double computeMinIntrinsicHeight(double width) {
    final scale = _scaleFor(width);
    return (child?.getMinIntrinsicHeight(width / scale) ?? 0) * scale;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final scale = _scaleFor(width);
    return (child?.getMaxIntrinsicHeight(width / scale) ?? 0) * scale;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final scale = _scaleFor(constraints.maxWidth);
    return constraints.constrain(child.getDryLayout(_unscaled(constraints, scale)) * scale);
  }

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final scale = _scaleFor(constraints.maxWidth);
    final distance = child?.getDryBaseline(_unscaled(constraints, scale), baseline);
    return distance == null ? null : distance * scale;
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    _scale = _scaleFor(constraints.maxWidth);
    child.layout(_unscaled(constraints, _scale), parentUsesSize: true);
    size = constraints.constrain(child.size * _scale);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final distance = child?.getDistanceToActualBaseline(baseline);
    return distance == null ? null : distance * _scale;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (_scale == 1) {
      layer = null;
      context.paintChild(child, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.multiply(_transform);
}

/// [text] wrapped as evenly as its lines allow: as narrow as it can be set
/// in as few lines as the full width takes, so that a word is never left
/// alone on its last line, as a title page sets its lines. Centred unless
/// [textAlign] says otherwise. A word too wide for the line on its own is
/// set just small enough to fit, as [WholeWords] sets it.
///
/// With [bySentence], text too long for one line sets each sentence on a
/// line or more of its own. With [holdDashes], a spaced em dash is held to
/// the word before it ([dashHeldToWord]), so that no line starts with one,
/// wherever the two fit on a line together; where they don't (very large
/// text on a phone), the words are set at their size rather than smaller.
class BalancedText extends StatelessWidget {
  const BalancedText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.center,
    this.bySentence = false,
    this.holdDashes = false,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool bySentence;
  final bool holdDashes;

  static final _sentenceBreak = RegExp(r'(?<=[.?!])\s+(?=\S)');

  @override
  Widget build(BuildContext context) {
    // Measured again when a font arrives.
    FontsChangeScope.watch(context);
    return LayoutBuilder(builder: (context, constraints) {
      final bold = MediaQuery.boldTextOf(context) ? const TextStyle(fontWeight: FontWeight.bold) : null;
      TextPainter painter(String text) => TextPainter(
            text: TextSpan(text: text, style: style?.merge(bold) ?? bold),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            locale: Localizations.maybeLocaleOf(context),
          )..layout(maxWidth: constraints.maxWidth);

      Widget balanced(String text) {
        final p = painter(text);
        // A word too wide for the line, as with very large text on a small
        // phone, leaves no lines to balance: it is set whole, just small
        // enough to fit.
        if (p.minIntrinsicWidth > constraints.maxWidth) {
          p.dispose();
          return WholeWords(text, style: style, textAlign: textAlign, breakAtHyphens: true);
        }
        final lines = p.computeLineMetrics().length;
        var width = constraints.maxWidth;
        if (lines > 1) {
          // Never narrower than its widest word.
          var low = math.min(p.minIntrinsicWidth, width);
          var high = width;
          for (var i = 0; i < 10 && high - low > 1; i++) {
            final mid = (low + high) / 2;
            p.layout(maxWidth: mid);
            if (p.computeLineMetrics().length > lines) {
              low = mid;
            } else {
              high = mid;
            }
          }
          width = math.min(constraints.maxWidth, high.ceilToDouble() + 1);
        }
        p.dispose();
        return Align(
          alignment: textAlign == TextAlign.center ? Alignment.center : AlignmentDirectional.centerStart,
          widthFactor: 1,
          child: SizedBox(width: width, child: Text(text, style: style, textAlign: textAlign)),
        );
      }

      var text = this.text;
      if (holdDashes) {
        final held = dashHeldToWord(text);
        if (held != text) {
          final p = painter(held);
          if (p.minIntrinsicWidth <= constraints.maxWidth) text = held;
          p.dispose();
        }
      }
      final sentences = bySentence ? text.split(_sentenceBreak) : [text];
      if (sentences.length > 1) {
        final whole = painter(text);
        final oneLine = whole.computeLineMetrics().length <= 1;
        whole.dispose();
        if (!oneLine) {
          return Semantics(
            // One text for screen readers, as it is written.
            label: text,
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final s in sentences) balanced(s)],
            ),
          );
        }
      }
      return balanced(text);
    });
  }
}
