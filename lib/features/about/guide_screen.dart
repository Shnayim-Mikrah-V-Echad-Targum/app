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
/// that it rests on, then the practice, the reading and the special days,
/// each part under a divider, and the sources it comes from.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final type = SeferType.of(context);
    // The parts of the guide, a divider between each: what the practice is
    // and when; how to read; and the special days.
    final parts = [
      [(l.guideWhatTitle, l.guideWhatBody, null), (l.guideWhenTitle, l.guideWhenBody, null)],
      [(l.guideHowTitle, l.guideHowBody, const _Passes()), (l.guideTargumTitle, l.guideTargumBody, null)],
      [(l.guideSpecialTitle, l.guideSpecialBody, null), (l.guideShabbatTitle, l.guideShabbatBody, null)],
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
            for (final (title, body, lead) in part) ...[
              _Heading(title),
              ?lead,
              SelectableText(body, style: type.longformBody),
            ],
          ],
          const Gap(Rhythm.sectionGap + Space.xs),
          const SeferDivider(),
          _Heading(l.guideSourcesTitle),
          const _Sources(),
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
    return InfoCard(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xxl, Space.xxl, Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

/// The guide's sources, one to a line, each after a small lozenge.
class _Sources extends StatelessWidget {
  const _Sources();

  @override
  Widget build(BuildContext context) {
    final style = SeferType.of(context).marginalia;
    // The lozenge sits in the middle of its line's first line.
    final line = MediaQuery.textScalerOf(context).scale(style.fontSize!) * style.height!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final source in context.l10n.guideSourcesBody.split('\n'))
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: (line - 6) / 2),
                  child: const Lozenge(size: 6),
                ),
                const Gap(Space.md),
                Expanded(child: SelectableText(source, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}
