import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fallbacks.dart';
import '../../ui/widgets/ornaments.dart';

class _Source {
  const _Source(this.title, this.description, this.license, this.url);
  final String title;
  final String description;
  final String license;
  final String url;
}

/// Attribution for every bundled text and dataset (required by CC BY-SA and
/// CC BY, and good practice), set as a book's list of sources: a card for
/// each, which opens the source, then where the adapted files are.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final he = context.isHebrewUi;
    final theme = Theme.of(context);
    final sources = [
      _Source(
        he ? 'מקרא על פי המסורה' : 'Miqra according to the Masorah (MAM)',
        l.sourcesMamDescription,
        'CC BY-SA 4.0',
        'https://he.wikisource.org/wiki/%D7%9E%D7%A9%D7%AA%D7%9E%D7%A9:Dovi/%D7%9E%D7%A7%D7%A8%D7%90_%D7%A2%D7%9C_%D7%A4%D7%99_%D7%94%D7%9E%D7%A1%D7%95%D7%A8%D7%94',
      ),
      _Source(
        he ? 'תרגום אונקלוס' : 'Targum Onkelos',
        he ? 'מהדורת תורת אמת, דרך ספריא.' : 'Torat Emet edition, via Sefaria.',
        he ? 'נחלת הכלל' : 'Public domain',
        'https://www.sefaria.org/Onkelos_Genesis',
      ),
      _Source(
        he ? 'פירוש רש״י' : "Rashi's commentary (Hebrew and English)",
        he
            ? 'חמישה חומשי תורה עם פירוש רש״י, מ. רוזנבאום וא.מ. סילברמן, לונדון ${ltr('1929–1934')}, דרך ספריא.'
            : "Pentateuch with Rashi's commentary, M. Rosenbaum and A. M. Silbermann, London 1929–1934, via Sefaria.",
        he ? 'נחלת הכלל' : 'Public domain',
        'https://www.sefaria.org/Rashi_on_Genesis',
      ),
      _Source(
        he ? 'תרגום לאנגלית' : 'English translation',
        he
            ? 'התרגום ${ltr('The Holy Scriptures: A New Translation')} של JPS משנת 1917, דרך פרויקט הסידור הפתוח וספריא.'
            : 'The Holy Scriptures: A New Translation (JPS 1917), via the Open Siddur Project and Sefaria.',
        he ? 'נחלת הכלל' : 'Public domain',
        'https://opensiddur.org/',
      ),
      _Source(
        he ? 'חלוקת עליות והפטרות' : 'Aliyah divisions and haftarah references',
        he ? 'מתוך ${ltr('@hebcal/leyning')} של Hebcal.' : 'From @hebcal/leyning by Hebcal.',
        'BSD-2-Clause',
        'https://github.com/hebcal/hebcal-leyning',
      ),
      _Source(
        he ? 'ערים לזמני השבת' : 'Cities for Shabbat times',
        he
            ? 'ממאגר המידע הגאוגרפי GeoNames: שמות, קואורדינטות ואזורי זמן של המקומות שגרים בהם 100,000 איש ומעלה ושל כל הערים בישראל. נבחרו ועובדו עבור האפליקציה, ונוספו שמות בעברית.'
            : 'From the GeoNames geographical database: the names, coordinates and time zones of places of 100,000 people or more, and of every city in Israel. Selected and adapted for this app, with Hebrew names added.',
        'CC BY 4.0',
        'https://www.geonames.org/',
      ),
      _Source(
        he ? 'זריחה ושקיעה' : 'Sunrise and sunset',
        he
            ? 'מחושבות במכשיר לפי הנוסחאות של מחשבון השמש של NOAA (על פי Meeus, Astronomical Algorithms), ונבדקו מול Hebcal. זמני הדלקת הנרות וצאת השבת כמו ב־Hebcal.'
            : 'Worked out on the device with the formulas of the NOAA Solar Calculator (after Meeus, Astronomical Algorithms), and checked against Hebcal, whose candle-lighting and Havdalah times they follow.',
        he ? 'נחלת הכלל' : 'Public domain',
        'https://gml.noaa.gov/grad/solcalc/',
      ),
    ];
    return PageScaffold(
      leading: homeLeading(context),
      titleText: l.sourcesTitle,
      contentMaxWidth: ContentWidth.longform,
      body: PageBody(
        maxWidth: ContentWidth.longform,
        children: [
          for (final (i, source) in sources.indexed) ...[if (i > 0) const Gap(Rhythm.cardGap), _SourceCard(source)],
          const Gap(Rhythm.sectionGap),
          const SeferDivider(),
          const Gap(Space.lg),
          Text(
            he
                ? 'הטקסטים והנתונים בצורתם המעובדת באפליקציה זו מופצים בתנאי הרישיונות המקוריים. קובצי הנתונים נמצאים בתיקיות ${ltr('assets/text')} ו־${ltr('assets/data')} בקוד המקור.'
                : 'The texts and data as adapted in this app are distributed under their original licenses. The data files are in the assets/⁠text and assets/⁠data folders of the source code.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// A source on a card that opens it: its name, with its license as a small
/// label beside it, then what it is. Read as one link, by its name and
/// license, then what it is.
class _SourceCard extends StatelessWidget {
  const _SourceCard(this.source);

  final _Source source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final padding =
        MediaQuery.sizeOf(context).width < Breakpoints.narrow ? Rhythm.cardPaddingNarrow : Rhythm.cardPadding;
    final titleStyle = theme.textTheme.titleLarge!;
    final titleLine = MediaQuery.textScalerOf(context).scale(titleStyle.fontSize!) * titleStyle.height!;
    return Card(
      // The focus ring is drawn just outside the card, which mustn't clip it;
      // the ink well clips the ink to the card's corners instead.
      clipBehavior: Clip.none,
      child: Semantics(
        link: true,
        label: '${source.title}, ${source.license}',
        child: SeferInkWell(
          onTap: () => launchUrl(Uri.parse(source.url)),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        // The license follows the name, or goes under it
                        // when the two don't fit on a line.
                        child: Wrap(
                          spacing: Space.md,
                          runSpacing: Space.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(source.title, style: titleStyle),
                            _LicenseLabel(source.license),
                          ],
                        ),
                      ),
                      const Gap(Space.md),
                      Padding(
                        // In the middle of the name's first line.
                        padding: EdgeInsets.only(top: math.max(0, (titleLine - 18) / 2)),
                        child: Icon(Icons.open_in_new, size: 18, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const Gap(Space.sm),
                Text(source.description, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A source's license: a small label, not a control.
class _LicenseLabel extends StatelessWidget {
  const _LicenseLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
        child: Text(text, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSecondaryContainer)),
      ),
    );
  }
}
