import 'package:flutter/material.dart';

import '../../app/config.dart';
import '../../ui/l10n.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fallbacks.dart';

enum LegalDoc {
  privacy,
  terms,
  guidelines,
  accessibility;

  static LegalDoc fromSlug(String slug) => values.firstWhere((d) => d.name == slug, orElse: () => privacy);
}

/// In-app policies. Kept in the app (not only on a website) so they are
/// available offline and in both languages.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});

  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final he = context.isHebrewUi;
    final title = switch (doc) {
      LegalDoc.privacy => l.privacyTitle,
      LegalDoc.terms => l.termsTitle,
      LegalDoc.guidelines => l.guidelinesTitle,
      LegalDoc.accessibility => l.accessibilityStatement,
    };
    final sections = (he ? _he : _en)[doc]!;
    final contact = AppConfig.supportEmail.isNotEmpty ? AppConfig.supportEmail : '${AppConfig.sourceUrl}/issues';
    return Scaffold(
      appBar: AppBar(leading: homeLeading(context), title: Text(title)),
      body: PageBody(
        children: [
          for (final (heading, body) in sections) ...[
            if (heading.isNotEmpty) SectionHeader(heading),
            SelectableText(
              body.replaceAll('{contact}', contact),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
          ],
        ],
      ),
    );
  }
}

const _en = <LegalDoc, List<(String, String)>>{
  LegalDoc.privacy: [
    ('', 'Shnayim Mikra is built to need as little of your data as possible. Last updated: October 2026.'),
    ('What stays on your device',
        'Your reading progress, streaks, settings and reminders are stored only on your device. The texts are bundled with the app, so reading works fully offline and nothing about what you read is sent anywhere.'),
    ('No tracking',
        'The app contains no advertising, no analytics and no third-party tracking. We do not sell or share data.'),
    ('If you create a community account',
        'Signing in to the community uses your email address, which is used only to sign you in. Your display name and the posts you write are visible to other users. If you choose to sync your progress, it is stored with your account so you can restore it on another device.'),
    ('Deleting your data',
        'You can reset your progress at any time in Settings → Your data. You can delete your community account in Settings → Account & community; this deletes your profile, your posts and any synced progress.'),
    ('Contact', 'Questions or requests: {contact}'),
  ],
  LegalDoc.terms: [
    ('', 'By using Shnayim Mikra you agree to these terms.'),
    ('The app',
        'The app is provided free of charge, as is, to help with the practice of Shnayim Mikra v\'Echad Targum. Calendar calculations are carefully tested, but customs vary: for practical questions, ask your rav.'),
    ('Texts', 'Bundled texts are used under their licenses, listed in About → Texts & sources.'),
    ('Community',
        'You are responsible for what you post. Posts must follow the Community guidelines. Moderators may hide or remove content and suspend accounts that violate them. You can report any post and block any user.'),
    ('Changes', 'These terms may be updated; material changes will be shown in the app.'),
  ],
  LegalDoc.guidelines: [
    ('', 'The community exists to learn the parsha together. Please help keep it a place of Torah, kindness and respect.'),
    ('Speak with derech eretz',
        'Disagree with ideas, never with people. No insults, mockery, harassment or personal attacks.'),
    ('Guard your tongue',
        'No lashon hara, gossip or shaming of individuals or communities. Don\'t share other people\'s private information.'),
    ('Respect sacred text',
        'When writing the Divine Name in posts, please write ה׳ or "Hashem". Quote sources accurately.'),
    ('Stay on topic', 'Keep discussions connected to the parsha, its commentaries and the practice of learning. No advertising or spam.'),
    ('Psak', 'The forums are for learning, not for halachic rulings. For practical questions, ask your rav.'),
    ('Reporting',
        'Use "Report" on any post that breaks these guidelines, and "Block" to stop seeing someone. Moderators review every report.'),
  ],
  LegalDoc.accessibility: [
    ('', 'We want everyone to be able to learn the parsha with this app, including people who use screen readers, magnification, switch access or keyboards, and people with dyslexia or low vision. We aim to meet WCAG 2.2 level AA.'),
    ('What the app offers',
        '• Screen reader support on every platform, with a clean spoken version (cantillation removed) of each verse of the Torah and the Targum, and of each comment of Rashi, tagged as Hebrew; the English translation is tagged as English\n'
            '• A choice of how the Divine Name is spoken, wherever it is written: in the Torah, in the Targum and in Rashi\n'
            '• Reading size up to 500%, on top of your device\'s text size, plus line, word and letter spacing\n'
            '• Light, dark, sepia and two high-contrast themes; bold text; a choice of fonts, including Atkinson Hyperlegible and Lexend\n'
            '• Show or hide vowels and cantillation; focus mode; adjustable line width\n'
            '• Full keyboard support with shortcuts on Windows and the web\n'
            '• Reduce motion and haptics settings; no flashing content\n'
            '• Status is never shown by color alone\n'
            '• Text-to-speech where a Hebrew voice is available'),
    ('Known limitations',
        'Hebrew voices differ between devices and some screen readers do not pronounce pointed Hebrew perfectly. On Windows, Narrator and NVDA cannot switch to a Hebrew voice on their own, because the app has no way to tell them the language of a text there. To hear the Hebrew in a Hebrew voice, choose one in the screen reader\'s settings. Reminders are not available in the web version.'),
    ('Feedback',
        'If something is hard to use, please tell us: {contact}. We aim to respond within five working days.'),
  ],
};

const _he = <LegalDoc, List<(String, String)>>{
  LegalDoc.privacy: [
    ('', 'שניים מקרא בנויה כך שתזדקק למעט ככל האפשר מהמידע שלך. עודכן לאחרונה: אוקטובר 2026.'),
    ('מה נשאר במכשיר שלך',
        'התקדמות הקריאה, הרצפים, ההגדרות והתזכורות נשמרים במכשיר שלך בלבד. הטקסטים כלולים באפליקציה, כך שהקריאה פועלת ללא חיבור לרשת, ושום מידע על מה שקראת אינו נשלח לשום מקום.'),
    ('ללא מעקב', 'אין באפליקציה פרסומות, אנליטיקה או מעקב של צד שלישי. איננו מוכרים או משתפים מידע.'),
    ('אם פתחת חשבון בקהילה',
        'הכניסה לקהילה משתמשת בכתובת הדוא״ל שלך לצורך הכניסה בלבד. שם התצוגה וההודעות שכתבת גלויים למשתמשים אחרים. אם בחרת לסנכרן את ההתקדמות, היא נשמרת עם החשבון כדי שתוכל/י לשחזר אותה במכשיר אחר.'),
    ('מחיקת המידע',
        'אפשר לאפס את ההתקדמות בכל עת בהגדרות ← הנתונים שלך. אפשר למחוק את החשבון בהגדרות ← חשבון וקהילה; פעולה זו מוחקת את הפרופיל, ההודעות וההתקדמות המסונכרנת.'),
    ('יצירת קשר', 'שאלות ובקשות: {contact}'),
  ],
  LegalDoc.terms: [
    ('', 'השימוש בשניים מקרא מהווה הסכמה לתנאים אלה.'),
    ('האפליקציה',
        'האפליקציה ניתנת בחינם, כמות שהיא, לסיוע בקיום שניים מקרא ואחד תרגום. חישובי הלוח נבדקים בקפידה, אך המנהגים שונים: בשאלות מעשיות יש לשאול רב.'),
    ('טקסטים', 'הטקסטים הכלולים משמשים בהתאם לרישיונותיהם, המפורטים באודות ← טקסטים ומקורות.'),
    ('קהילה',
        'כל משתמש אחראי למה שהוא מפרסם. ההודעות חייבות לעמוד בכללי הקהילה. המנהלים רשאים להסתיר או להסיר תוכן ולהשעות חשבונות המפרים אותם. אפשר לדווח על כל הודעה ולחסום כל משתמש.'),
    ('שינויים', 'התנאים עשויים להתעדכן; שינויים מהותיים יוצגו באפליקציה.'),
  ],
  LegalDoc.guidelines: [
    ('', 'הקהילה קיימת כדי ללמוד את הפרשה יחד. עזרו לשמור עליה מקום של תורה, חסד וכבוד.'),
    ('דרך ארץ', 'חולקים על רעיונות, לעולם לא על אנשים. ללא עלבונות, לעג, הטרדה או התקפות אישיות.'),
    ('שמירת הלשון', 'ללא לשון הרע, רכילות או ביוש של אנשים או קהילות. אין לשתף מידע פרטי של אחרים.'),
    ('כבוד לכתבי הקודש', 'בכתיבת שם ה׳ בהודעות, נא לכתוב ה׳ או ״השם״. יש לצטט מקורות במדויק.'),
    ('להישאר בנושא', 'הדיונים צריכים לעסוק בפרשה, במפרשיה ובלימוד. ללא פרסום או ספאם.'),
    ('פסיקה', 'הפורומים נועדו ללימוד ולא לפסיקת הלכה. בשאלות מעשיות יש לשאול רב.'),
    ('דיווח', 'השתמשו ב״דיווח״ על כל הודעה שמפרה את הכללים, וב״חסימה״ כדי להפסיק לראות משתמש. המנהלים בודקים כל דיווח.'),
  ],
  LegalDoc.accessibility: [
    ('', 'אנחנו רוצים שכל אחד יוכל ללמוד את הפרשה באפליקציה, כולל משתמשי קוראי מסך, הגדלה, מתג או מקלדת, ואנשים עם דיסלקציה או ראייה ירודה. היעד שלנו הוא עמידה ב־WCAG 2.2 ברמה AA.'),
    ('מה האפליקציה מציעה',
        '• תמיכה בקוראי מסך בכל הפלטפורמות, עם גרסה מדוברת נקייה (בלי טעמים) של כל פסוק בתורה ובתרגום ושל כל דיבור ברש״י, המסומנת כעברית; התרגום לאנגלית מסומן כאנגלית\n'
            '• בחירה כיצד להגות את השם בכל מקום שהוא כתוב: בתורה, בתרגום וברש״י\n'
            '• גודל קריאה עד 500%, מעבר לגודל הטקסט של המכשיר, וכן ריווח שורות, מילים ואותיות\n'
            '• ערכות בהירה, כהה, ספיה ושתי ערכות בניגודיות גבוהה; טקסט מודגש; מבחר גופנים\n'
            '• הצגה או הסתרה של ניקוד וטעמים; מצב מיקוד; רוחב שורה מתכוונן\n'
            '• תמיכה מלאה במקלדת עם קיצורים ב־Windows ובדפדפן\n'
            '• הפחתת תנועה ומשוב רטט; ללא תוכן מהבהב\n'
            '• מצב לעולם אינו מוצג באמצעות צבע בלבד\n'
            '• הקראה קולית כשקיים קול בעברית'),
    ('מגבלות ידועות',
        'קולות העברית שונים בין מכשירים, וחלק מקוראי המסך אינם הוגים עברית מנוקדת באופן מושלם. ב־Windows, \u200fNarrator ו־NVDA אינם עוברים לקול עברי מעצמם, כי שם אין לאפליקציה דרך לציין להם את שפת הטקסט. כדי לשמוע את העברית בקול עברי, יש לבחור קול כזה בהגדרות קורא המסך. תזכורות אינן זמינות בגרסת הדפדפן.'),
    ('משוב', 'אם משהו קשה לשימוש, נשמח לשמוע: {contact}. נשתדל להשיב תוך חמישה ימי עבודה.'),
  ],
};
