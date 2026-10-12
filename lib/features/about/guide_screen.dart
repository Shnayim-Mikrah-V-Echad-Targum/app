import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fallbacks.dart';
import '../../ui/widgets/lang.dart';
import '../../ui/widgets/lines.dart';
import '../../ui/widgets/ornaments.dart';

/// A short, sourced explanation of the practice and how the app supports it,
/// set as long-form reading (docs/DESIGN_SYSTEM.md §9): the Talmud's words
/// that it rests on, then how to use the app, the practice, the reading, and
/// the special cases and days, each part under a divider, and the sources it
/// comes from.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final type = SeferType.of(context);
    Widget paragraph(String text) => _Selectable(text, style: type.longformBody);
    // The parts of the guide, a divider between each: using the app; what
    // the practice is and when; how to read; the special cases and days; and
    // the sources. Each section is a heading and what follows it.
    final parts = <List<(String, List<Widget>)>>[
      [(l.guideAppTitle, [_Items(l.guideAppBody, style: type.longformBody, spacing: Space.sm)])],
      [(l.guideWhatTitle, [paragraph(l.guideWhatBody)]), (l.guideWhenTitle, [paragraph(l.guideWhenBody)])],
      [
        (l.guideHowTitle, [const _Passes(), paragraph(l.guideHowBody)]),
        (l.guideTargumTitle, [paragraph(l.guideTargumBody)]),
      ],
      [
        (l.guideSpecialTitle, [_Items(l.guideSpecialBody, style: type.longformBody, spacing: Space.sm, leadIns: true)]),
        (l.guideShabbatTitle, [paragraph(l.guideShabbatBody)]),
      ],
      [(l.guideSourcesTitle, [_Items(l.guideSourcesBody, style: type.marginalia, spacing: Space.xs)])],
    ];
    return PageScaffold(
      leading: homeLeading(context),
      titleText: l.guideTitle,
      contentMaxWidth: ContentWidth.longform,
      body: PageBody(
        maxWidth: ContentWidth.longform,
        children: [
          const Gap(Space.sm),
          const _Quote(),
          for (final (i, part) in parts.indexed) ...[
            if (i > 0) ...[const Gap(Rhythm.sectionGap + Space.xs), const SeferDivider()],
            for (final (title, body) in part) ...[_Heading(title), ...body],
          ],
          const Gap(Rhythm.sectionGap),
          NoticeBanner(icon: Icons.info_outline, text: l.disclaimer),
        ],
      ),
    );
  }
}

/// A heading of the guide: long-form, in ink.
class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Rhythm.sectionGap + Space.xs, bottom: Space.sm),
        child: Semantics(
          header: true,
          headingLevel: 2,
          child: Text(text, style: SeferType.of(context).longformHeading),
        ),
      );
}

/// The Talmud's words that the practice rests on, in pointed Hebrew, with
/// where they are written and, in the English UI, what they say.
class _Quote extends StatelessWidget {
  const _Quote();

  /// Its two phrases, each set on a line of its own, or evenly over two
  /// where the line is too short for it.
  static const _phrases = [
    'לְעוֹלָם יַשְׁלִים אָדָם פָּרָשִׁיּוֹתָיו עִם הַצִּבּוּר,',
    'שְׁנַיִם מִקְרָא וְאֶחָד תַּרְגּוּם',
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final words = TextStyle(
      fontFamily: 'NotoSerifHebrew',
      fontSize: 24,
      height: 1.6,
      // Its own spacing, never the card's: the lines are balanced by measure.
      letterSpacing: 0,
      wordSpacing: 0,
      leadingDistribution: TextLeadingDistribution.even,
      color: scheme.onSurface,
    );
    // The card's own padding (20, 16 under 360 dp), and a little more air
    // above and below the words.
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(Space.xs),
          Lang(
            const Locale('he'),
            child: Semantics(
              // One sentence for screen readers, as it is written.
              label: _phrases.join(' '),
              excludeSemantics: true,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final phrase in _phrases) BalancedText(phrase, style: words)],
                ),
              ),
            ),
          ),
          const Gap(Space.sm),
          Text(
            l.guideQuoteSource,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(color: scheme.secondary),
          ),
          if (!context.isHebrewUi) ...[
            const Gap(Space.md),
            BalancedText(l.guideQuoteTranslation, style: SeferType.of(context).marginalia),
          ],
          const Gap(Space.xs),
        ],
      ),
    );
  }
}

/// The three readings, as the pips show them on every aliyah: the text
/// twice, then the Targum. For the eye alone; the text beneath says it.
class _Passes extends StatelessWidget {
  const _Passes();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium!.copyWith(color: theme.colorScheme.onSurfaceVariant);
    // The pips sit in the middle of the caption's first line.
    final line = MediaQuery.textScalerOf(context).scale(style.fontSize!) * style.height!;
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(top: Space.xs, bottom: Space.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: math.max(0, (line - PassPips.full) / 2)),
              child: const PassPips(states: [PipState.done, PipState.done, PipState.done]),
            ),
            const Gap(Space.md),
            Flexible(child: Text(context.l10n.guidePassesCaption, style: style)),
          ],
        ),
      ),
    );
  }
}

/// A list of the guide's, one item to a line of [text], each after a small
/// lozenge (6 at the text's own size), its wrapped lines hanging from the
/// lozenge rather than running back under it, and [spacing] between items.
///
/// With [leadIns], an item's words up to its first colon are its lead-in,
/// heavier than the rest, or where the rest is Bold already, on a line of its
/// own, so that the cases can be found at a glance.
class _Items extends StatelessWidget {
  const _Items(this.text, {required this.style, required this.spacing, this.leadIns = false});

  final String text;
  final TextStyle style;
  final double spacing;
  final bool leadIns;

  static const _lozenge = 6.0;

  @override
  Widget build(BuildContext context) {
    // The lozenge grows with the text, and sits in the middle of its item's
    // first line.
    final size = MediaQuery.textScalerOf(context).scale(style.fontSize!);
    final lozenge = _lozenge * size / style.fontSize!;
    final line = size * style.height!;
    final items = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0) Gap(spacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: (line - lozenge) / 2),
                child: Lozenge(size: lozenge),
              ),
              const Gap(Space.md),
              Expanded(child: _Selectable(item, style: style, leadIn: leadIns)),
            ],
          ),
        ],
      ],
    );
  }
}

/// Text of the guide's that can be selected and copied, in [style], set in
/// bold where Bold text is on, as [Text] would be by itself.
///
/// With [leadIn], its words up to its first colon are its lead-in, set apart
/// from the rest so that it can be found at a glance (see [leadInWeight]).
class _Selectable extends StatelessWidget {
  const _Selectable(this.text, {required this.style, this.leadIn = false});

  final String text;
  final TextStyle style;
  final bool leadIn;

  /// A lead-in's weight over a [body] that is lighter than Bold: Semibold
  /// over EB Garamond's Medium, and Bold over anything else, the next weight
  /// bundled that shows as a step: over Frank Ruhl Libre's Medium (whose
  /// Semibold barely does at this size), high contrast's Semibold serifs, or
  /// an accessibility font's Regular. Null where the body is Bold already
  /// (Bold text, or Frank Ruhl Libre in high contrast): no weight is left to
  /// set the lead-in apart, so it stands on a line of its own instead.
  static FontWeight? leadInWeight(TextStyle body) {
    final weight = body.fontWeight ?? FontWeight.w400;
    if (weight.value >= FontWeight.w700.value) return null;
    return weight == FontWeight.w500 && body.fontFamily == 'EBGaramond' ? FontWeight.w600 : FontWeight.w700;
  }

  @override
  Widget build(BuildContext context) {
    final body = MediaQuery.boldTextOf(context) ? style.merge(const TextStyle(fontWeight: FontWeight.bold)) : style;
    final colon = leadIn ? text.indexOf(': ') : -1;
    if (colon < 0) return SelectableText(text, style: body);
    final weight = leadInWeight(body);
    final lead = text.substring(0, colon + 1);
    final rest = text.substring(colon + 1);
    return SelectableText.rich(
      TextSpan(children: [
        if (weight != null) ...[
          TextSpan(text: lead, style: TextStyle(fontWeight: weight)),
          TextSpan(text: rest),
        ] else ...[
          TextSpan(text: '$lead\n'),
          TextSpan(text: rest.trimLeft()),
        ],
      ]),
      style: body,
    );
  }
}
