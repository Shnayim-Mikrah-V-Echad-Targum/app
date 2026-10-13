import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/text/hebrew_text.dart';
import '../../data/models/scripture.dart';
import '../../data/models/verse_ref.dart';
import '../../l10n/app_localizations.dart';
import '../../services/feedback.dart' show hapticLongPress;
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/fonts_change_scope.dart';
import '../../ui/widgets/lang.dart';
import '../../ui/widgets/ornaments.dart' hide SectionBreak;
import '../../ui/widgets/ornaments.dart' as ornaments show SectionBreak;
import '../settings/app_settings.dart';

/// Which kind of text is being rendered, for sizing and styling.
enum ScriptureKind { mikra, targum, rashi, translation }

/// Text styles for scripture, derived from the reader's settings
/// (docs/DESIGN_SYSTEM.md §4.7). The in-app reading size multiplies the
/// system text scale (applied by Text).
class ScriptureStyles {
  ScriptureStyles(this.context, this.settings);

  final BuildContext context;
  final AppSettings settings;

  /// The Torah's size before the reading size: every Hebrew size is a share
  /// of it.
  static const baseHebrewSize = 26.0;

  /// The English translation's, in EB Garamond, and in an accessibility
  /// font, whose larger letters need less.
  static const baseEnglishSize = 20.0;
  static const accessibleEnglishSize = 17.0;

  static const targumScale = 0.90;
  static const rashiScale = 0.78;
  static const rashiScriptScale = 0.80;

  /// Verse numbers, and the petuchah and setumah marks, to their verse.
  static const numberScale = 0.55;

  /// Ketiv and alternate readings, to their verse.
  static const ketivScale = 0.62;

  /// The room the guided reader's gutter keeps between what it holds (the
  /// number, and the reader's marks after it) and the verse, as a fraction of
  /// the Torah's size: the number stands at the gutter's inner edge, this far
  /// from its verse, and marks with no room beside it go beneath it.
  static const numberGap = 0.3;

  /// The most verses a chapter of the Torah has (Numbers 7), whose numbers
  /// the guided reader's gutter has room for.
  static const _mostVerses = 89;

  /// An accessibility font (Atkinson, Lexend or OpenDyslexic) replaces the
  /// translation's serif, as it replaces the interface's.
  bool get _accessibleFont => settings.uiFont.family != null;

  bool get _bold => settings.boldText || MediaQuery.boldTextOf(context);

  bool get _highContrast => SeferColors.of(context).isHighContrast;

  /// The Torah's line spacing, never below the minimum: settings imported
  /// from an older version may hold less.
  double get lineHeight => settings.lineHeight.clamp(kMinLineHeight, kMaxLineHeight);

  double sizeFor(ScriptureKind kind) =>
      switch (kind) {
        ScriptureKind.mikra => baseHebrewSize,
        ScriptureKind.targum => baseHebrewSize * targumScale,
        ScriptureKind.rashi => baseHebrewSize * (settings.rashiScript ? rashiScriptScale : rashiScale),
        ScriptureKind.translation => _accessibleFont ? accessibleEnglishSize : baseEnglishSize,
      } *
      settings.readingScale;

  /// Pointed and cantillated text needs generous leading, split evenly above
  /// and below so that lower marks are never clipped.
  double heightFor(ScriptureKind kind) => switch (kind) {
        ScriptureKind.mikra => lineHeight,
        // A little closer than the Torah's, as befits the text beneath it.
        ScriptureKind.targum => math.max(kMinLineHeight, lineHeight - 0.1),
        ScriptureKind.rashi => settings.rashiScript ? 1.75 : 1.7,
        ScriptureKind.translation => _accessibleFont ? 26 / 17 : 1.5,
      };

  TextStyle style(ScriptureKind kind, {Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    final bold = _bold;
    final (String? family, List<String> fallback, FontWeight weight) = switch (kind) {
      // Taamey Frank has only a Medium weight (its Bold hides the
      // cantillation), so it is never asked for bold.
      ScriptureKind.mikra || ScriptureKind.targum => (
          settings.scriptureFont.family,
          _hebrewFallback,
          bold && settings.scriptureFont != ScriptureFont.taameyFrank ? FontWeight.w700 : FontWeight.w400,
        ),
      // The Rashi script has a single weight. Until it has loaded (it is
      // loaded only once chosen), Noto Serif Hebrew stands in, and the text is
      // laid out again as it arrives.
      ScriptureKind.rashi when settings.rashiScript => (kRashiScriptFamily, const ['NotoSerifHebrew'], FontWeight.w400),
      ScriptureKind.rashi => ('NotoSerifHebrew', _hebrewFallback, bold ? FontWeight.w700 : FontWeight.w400),
      // The accessibility fonts bundle 400 and 700; EB Garamond 500 to 700.
      ScriptureKind.translation when _accessibleFont => (
          settings.uiFont.family,
          const ['NotoSansHebrew', 'NotoSerifHebrew'],
          bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ScriptureKind.translation => (
          'EBGaramond',
          const ['FrankRuhlLibre', 'NotoSerifHebrew'],
          bold ? FontWeight.w700 : (_highContrast ? FontWeight.w600 : FontWeight.w500),
        ),
    };
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: sizeFor(kind),
      height: heightFor(kind),
      leadingDistribution: TextLeadingDistribution.even,
      wordSpacing: settings.wordSpacing,
      letterSpacing: settings.letterSpacing,
      fontWeight: weight,
      // The Torah in full ink; what accompanies it in the quieter one, which
      // still meets 7:1 (§3.5).
      color: color ?? (kind == ScriptureKind.mikra ? scheme.onSurface : scheme.onSurfaceVariant),
    );
  }

  /// Every line of [kind]'s paragraphs at least its own pitch, so that a span
  /// in another family or size (a verse number, a letter the Masorah writes
  /// small) never makes one line closer than the rest.
  StrutStyle strut(ScriptureKind kind) {
    final s = style(kind);
    return StrutStyle(
      fontFamily: s.fontFamily,
      fontFamilyFallback: s.fontFamilyFallback,
      fontSize: s.fontSize,
      height: s.height,
      leadingDistribution: TextLeadingDistribution.even,
      forceStrutHeight: false,
    );
  }

  /// A verse number for a verse in [kind]: Frank Ruhl Libre in gold ink,
  /// 0.55 of the verse's size, in [dimInk] when [dimmed].
  TextStyle numberStyle(ScriptureKind kind, {bool dimmed = false}) => TextStyle(
        fontFamily: 'FrankRuhlLibre',
        fontFamilyFallback: const ['NotoSerifHebrew'],
        fontSize: sizeFor(kind) * numberScale,
        height: heightFor(kind),
        leadingDistribution: TextLeadingDistribution.even,
        // Frank Ruhl Libre is set bold in high contrast, as in every role.
        fontWeight: _bold || _highContrast ? FontWeight.w700 : FontWeight.w600,
        letterSpacing: 0,
        color: dimmed ? SeferColors.of(context).dimInk : Theme.of(context).colorScheme.secondary,
      );

  /// A petuchah or setumah mark within a verse, drawn as [SectionBreakMark]
  /// draws the marks between verses, so that the two match: an ornament, in
  /// onSurface in high contrast.
  TextStyle rubricStyle(ScriptureKind kind, {bool dimmed = false}) {
    final number = numberStyle(kind, dimmed: dimmed);
    return dimmed || !_highContrast ? number : number.copyWith(color: Theme.of(context).colorScheme.onSurface);
  }

  /// The words a comment of Rashi explains (the dibbur hamatchil): Frank Ruhl
  /// Libre in full ink, never in techelet.
  TextStyle dibburStyle({bool dimmed = false}) {
    final rashi = style(ScriptureKind.rashi);
    return rashi.copyWith(
      fontFamily: 'FrankRuhlLibre',
      fontFamilyFallback: const ['NotoSerifHebrew'],
      fontWeight: FontWeight.w700,
      color: dimmed ? SeferColors.of(context).dimInk : Theme.of(context).colorScheme.onSurface,
    );
  }

  /// [numberGap] at the system text scale.
  double get numberGapWidth => MediaQuery.textScalerOf(context).scale(numberGap * sizeFor(ScriptureKind.mikra));

  /// The width of the guided reader's verse-number gutter, at the system text
  /// scale: the widest verse number of the Torah, as [numberStyle] sets it
  /// beside the Torah, and [numberGapWidth] between it and the verse. The
  /// same in every layer, so that the text's edge stays put from one reading
  /// to the next.
  double get gutterWidth {
    final scaler = MediaQuery.textScalerOf(context);
    final style = numberStyle(ScriptureKind.mikra);
    if (!_watchingFonts) {
      // Measured again once a font arrives (on the web, the bundled ones
      // too), rather than keep a stand-in's widths.
      _watchingFonts = true;
      PaintingBinding.instance.systemFonts.addListener(_widestNumbers.clear);
    }
    // Keyed by the size the numbers are set at, which is all their widths
    // depend on: a text scale's factor wouldn't do, as the system's may grow
    // small text faster than large (Android 14's).
    final size = scaler.scale(style.fontSize!);
    final widest = _widestNumbers[(size, style.fontWeight)] ??= _widestNumber(style.copyWith(fontSize: size));
    return widest + numberGapWidth;
  }

  /// The widest verse number from 1 to [_mostVerses] in [style], to the
  /// next whole pixel, so that no number wraps for a rounding.
  static double _widestNumber(TextStyle style) {
    // One number to a line: the paragraph is as wide as the widest.
    final painter = TextPainter(
      text: TextSpan(
        text: [for (var n = 1; n <= _mostVerses; n++) HebrewText.gematria(n, punctuate: false)].join('\n'),
        style: style,
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    final width = painter.width.ceilToDouble();
    painter.dispose();
    return width;
  }

  /// [_widestNumber]'s widths, by the size the numbers are set at, at the
  /// system text scale, and their weight.
  static final _widestNumbers = <(double, FontWeight?), double>{};
  static var _watchingFonts = false;

  /// The gutter the guided reader hangs a verse's number in, in a column
  /// [maxWidth] wide: [gutterWidth], or none where numbers are hidden, or
  /// where so wide a gutter would take more than a quarter of each line and
  /// the number leads the first line instead.
  double hangingGutter(double maxWidth) {
    if (!settings.showVerseNumbers) return 0;
    final gutter = gutterWidth;
    return gutter > maxWidth / 4 ? 0 : gutter;
  }

  /// The height for a run of letters [scale] times the size of [base] (the
  /// Masorah's large letters) that sets the run's top no higher above the
  /// baseline than [base]'s own, as a large letter stands in print: above the
  /// line, without pushing it from the one above. Leading split evenly, as
  /// the verse's is, would centre the larger letters' box on the line's and
  /// so raise its top by (scale - 1) / 2 of the font's ascent less its
  /// descent; the run's height takes that back.
  double largeLetterHeight(TextStyle base, double scale, String letters) {
    // At the font's own line height, which a style with no height keeps.
    final natural = TextStyle(
      fontFamily: base.fontFamily,
      fontFamilyFallback: base.fontFamilyFallback,
      fontWeight: base.fontWeight,
      fontSize: 100,
    );
    final painter = TextPainter(text: TextSpan(text: letters, style: natural), textDirection: TextDirection.rtl)..layout();
    final metrics = painter.computeLineMetrics();
    painter.dispose();
    // The font's own ascent and descent, as shares of its size.
    final (ascent, descent) = metrics.isEmpty ? (0.8, 0.2) : (metrics.first.ascent / 100, metrics.first.descent / 100);
    return (base.height! - (scale - 1) * (ascent - descent)) / scale;
  }

  /// The reading column's measure: about 80 characters at the Torah's size
  /// at its widest.
  double get maxLineWidth => switch (settings.lineWidth) {
        LineWidth.narrow => 560,
        LineWidth.medium => 680,
        LineWidth.wide => 880,
      };

  /// The full text's measure in parallel columns: the Torah's column, the
  /// gutter, and the column beside it ([ParallelVerse]).
  static const parallelWidth = 1160.0;

  /// The narrowest pane that sets the full text in parallel columns.
  static const parallelMinPane = 960.0;

  /// The largest the Torah may be, at the system text scale, for its column
  /// to keep a measure of words rather than of one or two.
  static const parallelMaxSize = 34.0;

  /// The width of the reader's pane in [context]'s window: the window's,
  /// within its side insets.
  static double paneWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width - MediaQuery.paddingOf(context).horizontal;

  /// Whether the full text, in a pane [paneWidth] wide, has room to set the
  /// Torah and what goes with it side by side, whether or not the reader has
  /// turned that off: on a wide pane, at a measure other than the narrow one
  /// and a size the column holds.
  bool parallelFits(double paneWidth) =>
      settings.lineWidth != LineWidth.narrow &&
      paneWidth >= parallelMinPane &&
      MediaQuery.textScalerOf(context).scale(sizeFor(ScriptureKind.mikra)) <= parallelMaxSize;

  /// Whether the full text, in a pane [paneWidth] wide, sets the Torah and
  /// what goes with it ([companion]: the Targum, or else the translation)
  /// side by side: where it fits ([parallelFits]), unless the reader has
  /// turned it off.
  bool parallelColumns(double paneWidth, {required bool companion}) =>
      companion && settings.parallelColumns && parallelFits(paneWidth);

  /// The full text's measure: [parallelWidth] in parallel columns, and
  /// otherwise the reading column's.
  double fullTextWidth({required bool parallel}) => parallel ? parallelWidth : maxLineWidth;

  /// The narrowest column, in ems of its text's size, that Auto justifies:
  /// about 20, where a line holds words enough for its spaces to stretch
  /// evenly. At the default sizes, a tablet's or a desktop's single column
  /// has it; a phone's hasn't.
  static const justifyMeasure = 20.0;

  /// Whether a paragraph of [kind] in a column [measure] wide is justified
  /// (§4.7): as the reader chose ([AppSettings.justifyMode]), or, under
  /// Auto, the Hebrew and Aramaic wherever the column is at least
  /// [justifyMeasure] ems of their size at the system text scale, and in
  /// either of the full text's parallel columns ([ParallelVerse]) whatever
  /// their width: the two are decided together, so that neither faces the
  /// gutter with a ragged edge, and they are set side by side only where
  /// each holds a measure of words ([parallelFits]). English, which nothing
  /// hyphenates, keeps its ragged edge unless justified always.
  bool justifies(ScriptureKind kind, double measure) => switch (settings.justifyMode) {
        JustifyMode.always => true,
        JustifyMode.never => false,
        JustifyMode.auto => kind != ScriptureKind.translation &&
            (context.getInheritedWidgetOfExactType<_InParallelColumns>() != null ||
                measure >= justifyMeasure * MediaQuery.textScalerOf(context).scale(sizeFor(kind))),
      };

  /// The alignment of a paragraph of [kind] in a column [measure] wide:
  /// justified where it [justifies], and otherwise flush at its start.
  TextAlign alignFor(ScriptureKind kind, double measure) =>
      justifies(kind, measure) ? TextAlign.justify : TextAlign.start;

  static const _hebrewFallback = ['NotoSerifHebrew', 'NotoSansHebrew', 'NotoSans'];
}

/// Prepares Hebrew for display: applies the vowel/cantillation preferences
/// and keeps line breaks typographically sound.
String displayHebrew(String text, AppSettings s) =>
    keepLinesSound(HebrewText.forDisplay(text, nikud: s.showNikud, teamim: s.showTeamim));

/// [hebrew] as it may break into lines on screen: never with a paseq at a
/// line's start, as it is bound to the word before it, and never between
/// words joined by a maqaf. Only for display: the no-break space and word
/// joiner would travel with a copy. Where the words a maqaf joins are too
/// wide together for a line, [joinWhereFits] parts them.
String keepLinesSound(String hebrew) =>
    hebrew.replaceAll(' ׀', ' ׀').replaceAll('־', '־⁠');

/// [shown], scripture as [keepLinesSound] sets it (and [joinWhereFits] and
/// [holdLastPair] after it), as it is copied: without the no-break spaces and
/// word joiners set for the screen.
String asCopied(String shown) => shown.replaceAll('\u00a0', ' ').replaceAll('\u2060', '');

/// [text], a paragraph of scripture whose words [keepLinesSound] has joined,
/// with the word joiner after a maqaf left out wherever the words it joins
/// would be too wide together for a line [maxWidth] wide, as at a very large
/// reading or text size on a phone. A line may then end after that maqaf, as
/// the text engine allows (U+05BE breaks after), rather than inside a word,
/// which is where a run of joined words too wide for the line would break.
/// Words joined by maqafs one after another stay together as far as they
/// fit: from the first, as many to a line as fit.
///
/// [text] is measured as a [Text] lays it out within [style] (the ambient
/// style it is merged with), at [textScaler], in [locale], with its widgets
/// as large as [placeholders] say, in order (as
/// [TextPainter.setPlaceholderDimensions] takes them).
InlineSpan joinWhereFits(
  InlineSpan text, {
  required double maxWidth,
  required TextScaler textScaler,
  TextStyle? style,
  Locale? locale,
  List<PlaceholderDimensions> placeholders = const [],
}) {
  if (!maxWidth.isFinite) return text;
  final plain = text.toPlainText(includeSemanticsLabels: false);
  // Each run a line can't break inside, between two spaces (the no-break
  // spaces and joiners bind the rest), that holds words joined by a maqaf:
  // where each of those words begins, at the joiner after its maqaf.
  final runs = <(int, int, List<int>)>[];
  for (final run in _unbreakable.allMatches(plain)) {
    final joins = [
      for (var i = run.start + 1; i < run.end; i++)
        if (plain.codeUnitAt(i) == _joiner && plain.codeUnitAt(i - 1) == _maqaf) i,
    ];
    if (joins.isNotEmpty) runs.add((run.start, run.end, joins));
  }
  if (runs.isEmpty) return text;
  // A hair under the line, so that rounding never breaks the words after all.
  final limit = maxWidth - 1;

  // Where every run surely fits, as at ordinary sizes, the paragraph isn't
  // measured.
  final letter = _widestLetter(text, style: style, textScaler: textScaler, placeholders: placeholders);
  bool surelyFits((int, int, List<int>) r) => _letters(plain.substring(r.$1, r.$2)) * letter <= limit;

  if (runs.every(surelyFits)) return text;

  // Laid out on one line, from the left: a word's width is its run's.
  final painter = TextPainter(
    text: TextSpan(style: style, children: [text]),
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.left,
    textScaler: textScaler,
    locale: locale,
  )
    ..setPlaceholderDimensions(placeholders)
    ..layout();
  double width(int start, int end) {
    final boxes = painter.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end));
    if (boxes.isEmpty) return 0;
    return boxes.map((b) => b.right).reduce(math.max) - boxes.map((b) => b.left).reduce(math.min);
  }

  final parted = <int>{};
  for (final (start, end, joins) in runs) {
    var line = width(start, joins.first);
    for (final (k, join) in joins.indexed) {
      final word = width(join, k + 1 < joins.length ? joins[k + 1] : end);
      if (line + word > limit) {
        parted.add(join);
        line = word;
      } else {
        line += word;
      }
    }
  }
  painter.dispose();
  return parted.isEmpty ? text : _without(text, parted);
}

const _maqaf = 0x05BE;
const _joiner = 0x2060;
const _space = 0x20;
final _unbreakable = RegExp('[^ ]+');

/// What takes no room of its own: the points and cantillation, and the
/// joiners and marks of direction.
final _zeroWidth = RegExp('[\u0591-\u05BD\u05BF\u05C1\u05C2\u05C4\u05C5\u05C7\u034F\u200B-\u200F\u2060]');

/// How many of [text]'s characters take room of their own.
int _letters(String text) => text.length - _zeroWidth.allMatches(text).length;

/// The most room one character of [text] can take, as a [Text] lays it out
/// within [style] at [textScaler] (as [joinWhereFits] takes them): an em of
/// its largest type with the widest spacing after it, or where it is a
/// widget, the widest of [placeholders] with that spacing. No run of [text]
/// is wider than this for each of its [_letters].
double _widestLetter(
  InlineSpan text, {
  required TextStyle? style,
  required TextScaler textScaler,
  required List<PlaceholderDimensions> placeholders,
}) {
  var em = 0.0;
  var spacing = 0.0;
  void largest(InlineSpan span, TextStyle inherited) {
    final s = inherited.merge(span.style);
    em = math.max(em, textScaler.scale(s.fontSize ?? kDefaultFontSize));
    spacing = math.max(spacing, math.max(s.letterSpacing ?? 0, 0) + math.max(s.wordSpacing ?? 0, 0));
    if (span is TextSpan) {
      for (final child in span.children ?? const <InlineSpan>[]) {
        largest(child, s);
      }
    }
  }

  largest(text, style ?? const TextStyle());
  return placeholders.fold(em, (w, p) => math.max(w, p.size.width)) + spacing;
}

/// [text], a paragraph of scripture or of what goes with it, with its last
/// two words held together by a no-break space, so that its last line never
/// holds one word alone, wherever the two take no more than half a line
/// [maxWidth] wide: where they take more, the line before would be left
/// short, which is the greater fault. A word is what stands between two
/// spaces (U+0020): words a maqaf joins ([keepLinesSound]) stand as one, as
/// a verse's number does with its first word. The two fit in half a line,
/// and a word joiner binds each hyphen or dash in the last word
/// ("sin-offering."), after which a line could otherwise end: so they
/// never break inside a word, and a paragraph of one line is laid out as it
/// was.
///
/// The no-break space is as wide as the space it stands for: the text engine
/// widens only spaces where a line may break, so it carries the paragraph's
/// word spacing as letter spacing, as a section mark's does. Screen readers
/// hear it as the space it stands for.
///
/// The two words are measured as [joinWhereFits] measures a paragraph, with
/// the same arguments, and only where an em of their largest type for each
/// of their letters might be too wide.
InlineSpan holdLastPair(
  InlineSpan text, {
  required double maxWidth,
  required TextScaler textScaler,
  TextStyle? style,
  Locale? locale,
  List<PlaceholderDimensions> placeholders = const [],
}) {
  if (!maxWidth.isFinite) return text;
  final plain = text.toPlainText(includeSemanticsLabels: false);
  // The last word ends at [end], before any spaces at the paragraph's end,
  // and the spaces before it run from [gap] to [last]; the word before them
  // begins at [start].
  var end = plain.length;
  while (end > 0 && plain.codeUnitAt(end - 1) == _space) {
    end--;
  }
  if (end == 0) return text;
  final last = plain.lastIndexOf(' ', end - 1) + 1;
  if (last == 0) return text;
  var gap = last - 1;
  while (gap > 0 && plain.codeUnitAt(gap - 1) == _space) {
    gap--;
  }
  if (gap == 0) return text;
  final start = plain.lastIndexOf(' ', gap - 1) + 1;
  if (plain.substring(start, end).contains('\n')) return text;

  final half = maxWidth / 2;
  final (pair, widgetsBefore, widgets) = _slice(text, start, end);
  // Each widget is as large as [placeholders] says, if it says.
  if (widgets > 0 && widgetsBefore + widgets > placeholders.length) return text;
  final sized = widgets == 0 ? const <PlaceholderDimensions>[] : placeholders.sublist(widgetsBefore, widgetsBefore + widgets);
  final letter = _widestLetter(pair, style: style, textScaler: textScaler, placeholders: sized);
  if (_letters(plain.substring(start, end)) * letter > half) {
    // Laid out alone, on one line: as wide as the two words are together.
    final painter = TextPainter(
      text: TextSpan(style: style, children: [pair]),
      textDirection: TextDirection.rtl,
      textScaler: textScaler,
      locale: locale,
    )
      ..setPlaceholderDimensions(sized)
      ..layout();
    final width = painter.width;
    painter.dispose();
    if (width > half) return text;
  }
  // Nor may the line break inside the last word, after a hyphen or a dash
  // ("sin-offering."), or before an em dash, which would leave its end
  // alone after all: a word joiner binds each.
  final joins = <int>{
    for (var i = last + 1; i < end; i++)
      if ((_breaksAfter.contains(plain.codeUnitAt(i - 1)) || plain.codeUnitAt(i) == _emDash) &&
          plain.codeUnitAt(i) != _joiner &&
          plain.codeUnitAt(i - 1) != _joiner)
        i,
  };
  return _held(text, {for (var i = gap; i < last; i++) i}, style ?? const TextStyle(), joins: joins);
}

/// The marks a line may break after within a word: a hyphen, an en or em
/// dash, and a maqaf.
const _breaksAfter = {0x2D, 0x2010, 0x2013, _emDash, _maqaf};
const _emDash = 0x2014;

/// What of [span] stands from [start] to [end] of its plain text (in which a
/// widget is one character), in the styles it has there; and how many of
/// [span]'s widgets stand before [start], and how many within.
(InlineSpan, int, int) _slice(InlineSpan span, int start, int end) {
  var at = 0;
  var before = 0;
  var within = 0;
  InlineSpan? cut(InlineSpan span) {
    if (span is! TextSpan) {
      final kept = at >= start && at < end;
      if (at < start) before++;
      if (kept) within++;
      at++;
      return kept ? span : null;
    }
    var text = span.text;
    if (text != null) {
      final from = at;
      at += text.length;
      text = text.substring((start - from).clamp(0, text.length), (end - from).clamp(0, text.length));
    }
    final children = [for (final child in span.children ?? const <InlineSpan>[]) ?cut(child)];
    if ((text == null || text.isEmpty) && children.isEmpty) return null;
    return TextSpan(
      text: text == null || text.isEmpty ? null : text,
      children: children.isEmpty ? null : children,
      style: span.style,
      locale: span.locale,
    );
  }

  return (cut(span) ?? const TextSpan(), before, within);
}

/// [span] with each of the spaces at [offsets] of its plain text (in which a
/// widget is one character) a no-break space as wide, within [style] (the
/// ambient style its own styles merge with), and a word joiner before each
/// character at [joins]. A screen reader hears the space as a space, and
/// nothing of the joiner. A space whose span a [TextSpan.semanticsLabel] or
/// [TextSpan.semanticsIdentifier] speaks for is left as it is; a widget
/// takes no joiner before it.
InlineSpan _held(InlineSpan span, Set<int> offsets, TextStyle style, {Set<int> joins = const {}}) {
  var at = 0;
  InlineSpan hold(InlineSpan span, TextStyle inherited) {
    if (span is! TextSpan) {
      at++;
      return span;
    }
    final s = inherited.merge(span.style);
    final from = at;
    var text = span.text;
    at += text?.length ?? 0;
    final children = [for (final child in span.children ?? const <InlineSpan>[]) hold(child, s)];
    final labelled = span.semanticsLabel != null || span.semanticsIdentifier != null;
    bool spaceAt(int i) => !labelled && offsets.contains(from + i) && text!.codeUnitAt(i) == _space;
    if (text != null && labelled) {
      // What it says is its label's: the joiners go in its text.
      text = String.fromCharCodes([
        for (var i = 0; i < text.length; i++) ...[if (joins.contains(from + i)) _joiner, text.codeUnitAt(i)],
      ]);
    }
    if (text == null || labelled || !Iterable.generate(text.length).any((i) => spaceAt(i) || joins.contains(from + i))) {
      return TextSpan(
        text: text,
        children: span.children == null ? null : children,
        style: span.style,
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        semanticsLabel: span.semanticsLabel,
        semanticsIdentifier: span.semanticsIdentifier,
        locale: span.locale,
        spellOut: span.spellOut,
      );
    }
    // The span's text in pieces, each answering the pointer as it did, and
    // its children after them.
    TextSpan piece(String piece, {TextStyle? style, String? semanticsLabel}) => TextSpan(
          text: piece,
          style: style,
          semanticsLabel: semanticsLabel,
          recognizer: span.recognizer,
          mouseCursor: span.mouseCursor,
          onEnter: span.onEnter,
          onExit: span.onExit,
        );
    final space = TextStyle(letterSpacing: (s.letterSpacing ?? 0) + (s.wordSpacing ?? 0));
    final pieces = <InlineSpan>[];
    var rest = 0;
    for (var i = 0; i < text.length; i++) {
      final join = joins.contains(from + i);
      final held = spaceAt(i);
      if (!join && !held) continue;
      if (i > rest) pieces.add(piece(text.substring(rest, i)));
      rest = i;
      if (join) pieces.add(piece('\u2060', semanticsLabel: ''));
      if (held) {
        pieces.add(piece('\u00A0', style: space, semanticsLabel: ' '));
        rest = i + 1;
      }
    }
    if (rest < text.length) pieces.add(piece(text.substring(rest)));
    return TextSpan(
      children: [...pieces, ...children],
      style: span.style,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      locale: span.locale,
      spellOut: span.spellOut,
    );
  }

  return hold(span, style);
}

/// [span] without the characters at [offsets] of its plain text, in which a
/// widget is one character, as [InlineSpan.toPlainText] writes it.
InlineSpan _without(InlineSpan span, Set<int> offsets) {
  var at = 0;
  InlineSpan strip(InlineSpan span) {
    if (span is! TextSpan) {
      at++;
      return span;
    }
    var text = span.text;
    if (text != null) {
      final start = at;
      at += text.length;
      text = String.fromCharCodes([
        for (var i = 0; i < text.length; i++)
          if (!offsets.contains(start + i)) text.codeUnitAt(i),
      ]);
    }
    return TextSpan(
      text: text,
      children: span.children?.map(strip).toList(),
      style: span.style,
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel,
      semanticsIdentifier: span.semanticsIdentifier,
      locale: span.locale,
      spellOut: span.spellOut,
    );
  }

  return strip(span);
}

/// [text], a paragraph of scripture whose words [keepLinesSound] has joined
/// (or of what goes with it: Rashi, or the translation), laid out by
/// [builder] with only the joins that the width it is given has room for:
/// the joiners after a maqaf ([joinWhereFits]), and the no-break space that
/// holds its last two words together on its last line ([holdLastPair]).
/// [builder] is given that width too, the paragraph's measure, which decides
/// whether it is justified ([ScriptureStyles.alignFor]). [style] and
/// [locale] are the ones [builder] gives its [Text], and [placeholders] size
/// [text]'s widgets.
class JoinsThatFit extends StatelessWidget {
  const JoinsThatFit({
    super.key,
    required this.text,
    required this.builder,
    this.style,
    this.locale,
    this.placeholders = const [],
  });

  final InlineSpan text;
  final TextStyle? style;
  final Locale? locale;
  final List<PlaceholderDimensions> placeholders;
  final Widget Function(BuildContext context, InlineSpan text, double measure) builder;

  @override
  Widget build(BuildContext context) {
    // Measured again when a font arrives.
    FontsChangeScope.watch(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        var effective = DefaultTextStyle.of(context).style.merge(style);
        if (MediaQuery.boldTextOf(context)) effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
        final textScaler = MediaQuery.textScalerOf(context);
        final joined = joinWhereFits(
          text,
          maxWidth: constraints.maxWidth,
          textScaler: textScaler,
          style: effective,
          locale: locale,
          placeholders: placeholders,
        );
        return builder(
          context,
          holdLastPair(
            joined,
            maxWidth: constraints.maxWidth,
            textScaler: textScaler,
            style: effective,
            locale: locale,
            placeholders: placeholders,
          ),
          constraints.maxWidth,
        );
      },
    );
  }
}

/// The text a screen reader should speak for a verse of the Torah or of
/// Targum Onkelos.
String spokenVerse(Verse verse, AppSettings s, {required ScriptureKind kind}) =>
    _spoken(verse.readText, s, targum: kind == ScriptureKind.targum);

/// The same for a verse of the Torah or the Prophets quoted as text, as a
/// question about it quotes it, whose Name may be written ה׳, as Rashi
/// writes it.
String spokenQuotedVerse(String text, AppSettings s) => _spoken(text, s, rashi: true);

/// The text a screen reader should speak for one of Rashi's comments in
/// Hebrew: the words it explains, then the comment.
String spokenRashi(Comment c, AppSettings s) =>
    _spoken(c.heading == null ? c.text : '${c.heading} ${c.text}', s, rashi: true);

/// The same for one of Rashi's comments in English, with the Hebrew it
/// quotes ("בראשית IN THE BEGINNING") tagged as Hebrew. The Hebrew is read
/// as Rashi in Hebrew is, the Divine Name among it ("לפני ה׳ BEFORE THE
/// LORD"); for text-to-speech ([speech]), whatever the screen-reader text.
AttributedString spokenRashiEnglish(Comment c, AppSettings s, {bool speech = false}) {
  final text = c.heading == null ? c.text : '${c.heading} ${c.text}';
  final label = StringBuffer();
  final hebrew = <TextRange>[];
  var from = 0;
  for (final m in _hebrewRun.allMatches(text)) {
    label.write(text.substring(from, m.start));
    final run = speech
        ? HebrewSpeech.spoken(m.group(0)!, divineName: s.divineName, rashi: true)
        : _spoken(m.group(0)!, s, rashi: true);
    hebrew.add(TextRange(start: label.length, end: label.length + run.length));
    label.write(run);
    from = m.end;
  }
  label.write(text.substring(from));
  return AttributedString(label.toString(), attributes: [
    for (final range in hebrew) LocaleStringAttribute(range: range, locale: _hebrew),
  ]);
}

// Hebrew words, with the spaces and punctuation between them.
final _hebrewRun = RegExp('[\u05d0-\u05ea][\u0591-\u05f4\\s"\'.,:;-]*[\u05b0-\u05f4]|[\u05d0-\u05ea]');

String _spoken(String text, AppSettings s, {bool targum = false, bool rashi = false}) => switch (s.screenReaderText) {
      ScreenReaderText.simplified => HebrewSpeech.spoken(text, divineName: s.divineName, targum: targum, rashi: rashi),
      ScreenReaderText.consonants =>
        HebrewSpeech.spoken(text, keepNikud: false, divineName: s.divineName, targum: targum, rashi: rashi),
      ScreenReaderText.allMarks => text,
    };

const _hebrew = Locale('he');

/// One verse of Hebrew or Aramaic, with its number.
class ScriptureVerse extends StatelessWidget {
  const ScriptureVerse({
    super.key,
    required this.verse,
    required this.kind,
    required this.settings,
    this.dimmed = false,
    this.secondary = false,
    this.showNumber = true,
    this.hangingNumber = false,
    this.ruled = false,
    this.onLongPress,
    this.ownGestures = true,
    this.onFocusTap,
    this.bookmarked = false,
    this.hasNote = false,
  });

  final Verse verse;
  final ScriptureKind kind;
  final AppSettings settings;

  /// De-emphasized (focus mode, not the current verse): the whole verse, its
  /// number and ketiv too, in the dimmed ink.
  final bool dimmed;

  /// Supporting text (the Torah beside Rashi, the Targum beneath the verse):
  /// a quieter ink that still meets text contrast requirements.
  final bool secondary;
  final bool showNumber;

  /// The number hangs in a gutter at the verse's start, as in the guided
  /// reader, rather than leading its first line, as in the full text.
  final bool hangingNumber;

  /// Set off by a gold rule at its start (in outline in high contrast), as
  /// the Targum beneath each verse of the full text is.
  final bool ruled;

  /// Opens the verse's options (copy, share, ask): on a long press or a
  /// secondary click, and for screen readers as their own long press and as
  /// the action "Verse options". Null where it has none.
  final VoidCallback? onLongPress;

  /// Whether the verse takes the long press and secondary click itself.
  /// False where the block it stands in takes them for the whole of it
  /// ([VerseGroup], in the full text), so that only the screen readers'
  /// actions are here, on the verse they hear.
  final bool ownGestures;

  /// Focus mode's tap, which moves the focus to this verse, for screen
  /// readers only: the block the verse stands in ([VerseGroup]) takes the
  /// pointer's tap for the whole of it, and the verse offers it where it is
  /// heard. Null outside focus mode.
  final VoidCallback? onFocusTap;

  /// Whether the reader has bookmarked the verse, or written a note on it:
  /// marked after its number ([VerseMarks]) wherever it [showNumber]s, and
  /// said after it to screen readers.
  final bool bookmarked;
  final bool hasNote;

  /// Between the rule and the text.
  static const ruleGap = 12.0;
  static const ruleWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final sefer = SeferColors.of(context);
    // Dimmed text uses its own ink, never a fade: it stays at 4.5:1 or more.
    final dimInk = sefer.dimInk;
    final styles = ScriptureStyles(context, settings);
    final base = styles.style(
      kind,
      color: dimmed ? dimInk : (secondary ? scheme.onSurfaceVariant : null),
    );
    final muted = base.copyWith(
      color: dimmed ? dimInk : scheme.onSurfaceVariant,
      fontSize: base.fontSize! * ScriptureStyles.ketivScale,
    );
    final rubric = styles.rubricStyle(kind, dimmed: dimmed);
    final notes = <String>[];
    final spans = <InlineSpan>[];

    for (final seg in verse.segments) {
      switch (seg) {
        case PlainText(:final text):
          spans.add(TextSpan(text: displayHebrew(text, settings)));
        case KetivQere(:final ketiv, :final qere):
          if (qere.isNotEmpty) spans.add(TextSpan(text: displayHebrew(qere, settings)));
          if (settings.showKetiv && ketiv.isNotEmpty) {
            spans.add(TextSpan(text: qere.isEmpty ? '[$ketiv]' : ' ($ketiv)', style: muted));
          }
        case TextNote(:final text):
          notes.add(text);
          spans.add(TextSpan(text: '*', style: dimmed ? muted : muted.copyWith(color: scheme.primary)));
        case SizedLetters(:final text, :final size):
          final scale = size == LetterSize.large ? 1.45 : 0.72;
          final letters = displayHebrew(text, settings);
          spans.add(TextSpan(
            text: letters,
            style: base.copyWith(
              fontSize: base.fontSize! * scale,
              // A large letter stands above the line, as in print, rather
              // than push the line apart: it reaches no higher above the
              // baseline than the verse's own letters' line box, nor lower.
              height: scale > 1 ? styles.largeLetterHeight(base, scale, letters) : null,
            ),
          ));
        case AlternateReading(:final text):
          spans.add(TextSpan(text: ' (${displayHebrew(text, settings)}) ', style: muted));
        case PisqaGap(:final kind):
          // A section break inside the verse, marked as printed Chumashim
          // mark the scroll's gap: a small letter between full word spaces.
          // The no-break space keeps the mark with the words before it, so
          // it never begins a line. The text engine widens only spaces where
          // a line may break (not this one, nor a space before a word
          // joiner), so this space carries the reader's word spacing as
          // letter spacing. A justified line still stretches only the space
          // after the mark.
          spans.add(TextSpan(children: [
            TextSpan(text: '\u00A0', style: TextStyle(letterSpacing: settings.letterSpacing + settings.wordSpacing)),
            TextSpan(text: kind == SectionBreak.open ? 'פ' : 'ס', style: rubric),
            const TextSpan(text: ' '),
          ]));
      }
    }

    // A screen reader reads the verse as one label, "Verse 9." and then the
    // Hebrew, tagged as Hebrew so that it is read in a Hebrew voice. Where
    // only a whole node can be tagged (the web), the whole label is in
    // Hebrew ("פסוק 9.") and the node itself is tagged.
    final byNode = nodeLanguageOnly;
    final labels = byNode ? lookupAppLocalizations(_hebrew) : l;
    final number = '${verse.ref.verse}';
    final prefix = '${kind == ScriptureKind.targum ? labels.targumVerseLabel(number) : labels.verseLabel(number)}. ';
    final spoken = spokenVerse(verse, settings, kind: kind);
    var label = '$prefix$spoken';
    final hebrewSpans = [TextRange(start: prefix.length, end: label.length)];
    for (final (i, n) in notes.indexed) {
      // The notes are in Hebrew too, and read like the verse: without
      // cantillation, and the Divine Name as chosen.
      label += i == 0 ? '. ' : ' ';
      final spokenNote = _spoken(n, settings);
      final note = labels.noteLabel(spokenNote);
      final start = label.length + note.indexOf(spokenNote);
      hebrewSpans.add(TextRange(start: start, end: start + spokenNote.length));
      label += note;
    }
    final marked = showNumber && (bookmarked || hasNote);
    if (marked) {
      label += [
        if (bookmarked) '. ${labels.verseBookmarked}',
        if (hasNote) '. ${labels.verseWithNote}',
      ].join();
    }

    // The number in gold, joined to the first word by a no-break space so
    // that it never ends a line alone. The space is the verse's, and the
    // text engine widens only spaces where a line may break, so it carries
    // the reader's word spacing as letter spacing, as a section mark's does:
    // the number stands as far from its word as words from each other.
    final numeral = showNumber && settings.showVerseNumbers ? HebrewText.gematria(verse.ref.verse, punctuate: false) : null;
    final numberStyle = styles.numberStyle(kind, dimmed: dimmed);
    final strut = styles.strut(kind);
    // The reader's marks, after the number (or where it would be), in the
    // number's size: the techelet of the scroll's own note marks, receding
    // with a dimmed verse. The text scales them with the text, as the number
    // is scaled, at the number's size.
    final marks = marked
        ? WidgetSpan(
            alignment: PlaceholderAlignment.aboveBaseline,
            baseline: TextBaseline.alphabetic,
            style: TextStyle(fontSize: numberStyle.fontSize),
            child: VerseMarks(
              size: numberStyle.fontSize!,
              bookmarked: bookmarked,
              hasNote: hasNote,
              color: dimmed ? dimInk : scheme.primary,
              lead: numeral != null,
            ),
          )
        : null;

    Widget paragraph({required bool withNumber}) {
      final lead = withNumber && (numeral != null || marks != null);
      // A maqaf's words stay on one line where the line has room for them,
      // and the verse's last two words end it together where they fit in
      // half a line.
      Widget text = JoinsThatFit(
        text: TextSpan(
          style: base,
          children: [
            if (lead) ...[
              if (numeral != null) TextSpan(text: numeral, style: numberStyle),
              // Joined to the number, so that a line never breaks between
              // them.
              if (marks != null) ...[if (numeral != null) const TextSpan(text: '\u2060'), marks],
              TextSpan(text: '\u00A0', style: TextStyle(letterSpacing: settings.letterSpacing + settings.wordSpacing)),
            ],
            ...spans,
          ],
        ),
        placeholders: [
          if (lead && marks != null)
            PlaceholderDimensions(
              // As the text scales them, at the number's size.
              size: VerseMarks.extent(
                MediaQuery.textScalerOf(context).scale(numberStyle.fontSize!),
                bookmarked: bookmarked,
                hasNote: hasNote,
                lead: numeral != null,
              ),
              alignment: PlaceholderAlignment.aboveBaseline,
              baseline: TextBaseline.alphabetic,
            ),
        ],
        builder: (context, fitted, measure) => Text.rich(
          fitted,
          textDirection: TextDirection.rtl,
          textAlign: styles.alignFor(kind, measure),
          strutStyle: strut,
        ),
      );
      if (notes.isNotEmpty) {
        text = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            text,
            for (final n in notes)
              Text('* $n', textDirection: TextDirection.rtl, style: muted.copyWith(height: 1.4)),
          ],
        );
      }
      return text;
    }

    Widget content;
    if (hangingNumber && numeral != null) {
      content = LayoutBuilder(
        builder: (context, constraints) {
          // The gutter is measured: measured again when a font arrives.
          FontsChangeScope.watch(context);
          final gutter = styles.hangingGutter(constraints.maxWidth);
          // At a very large size a gutter would take too much of each line:
          // the number leads the first line instead, as in the full text.
          if (gutter == 0) return paragraph(withNumber: true);
          // The verse begins on the right in either language of the app.
          return Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(
                width: gutter,
                // At the gutter's inner edge, close by its verse, about a
                // word's space from it: the number, and the marks after it,
                // or beneath it where the gutter has no room for both.
                child: Padding(
                  padding: EdgeInsets.only(left: styles.numberGapWidth),
                  child: Text.rich(
                    TextSpan(text: numeral, children: [?marks]),
                    style: numberStyle,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
              Expanded(child: paragraph(withNumber: false)),
            ],
          );
        },
      );
    } else {
      content = paragraph(withNumber: true);
    }

    if (ruled) {
      // At the scripture's start, the right, in either language of the app.
      // Dimmed, it recedes with its verse to a hairline, leaving the gold to
      // the verse being read. High contrast draws it in outline, undimmed: it
      // marks the Targum off from the Torah, which is structure, not
      // decoration (§3.1).
      content = Container(
        padding: const EdgeInsets.only(right: ruleGap),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: sefer.isHighContrast ? scheme.outline : (dimmed ? sefer.hairline : sefer.goldLeaf),
              width: ruleWidth,
            ),
          ),
        ),
        child: content,
      );
    }

    final onLongPress = this.onLongPress;
    if (onLongPress != null && ownGestures) {
      content = GestureDetector(
        // The spaces between its words and lines are the verse's too.
        behavior: HitTestBehavior.opaque,
        onLongPress: () {
          hapticLongPress(context, haptics: settings.haptics);
          onLongPress();
        },
        onSecondaryTap: onLongPress,
        child: content,
      );
    }

    return Semantics(
      container: true,
      // Only where the whole label is Hebrew: elsewhere the node's language
      // would also be given to the English "Verse 9.".
      localeForSubtree: byNode ? _hebrew : null,
      attributedLabel: AttributedString(
        label,
        attributes: [for (final range in hebrewSpans) LocaleStringAttribute(range: range, locale: _hebrew)],
      ),
      textDirection: TextDirection.rtl,
      onTap: onFocusTap,
      onLongPress: onLongPress,
      customSemanticsActions: onLongPress == null ? null : {CustomSemanticsAction(label: l.verseOptions): onLongPress},
      child: ExcludeSemantics(child: content),
    );
  }
}

/// What the reader has marked on a verse, set after its number: a bookmark,
/// a ribbon as tall as the number's letters, and a note, a dot at their
/// middle. [size] is the number's size, at the system text scale; the marks
/// stand on the baseline (a [WidgetSpan] aligned above it) and run right to
/// left, as the verse does. A [lead]ing gap parts them from the number.
class VerseMarks extends StatelessWidget {
  const VerseMarks({
    super.key,
    required this.size,
    required this.bookmarked,
    required this.hasNote,
    required this.color,
    this.lead = true,
  });

  final double size;
  final bool bookmarked;
  final bool hasNote;
  final Color color;
  final bool lead;

  static const _gap = 0.28;
  static const _ribbonWidth = 0.46;
  static const _height = 0.72;
  static const _dot = 0.34;

  /// Its size, for a number [size] large.
  static Size extent(double size, {required bool bookmarked, required bool hasNote, bool lead = true}) {
    final width = (lead ? _gap : 0) +
        (bookmarked ? _ribbonWidth : 0) +
        (bookmarked && hasNote ? _gap : 0) +
        (hasNote ? _dot : 0);
    return Size(width * size, _height * size);
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: extent(size, bookmarked: bookmarked, hasNote: hasNote, lead: lead),
        painter: _VerseMarksPainter(size: size, bookmarked: bookmarked, hasNote: hasNote, color: color, lead: lead),
      ),
    );
  }
}

class _VerseMarksPainter extends CustomPainter {
  const _VerseMarksPainter({
    required this.size,
    required this.bookmarked,
    required this.hasNote,
    required this.color,
    required this.lead,
  });

  final double size;
  final bool bookmarked;
  final bool hasNote;
  final Color color;
  final bool lead;

  @override
  void paint(Canvas canvas, Size box) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    // From the right, where the number is.
    var right = box.width - (lead ? VerseMarks._gap * size : 0);
    if (bookmarked) {
      final w = VerseMarks._ribbonWidth * size;
      final h = box.height;
      final left = right - w;
      canvas.drawPath(
        Path()
          ..moveTo(left, 0)
          ..lineTo(right, 0)
          ..lineTo(right, h)
          ..lineTo(left + w / 2, h - w * 0.42)
          ..lineTo(left, h)
          ..close(),
        paint,
      );
      right = left - VerseMarks._gap * size;
    }
    if (hasNote) {
      final r = VerseMarks._dot * size / 2;
      // At the middle of the number's letters.
      canvas.drawCircle(Offset(right - r, box.height - 0.36 * size), r, paint);
    }
  }

  @override
  bool shouldRepaint(_VerseMarksPainter old) =>
      old.size != size ||
      old.bookmarked != bookmarked ||
      old.hasNote != hasNote ||
      old.color != color ||
      old.lead != lead;
}

/// One verse of the full text with all that goes with it (its Targum,
/// translation and Rashi) as one block, and in focus mode one place to tap
/// (DESIGN_SYSTEM.md §4.7).
///
/// Every block is inset alike, highlighted or not, so that focus mode moves
/// nothing as it moves from verse to verse: the verse being read is set on
/// the paper with a rule in techelet at its start; the others are dimmed by
/// their own text.
class VerseGroup extends StatelessWidget {
  const VerseGroup({
    super.key,
    required this.verse,
    required this.child,
    required this.haptics,
    this.highlighted = false,
    this.onTap,
    this.onLongPress,
  });

  final VerseRef verse;
  final Widget child;

  /// The reader's Haptic feedback, which a long press keeps to
  /// ([hapticLongPress]).
  final bool haptics;

  /// The verse focus mode is on, or the one Listen is reading.
  final bool highlighted;

  /// Focus mode's tap, anywhere in the block. Screen readers find it on its
  /// verses ([ScriptureVerse.onFocusTap]), which they hear: a node of the
  /// block's own would be one with nothing to say.
  final VoidCallback? onTap;

  /// Opens the verse's options, on a long press or a secondary click
  /// anywhere in the block. Screen readers find them on its verses
  /// ([ScriptureVerse.onLongPress]), which they hear.
  final VoidCallback? onLongPress;

  /// Around every block's text: at its start, the right, in either language
  /// of the app, with the rule's width, and as much at its end, so that the
  /// highlight frames lines that run the full measure (the translation, or
  /// justified text) as it frames the rest.
  static const padding = EdgeInsets.fromLTRB(12, 4, 12, 4);

  /// The width of the highlight's rule.
  static const rule = 3.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sefer = SeferColors.of(context);
    return AnimatedContainer(
      duration: Motion.of(context).d(Motion.short),
      curve: Motion.standard,
      // The rule keeps its width when it isn't drawn, so that it moves
      // nothing as it comes and goes. No corner radius: Flutter draws none
      // on a border of one side.
      decoration: BoxDecoration(
        color: highlighted ? sefer.verseHighlight : null,
        border: Border(
          right: BorderSide(
            color: scheme.primary,
            width: rule,
            style: highlighted ? BorderStyle.solid : BorderStyle.none,
          ),
        ),
      ),
      // So that a tap's ink shows over the highlight.
      child: Material(
        type: MaterialType.transparency,
        // Screen readers find focus mode's tap and the verse's options on
        // its verses, where they hear them.
        child: InkWell(
          // A long press is felt as hapticLongPress gives it, not as the
          // platform's pulse; a tap still clicks.
          enableFeedback: false,
          onTap: switch (onTap) {
            final onTap? => () {
                Feedback.forTap(context);
                onTap();
              },
            null => null,
          },
          onLongPress: switch (onLongPress) {
            final onLongPress? => () {
                hapticLongPress(context, haptics: haptics);
                onLongPress();
              },
            null => null,
          },
          onSecondaryTap: onLongPress,
          excludeFromSemantics: true,
          // ↑ and ↓ move from verse to verse: a Tab stop on each would put
          // up to 72 before the button at the end.
          canRequestFocus: false,
          // Outside focus mode a verse is text to read, not a button: no
          // ink for a tap, which does nothing, no wash under the pointer
          // and no hand over it. A long press opens the options at once.
          splashFactory: onTap == null ? NoSplash.splashFactory : null,
          highlightColor: onTap == null ? Colors.transparent : null,
          hoverColor: onTap == null ? Colors.transparent : null,
          mouseCursor: onTap == null ? MouseCursor.defer : null,
          child: Padding(
            padding: padding.copyWith(right: padding.right - rule),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// One verse of the full text in parallel columns, on a wide screen: the
/// Torah's column at the right, as the verse begins in either language of
/// the app, and beside it, across a gutter, the Targum (or the translation),
/// their first lines on one baseline. What else goes with the verse (its
/// translation, Rashi) follows it in its own column.
///
/// Screen readers hear it as they do the verse beneath each other: the
/// verse, what is beside it, and then what follows it.
class ParallelVerse extends StatelessWidget {
  const ParallelVerse({super.key, required this.torah, required this.beside, this.below = const []});

  /// The verse.
  final Widget torah;

  /// The Targum, or the translation where there is no Targum.
  final Widget beside;

  /// What follows the verse in its column, each with the space above it.
  final List<Widget> below;

  /// The columns' shares of the width: the Torah's a little the wider, as
  /// its letters are larger.
  static const torahFlex = 6;
  static const besideFlex = 5;

  /// Between the two columns.
  static const gutter = 40.0;

  @override
  Widget build(BuildContext context) {
    // In the order a screen reader takes them, whatever their place.
    Widget ordered(int order, Widget child) =>
        Semantics(container: true, sortKey: OrdinalSortKey(order.toDouble()), child: child);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      // Its columns justified together (ScriptureStyles.justifies).
      child: _InParallelColumns(
        child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              flex: torahFlex,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ordered(0, torah),
                  for (final (i, child) in below.indexed) ordered(i + 2, child),
                ],
              ),
            ),
            const SizedBox(width: gutter),
            Expanded(
              flex: besideFlex,
              // A verse of one short line is still a target as tall as a
              // finger for its long press: no taller than the verse's own
              // line beside it, which sets the row's height.
              child: ordered(
                1,
                ConstrainedBox(constraints: const BoxConstraints(minHeight: kMinInteractiveDimension), child: beside),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marks what stands in a [ParallelVerse]'s columns, which Auto justifies
/// together ([ScriptureStyles.justifies]).
class _InParallelColumns extends InheritedWidget {
  const _InParallelColumns({required super.child});

  @override
  bool updateShouldNotify(_InParallelColumns oldWidget) => false;
}

/// The heads of the full text's parallel columns ([ParallelVerse]), above
/// its first verse: "Mikra" over the Torah's column and "Targum Onkelos" (or
/// the translation's name) over the other, as eyebrows, each where its text
/// begins, over a hairline as wide as its column. They are inset as the
/// verses' text is within its block ([VerseGroup.padding]).
class ParallelHeading extends StatelessWidget {
  const ParallelHeading({super.key, required this.torah, required this.beside, this.besideDirection = TextDirection.rtl});

  final String torah;
  final String beside;

  /// The direction of the text beside the Torah: the Targum's, right to
  /// left, or the translation's.
  final TextDirection besideDirection;

  @override
  Widget build(BuildContext context) {
    final sefer = SeferColors.of(context);
    // Eyebrows, as the guided reader's layer labels are.
    Widget head(String label, TextDirection direction) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Eyebrow(label, textAlign: direction == TextDirection.rtl ? TextAlign.right : TextAlign.left),
            const SizedBox(height: 6),
            SizedBox(height: sefer.hairlineWidth, child: ColoredBox(color: sefer.hairline)),
          ],
        );
    // Read as one, the Torah's first, whatever the language of the app.
    return Semantics(
      container: true,
      label: '$torah, $beside',
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: VerseGroup.padding.left),
          child: Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: ParallelVerse.torahFlex, child: head(torah, TextDirection.rtl)),
              const SizedBox(width: ParallelVerse.gutter),
              Expanded(flex: ParallelVerse.besideFlex, child: head(beside, besideDirection)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The verse Listen is reading, where it is not one of the full text's
/// blocks (the guided reader and the haftarah): focus mode's highlight, the
/// paper and a techelet rule at the verse's start, the right in either
/// language of the app (§4.7). It is painted [bleed] past the verse, as far
/// as a block of the full text reaches, so that nothing moves as it comes and
/// goes; and the text follows it ([FollowedVerse]).
class SpeakingVerseMark extends StatelessWidget {
  const SpeakingVerseMark({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  /// How far the highlight reaches past the text: as far as [VerseGroup]'s
  /// padding, within the page's side padding and the gap between verses.
  static const bleed = VerseGroup.padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sefer = SeferColors.of(context);
    return FollowedVerse(
      active: active,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: active ? 1 : 0),
        duration: Motion.of(context).d(Motion.short),
        curve: Motion.standard,
        child: child,
        // The same widgets with the highlight or without, so that what
        // [child] holds stays as it comes and goes.
        builder: (context, shown, child) => CustomPaint(
          painter: shown == 0 ? null : _SpeakingPainter(fill: sefer.verseHighlight, rule: scheme.primary, shown: shown),
          child: child,
        ),
      ),
    );
  }
}

class _SpeakingPainter extends CustomPainter {
  const _SpeakingPainter({required this.fill, required this.rule, required this.shown});

  final Color fill;
  final Color rule;

  /// How far it has faded in, from 0 to 1.
  final double shown;

  @override
  void paint(Canvas canvas, Size size) {
    final area = SpeakingVerseMark.bleed.inflateRect(Offset.zero & size);
    if (fill.a > 0) canvas.drawRect(area, Paint()..color = fill.withValues(alpha: fill.a * shown));
    canvas.drawRect(
      Rect.fromLTRB(area.right - VerseGroup.rule, area.top, area.right, area.bottom),
      Paint()..color = rule.withValues(alpha: rule.a * shown),
    );
  }

  @override
  bool shouldRepaint(_SpeakingPainter old) => old.fill != fill || old.rule != rule || old.shown != shown;
}

/// Brings [child] into view as it becomes [active]: the verse Listen has
/// reached, which the text follows. Unless it is in view already, it is
/// scrolled a fifth of the way down the screen, as the verse opened at is,
/// over Motion.medium, or at once under Reduce Motion. Nothing is scrolled
/// under a finger that is scrolling the text.
class FollowedVerse extends StatefulWidget {
  const FollowedVerse({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<FollowedVerse> createState() => _FollowedVerseState();
}

class _FollowedVerseState extends State<FollowedVerse> {
  /// Room kept clear above and below the verse, for its highlight.
  static const _margin = 4.0;

  @override
  void initState() {
    super.initState();
    if (widget.active) _reveal();
  }

  @override
  void didUpdateWidget(FollowedVerse old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _reveal();
  }

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) return;
      final box = context.findRenderObject();
      final position = Scrollable.maybeOf(context)?.position;
      if (box is! RenderBox || !box.hasSize || position == null || position.isScrollingNotifier.value) return;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) return;
      // The scroll offsets that would set its top at the top of the view,
      // and its foot at the foot.
      final top = viewport.getOffsetToReveal(box, 0).offset;
      final foot = viewport.getOffsetToReveal(box, 1).offset;
      final inView = position.pixels <= math.max(position.minScrollExtent, top - _margin) + 0.5 &&
          position.pixels >= math.min(position.maxScrollExtent, foot + _margin) - 0.5;
      if (inView) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.2,
        duration: Motion.of(context).d(Motion.medium),
        curve: Motion.standard,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The head of a chapter, centred as a Chumash sets it (DESIGN_SYSTEM.md
/// §4.7): "פרק ג" in gold between two hairlines and, in the English UI,
/// "Chapter 3" beneath. One heading to a screen reader, in the UI language.
class ChapterHeading extends StatelessWidget {
  const ChapterHeading({super.key, required int this.chapter, required this.settings, this.headingLevel = 2})
      : hebrewName = null,
        name = null;

  /// A head set as a chapter's, naming what begins there: a book's verses in
  /// a haftarah drawn from more than one book, or the second of two
  /// parshiyot read together. Its [hebrewName] in gold and, in the English
  /// UI, its [name] beneath. Screen readers hear [name].
  const ChapterHeading.book({
    super.key,
    required String this.hebrewName,
    required String this.name,
    required this.settings,
    this.headingLevel = 2,
  }) : chapter = null;

  final int? chapter;
  final String? hebrewName;
  final String? name;
  final AppSettings settings;

  /// Its level as a heading: 2, beneath the page's heading, or 3 beneath a
  /// heading of level 2 (the regular haftarah's).
  final int headingLevel;

  static const _rule = 32.0;
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final sefer = SeferColors.of(context);
    final hebrewUi = context.isHebrewUi;
    final chapter = this.chapter;
    final numeral = chapter == null ? '' : HebrewText.gematria(chapter, punctuate: false);
    final english = chapter == null ? name! : l.chapterLabel('$chapter');
    final gold = chapter == null ? hebrewName! : lookupAppLocalizations(_hebrew).chapterLabel(numeral);
    final label = chapter == null || !hebrewUi ? english : l.chapterLabel(numeral);
    // The heading grows with the reading size, but more slowly than the
    // text, so that it never outweighs it.
    final style = SeferType.of(context).hebrewDisplay.copyWith(
          fontSize: 20 * math.sqrt(settings.readingScale),
          fontWeight: sefer.isHighContrast ? FontWeight.w700 : FontWeight.w600,
          color: theme.colorScheme.secondary,
        );
    final rule = SizedBox(
      width: _rule,
      height: sefer.hairlineWidth,
      child: ColoredBox(color: sefer.isHighContrast ? theme.colorScheme.onSurface : sefer.hairline),
    );
    return Semantics(
      header: true,
      headingLevel: headingLevel,
      label: label,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                textDirection: TextDirection.rtl,
                children: [
                  rule,
                  const SizedBox(width: _gap),
                  Flexible(
                    child: Text(
                      gold,
                      style: style,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      locale: _hebrew,
                    ),
                  ),
                  const SizedBox(width: _gap),
                  rule,
                ],
              ),
              if (!hebrewUi)
                Text(
                  english,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The space between two sections of the Torah, and its mark: פ for a
/// petuchah, with more space, or ס for a setumah (DESIGN_SYSTEM.md §4.7).
class SectionGap extends StatelessWidget {
  const SectionGap({super.key, required this.kind, required this.settings});

  final SectionBreak kind;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final open = kind == SectionBreak.open;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: open ? 20 : 10),
      child: SectionBreakMark(
        open ? ornaments.SectionBreak.petuchah : ornaments.SectionBreak.setumah,
        verseSize: ScriptureStyles(context, settings).sizeFor(ScriptureKind.mikra),
      ),
    );
  }
}

/// A verse of English translation (a study aid).
class TranslationVerse extends StatelessWidget {
  const TranslationVerse({super.key, required this.text, required this.number, required this.settings, this.dimmed = false});

  final String text;
  final int number;
  final AppSettings settings;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sefer = SeferColors.of(context);
    final dimInk = sefer.dimInk;
    final styles = ScriptureStyles(context, settings);
    final style = styles.style(ScriptureKind.translation, color: dimmed ? dimInk : null);
    final accessibleFont = settings.uiFont.family != null;
    final bold = settings.boldText || MediaQuery.boldTextOf(context);
    const english = Locale('en');
    return Lang(
      english,
      child: Directionality(
        textDirection: TextDirection.ltr,
        // Its last two words held together, as the verse's are.
        child: JoinsThatFit(
          text: TextSpan(children: [
            TextSpan(
              text: '$number ',
              style: style.copyWith(
                fontWeight: accessibleFont || bold || sefer.isHighContrast ? FontWeight.w700 : FontWeight.w600,
                color: dimmed ? dimInk : theme.colorScheme.secondary,
                // EB Garamond's old-style figures make "1" read as "I".
                fontFeatures: const [FontFeature.liningFigures()],
              ),
            ),
            TextSpan(text: text),
          ]),
          style: style,
          locale: english,
          // Justified only where the reader asks for it always.
          builder: (context, held, measure) => Text.rich(
            held,
            style: style,
            textAlign: styles.alignFor(ScriptureKind.translation, measure),
          ),
        ),
      ),
    );
  }
}

/// Rashi's comments on one verse.
class RashiComments extends StatelessWidget {
  const RashiComments({
    super.key,
    required this.comments,
    required this.settings,
    required this.english,
    this.dimmed = false,
  });

  final List<Comment> comments;
  final AppSettings settings;
  final bool english;

  /// De-emphasized with the rest of its verse (focus mode).
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final styles = ScriptureStyles(context, settings);
    final theme = Theme.of(context);
    final ink = dimmed ? SeferColors.of(context).dimInk : null;
    final kind = english ? ScriptureKind.translation : ScriptureKind.rashi;
    final style = styles.style(kind, color: ink);
    // The words explained in bold full ink (never techelet): Frank Ruhl Libre
    // over Rashi's Hebrew, the comment's own face over English.
    final heading = english
        ? style.copyWith(fontWeight: FontWeight.w700, color: ink ?? theme.colorScheme.onSurface)
        : styles.dibburStyle(dimmed: dimmed);
    final dir = english ? TextDirection.ltr : TextDirection.rtl;
    final locale = english ? const Locale('en') : _hebrew;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in comments.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            // Each comment is one node in its own language, read like a verse
            // (the Divine Name as chosen); its Hebrew label is tagged as well
            // for Android and iOS.
            child: Semantics(
              container: true,
              localeForSubtree: locale,
              attributedLabel: english ? spokenRashiEnglish(c, settings) : _hebrewLabel(c),
              textDirection: dir,
              child: ExcludeSemantics(
                // Its last two words held together, as the verse's are.
                child: JoinsThatFit(
                  text: TextSpan(children: [
                    if (c.heading != null) TextSpan(text: '${c.heading} ', style: heading),
                    TextSpan(text: english ? c.text : HebrewText.forDisplay(c.text, nikud: settings.showNikud, teamim: true)),
                  ]),
                  style: style,
                  locale: locale,
                  builder: (context, held, measure) => Text.rich(
                    held,
                    style: style,
                    textDirection: dir,
                    textAlign: styles.alignFor(kind, measure),
                    strutStyle: english ? null : styles.strut(ScriptureKind.rashi),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  AttributedString _hebrewLabel(Comment c) {
    final label = spokenRashi(c, settings);
    return AttributedString(label, attributes: [
      LocaleStringAttribute(range: TextRange(start: 0, end: label.length), locale: _hebrew),
    ]);
  }
}

/// The eyebrow over Rashi's comments in the full text: "רש״י" over Rashi in
/// Hebrew, at the right, or "Rashi" over Rashi in English, at the left. A
/// screen reader hears it in the UI language.
class RashiEyebrow extends StatelessWidget {
  const RashiEyebrow({super.key, required this.english, this.dimmed = false});

  final bool english;

  /// De-emphasized with the rest of its verse (focus mode): in the dimmed
  /// ink rather than gold.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final locale = english ? const Locale('en') : _hebrew;
    return Semantics(
      label: context.l10n.rashiLabel,
      child: ExcludeSemantics(
        child: Directionality(
          textDirection: english ? TextDirection.ltr : TextDirection.rtl,
          child: Eyebrow(
            lookupAppLocalizations(locale).rashiLabel,
            color: dimmed ? SeferColors.of(context).dimInk : null,
          ),
        ),
      ),
    );
  }
}

/// What goes with a verse in the guided reader (its translation, Rashi, a
/// note or a label), set in at the right by the gutter the verse hangs its
/// number in, so that every block shares the edge its text starts at, as on
/// a chumash's page, with the number alone in the margin (§4.7).
class HangingIndent extends StatelessWidget {
  const HangingIndent({super.key, required this.settings, required this.child});

  final AppSettings settings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The gutter is measured: measured again when a font arrives.
    FontsChangeScope.watch(context);
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: EdgeInsets.only(right: ScriptureStyles(context, settings).hangingGutter(constraints.maxWidth)),
        child: child,
      ),
    );
  }
}

/// A label above a block of text in the guided reader ("Targum Onkelos"): an
/// eyebrow, in gold ink (§3.1).
class LayerLabel extends StatelessWidget {
  const LayerLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Eyebrow(text),
      );
}
