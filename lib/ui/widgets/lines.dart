import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'fonts_change_scope.dart';

/// [parts] between middle dots, as many to a line as fit, so that a line
/// breaks between two parts rather than inside one ("Read on Shabbat,
/// October / 10"). A line that starts after a break starts with its part,
/// not with a dot. A part too long for a line on its own wraps after a comma
/// in it ("Read on Shabbat, / October 10") before it wraps anywhere else.
///
/// Each line is a text of its own.
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
      if (lines.length == 1) return Text(lines.single, style: style, textAlign: textAlign);
      return Column(
        crossAxisAlignment: textAlign == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [for (final line in lines) Text(line, style: style, textAlign: textAlign)],
      );
    });
  }
}

/// [text] wrapped between its words, never inside one: a word too wide for
/// the line on its own, as with large text, is set just small enough to fit.
/// Centred unless [textAlign] says otherwise.
class WholeWords extends StatelessWidget {
  const WholeWords(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.center,
    this.textDirection,
    this.locale,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final Locale? locale;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final bold = MediaQuery.boldTextOf(context) ? const TextStyle(fontWeight: FontWeight.bold) : null;
        var widest = 0.0;
        for (final word in text.split(' ')) {
          final painter = TextPainter(
            text: TextSpan(text: word, style: style?.merge(bold) ?? bold),
            textDirection: textDirection ?? Directionality.of(context),
            textScaler: scaler,
            locale: locale,
            maxLines: 1,
          )..layout();
          widest = math.max(widest, painter.width);
          painter.dispose();
        }
        final size = style?.fontSize ?? 14;
        // A hair under, so rounding never breaks the word after all.
        final share = widest > constraints.maxWidth ? (constraints.maxWidth - 1) / widest : 1.0;
        return Text(
          text,
          style: style,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          textScaler: share < 1 ? TextScaler.linear(scaler.scale(size) / size * share) : null,
        );
      });
}
