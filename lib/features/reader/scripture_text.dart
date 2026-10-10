import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/text/hebrew_text.dart';
import '../../data/models/scripture.dart';
import '../../data/models/verse_ref.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
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

  /// The guided reader's hanging verse numbers sit in a gutter this many
  /// times the Torah's size wide, whatever the layer, so the text's edge stays
  /// put from one reading to the next.
  static const gutterScale = 1.4;

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

  /// The width of the guided reader's verse-number gutter, before the system
  /// text scale.
  double get gutterWidth => gutterScale * sizeFor(ScriptureKind.mikra);

  /// The reading column's measure: about 80 characters at the Torah's size
  /// at its widest.
  double get maxLineWidth => switch (settings.lineWidth) {
        LineWidth.narrow => 560,
        LineWidth.medium => 680,
        LineWidth.wide => 880,
      };

  static const _hebrewFallback = ['NotoSerifHebrew', 'NotoSansHebrew', 'NotoSans'];
}

/// Prepares Hebrew for display: applies the vowel/cantillation preferences
/// and keeps line breaks typographically sound.
String displayHebrew(String text, AppSettings s) {
  var out = HebrewText.forDisplay(text, nikud: s.showNikud, teamim: s.showTeamim);
  // Never start a line with a paseq: bind it to the preceding word.
  out = out.replaceAll(' ׀', ' ׀');
  // Keep words joined by a maqaf on one line.
  out = out.replaceAll('־', '־⁠');
  return out;
}

/// The text a screen reader should speak for a verse of the Torah or of
/// Targum Onkelos.
String spokenVerse(Verse verse, AppSettings s, {required ScriptureKind kind}) =>
    _spoken(verse.readText, s, targum: kind == ScriptureKind.targum);

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

  /// Set off by a gold rule at its start, as the Targum beneath each verse of
  /// the full text is.
  final bool ruled;

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
          spans.add(TextSpan(
            text: displayHebrew(text, settings),
            style: base.copyWith(
              fontSize: base.fontSize! * scale,
              // A large letter stands above the line, as in print, rather
              // than push the line apart: its line box is the verse's own.
              height: scale > 1 ? base.height! / scale : null,
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

    // The number in gold, joined to the first word by a no-break space so
    // that it never ends a line alone.
    final numeral = showNumber && settings.showVerseNumbers ? HebrewText.gematria(verse.ref.verse, punctuate: false) : null;
    final numberStyle = styles.numberStyle(kind, dimmed: dimmed);
    final strut = styles.strut(kind);

    Widget paragraph({required bool withNumber}) {
      Widget text = Text.rich(
        TextSpan(
          style: base,
          children: [
            if (withNumber && numeral != null) TextSpan(text: '$numeral\u00A0', style: numberStyle),
            ...spans,
          ],
        ),
        textDirection: TextDirection.rtl,
        textAlign: settings.justify ? TextAlign.justify : TextAlign.start,
        strutStyle: strut,
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
          final gutter = MediaQuery.textScalerOf(context).scale(styles.gutterWidth);
          // At a very large size a gutter would take too much of each line:
          // the number leads the first line instead, as in the full text.
          if (gutter > constraints.maxWidth / 4) return paragraph(withNumber: true);
          // The verse begins on the right in either language of the app.
          return Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(width: gutter, child: Text(numeral, style: numberStyle, textDirection: TextDirection.rtl)),
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
      // High contrast keeps the inset but not the rule, a decoration (§3.1).
      content = Container(
        padding: const EdgeInsets.only(right: ruleGap),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: sefer.goldLeaf,
              width: ruleWidth,
              style: sefer.isHighContrast ? BorderStyle.none : BorderStyle.solid,
            ),
          ),
        ),
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
      child: ExcludeSemantics(child: content),
    );
  }
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
  const VerseGroup({super.key, required this.verse, required this.child, this.highlighted = false, this.onTap});

  final VerseRef verse;
  final Widget child;

  /// The verse focus mode is on.
  final bool highlighted;
  final VoidCallback? onTap;

  /// Around every block's text: at its start, the right, in either language
  /// of the app, with the rule's width, and as much at its end, so that the
  /// highlight frames lines that run the full measure (the translation, or
  /// justified text) as it frames the rest.
  static const padding = EdgeInsets.fromLTRB(12, 4, 12, 4);
  static const _rule = 3.0;

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
            width: _rule,
            style: highlighted ? BorderStyle.solid : BorderStyle.none,
          ),
        ),
      ),
      // So that a tap's ink shows over the highlight.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          // ↑ and ↓ move from verse to verse: a Tab stop on each would put
          // up to 72 before the button at the end.
          canRequestFocus: false,
          child: Padding(
            padding: padding.copyWith(right: padding.right - _rule),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The head of a chapter, centred as a Chumash sets it (DESIGN_SYSTEM.md
/// §4.7): "פרק ג" in gold between two hairlines and, in the English UI,
/// "Chapter 3" beneath. One heading to a screen reader, in the UI language.
class ChapterHeading extends StatelessWidget {
  const ChapterHeading({super.key, required this.chapter, required this.settings});

  final int chapter;
  final AppSettings settings;

  static const _rule = 32.0;
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final sefer = SeferColors.of(context);
    final hebrewUi = context.isHebrewUi;
    final numeral = HebrewText.gematria(chapter, punctuate: false);
    final english = l.chapterLabel('$chapter');
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
      headingLevel: 2,
      label: hebrewUi ? l.chapterLabel(numeral) : english,
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
                      lookupAppLocalizations(_hebrew).chapterLabel(numeral),
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
    final style = ScriptureStyles(context, settings).style(ScriptureKind.translation, color: dimmed ? dimInk : null);
    final accessibleFont = settings.uiFont.family != null;
    final bold = settings.boldText || MediaQuery.boldTextOf(context);
    return Lang(
      const Locale('en'),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Text.rich(
          TextSpan(children: [
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
          textAlign: settings.justify ? TextAlign.justify : TextAlign.start,
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
    final style = styles.style(english ? ScriptureKind.translation : ScriptureKind.rashi, color: ink);
    // The words explained in bold full ink (never techelet): Frank Ruhl Libre
    // over Rashi's Hebrew, the comment's own face over English.
    final heading = english
        ? style.copyWith(fontWeight: FontWeight.w700, color: ink ?? theme.colorScheme.onSurface)
        : styles.dibburStyle(dimmed: dimmed);
    final dir = english ? TextDirection.ltr : TextDirection.rtl;
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
              localeForSubtree: english ? const Locale('en') : _hebrew,
              attributedLabel: english ? spokenRashiEnglish(c, settings) : _hebrewLabel(c),
              textDirection: dir,
              child: ExcludeSemantics(
                child: Text.rich(
                  TextSpan(children: [
                    if (c.heading != null) TextSpan(text: '${c.heading} ', style: heading),
                    TextSpan(text: english ? c.text : HebrewText.forDisplay(c.text, nikud: settings.showNikud, teamim: true)),
                  ]),
                  style: style,
                  textDirection: dir,
                  textAlign: settings.justify ? TextAlign.justify : TextAlign.start,
                  strutStyle: english ? null : styles.strut(ScriptureKind.rashi),
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
  const RashiEyebrow({super.key, required this.english});

  final bool english;

  @override
  Widget build(BuildContext context) {
    final locale = english ? const Locale('en') : _hebrew;
    return Semantics(
      label: context.l10n.rashiLabel,
      child: ExcludeSemantics(
        child: Directionality(
          textDirection: english ? TextDirection.ltr : TextDirection.rtl,
          child: Eyebrow(lookupAppLocalizations(locale).rashiLabel),
        ),
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
