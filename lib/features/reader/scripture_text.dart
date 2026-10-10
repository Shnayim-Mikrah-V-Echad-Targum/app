import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/text/hebrew_text.dart';
import '../../data/models/scripture.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/l10n.dart';
import '../../ui/widgets/lang.dart';
import '../settings/app_settings.dart';

/// Which kind of text is being rendered, for sizing and styling.
enum ScriptureKind { mikra, targum, rashi, translation }

/// Text styles for scripture, derived from the reader's settings. The
/// in-app reading size multiplies the system text scale (applied by Text).
class ScriptureStyles {
  ScriptureStyles(this.context, this.settings);

  final BuildContext context;
  final AppSettings settings;

  static const baseHebrewSize = 26.0;
  static const baseEnglishSize = 17.0;

  double sizeFor(ScriptureKind kind) => switch (kind) {
        ScriptureKind.mikra => baseHebrewSize,
        ScriptureKind.targum => baseHebrewSize * 0.92,
        ScriptureKind.rashi => baseHebrewSize * 0.78,
        ScriptureKind.translation => baseEnglishSize,
      } *
      settings.readingScale;

  TextStyle style(ScriptureKind kind, {Color? color}) {
    final theme = Theme.of(context);
    final bold = settings.boldText || MediaQuery.boldTextOf(context);
    final hebrew = kind != ScriptureKind.translation;
    return TextStyle(
      fontFamily: hebrew ? settings.scriptureFont.family : settings.uiFont.family ?? 'NotoSans',
      fontFamilyFallback: const ['NotoSerifHebrew', 'NotoSansHebrew', 'NotoSans'],
      fontSize: sizeFor(kind),
      // Pointed and cantillated text needs generous leading, split evenly
      // above and below so lower marks are never clipped.
      height: hebrew ? settings.lineHeight : 1.5,
      leadingDistribution: TextLeadingDistribution.even,
      wordSpacing: settings.wordSpacing,
      letterSpacing: settings.letterSpacing,
      // Taamey Frank has only a Medium weight (its Bold hides the cantillation),
      // so it is never asked for bold.
      fontWeight: bold && settings.scriptureFont != ScriptureFont.taameyFrank ? FontWeight.w700 : FontWeight.w400,
      color: color ?? theme.colorScheme.onSurface,
    );
  }

  double get maxLineWidth => switch (settings.lineWidth) {
        LineWidth.narrow => 560,
        LineWidth.medium => 760,
        LineWidth.wide => 1040,
      };
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
    this.highlighted = false,
    this.showNumber = true,
  });

  final Verse verse;
  final ScriptureKind kind;
  final AppSettings settings;

  /// De-emphasized (focus mode, not the current verse).
  final bool dimmed;

  /// Supporting text (e.g. the Targum beneath the verse): a quieter color
  /// that still meets text contrast requirements.
  final bool secondary;
  final bool highlighted;
  final bool showNumber;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final styles = ScriptureStyles(context, settings);
    final base = styles.style(
      kind,
      color: dimmed
          ? theme.colorScheme.onSurface.withValues(alpha: 0.55)
          : (secondary ? theme.colorScheme.onSurfaceVariant : null),
    );
    final muted = base.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: dimmed ? 0.55 : 1),
      fontSize: base.fontSize! * 0.62,
    );
    // Petuchah and setumah marks are rubrics, drawn like SectionBreakMark
    // (DESIGN_SYSTEM.md §7.3) so that marks inside and between verses match.
    final rubric = base.copyWith(
      color: theme.colorScheme.secondary.withValues(alpha: dimmed ? 0.55 : 1),
      fontSize: base.fontSize! * 0.55,
      fontWeight: FontWeight.w600,
    );
    final notes = <String>[];
    final spans = <InlineSpan>[];

    if (showNumber && settings.showVerseNumbers) {
      spans.add(TextSpan(
        text: '${HebrewText.gematria(verse.ref.verse, punctuate: false)} ',
        style: base.copyWith(
          fontSize: base.fontSize! * 0.6,
          color: theme.colorScheme.primary.withValues(alpha: dimmed ? 0.55 : 1),
          fontWeight: FontWeight.w700,
        ),
      ));
    }

    for (final seg in verse.segments) {
      switch (seg) {
        case PlainText(:final text):
          spans.add(TextSpan(text: displayHebrew(text, settings)));
        case KetivQere(:final ketiv, :final qere):
          if (qere.isNotEmpty) spans.add(TextSpan(text: displayHebrew(qere, settings)));
          if (settings.showKetiv && ketiv.isNotEmpty) {
            spans.add(TextSpan(text: qere.isEmpty ? '[$ketiv]' : ' ($ketiv)', style: muted));
          }
        case TextNote(:final text):
          notes.add(text);
          spans.add(TextSpan(text: '*', style: muted.copyWith(color: theme.colorScheme.primary)));
        case SizedLetters(:final text, :final size):
          spans.add(TextSpan(
            text: displayHebrew(text, settings),
            style: base.copyWith(
              fontSize: base.fontSize! * (size == LetterSize.large ? 1.45 : 0.72),
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

    Widget text = Text.rich(
      TextSpan(children: spans, style: base),
      textDirection: TextDirection.rtl,
      textAlign: settings.justify ? TextAlign.justify : TextAlign.start,
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
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: highlighted ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: highlighted ? 8 : 0, vertical: 4),
            child: text,
          ),
        ),
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
    final style = ScriptureStyles(context, settings).style(
      ScriptureKind.translation,
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: dimmed ? 0.55 : 1),
    );
    return Lang(
      const Locale('en'),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '$number ', style: style.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
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
  const RashiComments({super.key, required this.comments, required this.settings, required this.english});

  final List<Comment> comments;
  final AppSettings settings;
  final bool english;

  @override
  Widget build(BuildContext context) {
    final styles = ScriptureStyles(context, settings);
    final theme = Theme.of(context);
    final style = english
        ? styles.style(ScriptureKind.translation)
        : styles.style(ScriptureKind.rashi).copyWith(height: 1.7);
    final dir = english ? TextDirection.ltr : TextDirection.rtl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in comments)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
                    if (c.heading != null)
                      TextSpan(
                        text: '${c.heading} ',
                        style: style.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                      ),
                    TextSpan(text: english ? c.text : HebrewText.forDisplay(c.text, nikud: settings.showNikud, teamim: true)),
                  ]),
                  style: style,
                  textDirection: dir,
                  textAlign: settings.justify ? TextAlign.justify : TextAlign.start,
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

/// A small label above a block of text ("Targum Onkelos").
class LayerLabel extends StatelessWidget {
  const LayerLabel(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 6)],
          Text(text, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
        ],
      ),
    );
  }
}
