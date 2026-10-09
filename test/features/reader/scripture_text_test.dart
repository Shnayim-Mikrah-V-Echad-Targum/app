import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/data/models/scripture.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';

void main() {
  // Exodus 20:13, unpointed: three commandments with setumah gaps between.
  final decalogue = Verse.fromJson(const VerseRef(20, 13), [
    'לא תרצח׃',
    {'gap': 'S'},
    'לא תנאף׃',
    {'gap': 'S'},
    'לא תגנב׃',
    {'gap': 'S'},
    'לא־תענה ברעך עד שקר׃',
  ]);

  Future<void> pumpVerse(WidgetTester tester, Verse verse) => tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ScriptureVerse(verse: verse, kind: ScriptureKind.mikra, settings: const AppSettings()),
        ),
      ));

  testWidgets('a section gap inside a verse shows a small mark between word spaces', (tester) async {
    await pumpVerse(tester, decalogue);
    final text = tester.widget<RichText>(find.byType(RichText)).text;
    // The no-break space binds each mark to the words before it (and a word
    // joiner keeps the maqaf phrase on one line).
    expect(text.toPlainText(), endsWith('לא תרצח׃\u00A0ס לא תנאף׃\u00A0ס לא תגנב׃\u00A0ס לא־\u2060תענה ברעך עד שקר׃'));

    final marks = <TextSpan>[];
    text.visitChildren((span) {
      if (span is TextSpan && span.text == 'ס') marks.add(span);
      return true;
    });
    expect(marks, hasLength(3));
    final context = tester.element(find.byType(ScriptureVerse));
    expect(marks.first.style?.fontSize, closeTo(ScriptureStyles.baseHebrewSize * 0.62, 0.001));
    expect(marks.first.style?.color, Theme.of(context).colorScheme.onSurfaceVariant);
  });

  testWidgets('a section gap is a plain word space to a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpVerse(tester, decalogue);
    expect(find.bySemanticsLabel('Verse 13. לא תרצח. לא תנאף. לא תגנב. לא תענה ברעך עד שקר.'), findsOneWidget);
    handle.dispose();
  });
}
