import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ui/l10n.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fallbacks.dart';

class _Source {
  const _Source(this.title, this.description, this.license, this.url);
  final String title;
  final String description;
  final String license;
  final String url;
}

/// Attribution for every bundled text and dataset (required by CC BY-SA and
/// CC BY, and good practice).
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final he = context.isHebrewUi;
    final sources = [
      _Source(
        he ? 'מקרא על פי המסורה' : 'Miqra according to the Masorah (MAM)',
        he
            ? 'נוסח התורה וההפטרות, על פי כתר ארם צובה וכתבי יד קרובים, בעריכת אבי קדיש וחבריו בוויקיטקסט העברי, דרך ספריא. הותאם לתצוגה מובנית ללא שינוי בנוסח.'
            : 'Hebrew text of the Torah and haftarot, based on the Aleppo Codex and related manuscripts, edited by Avi Kadish and collaborators on Hebrew Wikisource, via Sefaria. Converted to a structured format without changing the text.',
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
            ? 'חמישה חומשי תורה עם פירוש רש״י, מ. רוזנבאום וא.מ. סילברמן, לונדון 1929–1934, דרך ספריא.'
            : "Pentateuch with Rashi's commentary, M. Rosenbaum and A. M. Silbermann, London 1929–1934, via Sefaria.",
        he ? 'נחלת הכלל' : 'Public domain',
        'https://www.sefaria.org/Rashi_on_Genesis',
      ),
      _Source(
        he ? 'תרגום לאנגלית' : 'English translation',
        he
            ? 'The Holy Scriptures: A New Translation, JPS 1917, דרך פרויקט הסידור הפתוח וספריא.'
            : 'The Holy Scriptures: A New Translation (JPS 1917), via the Open Siddur Project and Sefaria.',
        he ? 'נחלת הכלל' : 'Public domain',
        'https://opensiddur.org/',
      ),
      _Source(
        he ? 'חלוקת עליות והפטרות' : 'Aliyah divisions and haftarah references',
        he ? 'מתוך @hebcal/leyning של Hebcal.' : 'From @hebcal/leyning by Hebcal.',
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
    return Scaffold(
      appBar: AppBar(leading: homeLeading(context), title: Text(l.sourcesTitle)),
      body: PageBody(
        children: [
          for (final s in sources)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              // Its heading, text and link each a node of their own.
              semanticContainer: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, headingLevel: 2, child: Text(s.title, style: Theme.of(context).textTheme.titleMedium)),
                    const Gap(4),
                    Text(s.description),
                    const Gap(8),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(label: Text(s.license)),
                        TextButton.icon(
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: Text(l.actionLearnMore),
                          onPressed: () => launchUrl(Uri.parse(s.url)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Text(
            he
                ? 'הטקסטים והנתונים בצורתם המעובדת באפליקציה זו מופצים בתנאי הרישיונות המקוריים. קובצי הנתונים נמצאים בתיקיות assets/\u2060text ו־assets/\u2060data בקוד המקור.'
                : 'The texts and data as adapted in this app are distributed under their original licenses. The data files are in the assets/\u2060text and assets/\u2060data folders of the source code.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
