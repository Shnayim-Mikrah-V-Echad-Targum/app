import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/text/hebrew_text.dart';
import '../../data/models/scripture.dart';
import '../../ui/l10n.dart';
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

/// The text a screen reader should speak for a verse.
String spokenVerse(Verse verse, AppSettings s) {
  final read = verse.readText;
  return switch (s.screenReaderText) {
    ScreenReaderText.simplified => HebrewSpeech.spoken(read, divineName: s.divineName),
    ScreenReaderText.consonants => HebrewSpeech.spoken(read, keepNikud: false, divineName: s.divineName),
    ScreenReaderText.allMarks => read,
  };
}

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
      }
    }

    final spoken = spokenVerse(verse, settings);
    final prefix = '${l.verseLabel('${verse.ref.verse}')}. ';
    final noteText = notes.map(l.noteLabel).join(' ');
    final label = '$prefix$spoken${noteText.isEmpty ? '' : '. $noteText'}';

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
      attributedLabel: AttributedString(
        label,
        attributes: [
          LocaleStringAttribute(
            range: TextRange(start: prefix.length, end: prefix.length + spoken.length),
            locale: const Locale('he'),
          ),
        ],
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
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$number ', style: style.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
          TextSpan(text: text),
        ]),
        style: style,
        textAlign: settings.justify ? TextAlign.justify : TextAlign.start,
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
      ],
    );
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
