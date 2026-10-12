import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/config.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/widgets/app_mark.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';

import '../../helpers.dart';

void main() {
  Future<void> openAbout(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.english,
    double width = 412,
    double height = 1600,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: AppSettings(onboardingComplete: true, language: language));
    c.read(routerProvider).go('/settings/about');
    await tester.pumpAndSettle();
  }

  for (final language in [AppLanguage.english, AppLanguage.hebrew]) {
    testWidgets('About names the app in Hebrew, and in the English interface also as read in English (${language.name})',
        (tester) async {
      await openAbout(tester, language: language);
      expect(find.text('שניים מקרא ואחד תרגום'), findsOneWidget, reason: 'never twice in the Hebrew interface');
      expect(find.text('Shnayim Mikra v’Echad Targum'), language == AppLanguage.english ? findsOneWidget : findsNothing);
    });
  }

  testWidgets('About heads its page with the mark and the name, read once as the heading', (tester) async {
    final handle = tester.ensureSemantics();
    await openAbout(tester);
    expect(find.byWidgetPredicate((w) => w is AppMark && w.size == 72), findsOneWidget);
    expect(
      tester.getSemantics(find.text('שניים מקרא ואחד תרגום')),
      isSemantics(label: 'Shnayim Mikra v’Echad Targum', isHeader: true),
    );
    // The English name under it is for the eye: the heading says it.
    expect(find.bySemanticsLabel('Shnayim Mikra v’Echad Targum'), findsOneWidget);
    expect(find.byType(SeferDivider), findsOneWidget);
    // The page's one heading of level 1: the app bar's "About" shows, for
    // the eye alone, only once the name has scrolled under it.
    final levelOne = find.semantics.byPredicate((node) {
      final data = node.getSemanticsData();
      return data.flagsCollection.isHeader && data.headingLevel == 1;
    });
    expect(levelOne.evaluate().map((n) => n.label), ['Shnayim Mikra v’Echad Targum']);
    double titleOpacity() => tester
        .widget<AnimatedOpacity>(find.descendant(of: find.byType(AppBar), matching: find.byType(AnimatedOpacity)))
        .opacity;
    expect(titleOpacity(), 0);
    await openAbout(tester, height: 700);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(titleOpacity(), 1);
    handle.dispose();
  });

  testWidgets('About sets its links on paper: the texts, the policies and the ways to reach us', (tester) async {
    await openAbout(tester);
    List<String> group(String header) {
      final headers = find.byType(GroupHeader).evaluate().map((e) => (e.widget as GroupHeader).text).toList();
      final groups = find.byType(PaperGroup).evaluate().toList();
      final rows = find.descendant(of: find.byWidget(groups[headers.indexOf(header)].widget), matching: find.byType(PaperRow));
      return [for (final row in rows.evaluate()) (row.widget as PaperRow).title];
    }

    expect(group('Learn'), ['Texts & sources']);
    expect(group('Policies'), [
      'Privacy',
      'Terms of use',
      'Community guidelines',
      'Accessibility statement',
      'Open-source licenses',
    ]);
    // A build with no address to email has only the issue tracker.
    expect(group('Contact'), ['Send feedback']);
    // The guide is Today's and Settings' to open.
    expect(find.text('How it works'), findsNothing);
  });

  testWidgets("in Hebrew, the contact group's rows say what they do, not the group's name again", (tester) async {
    AppConfig.debugSupportEmail = 'help@example.org';
    addTearDown(() => AppConfig.debugSupportEmail = null);
    await openAbout(tester, language: AppLanguage.hebrew);
    final headers = find.byType(GroupHeader).evaluate().map((e) => (e.widget as GroupHeader).text).toList();
    final group = find.byType(PaperGroup).evaluate().toList()[headers.indexOf('יצירת קשר')];
    final titles = [
      for (final row in find.descendant(of: find.byWidget(group.widget), matching: find.byType(PaperRow)).evaluate())
        (row.widget as PaperRow).title,
    ];
    expect(titles.first, 'כתיבה אלינו בדוא״ל');
    expect(titles, isNot(contains('יצירת קשר')));
  });

  for (final (width, framed) in [(412.0, false), (800.0, true)]) {
    testWidgets('About frames its title page ${framed ? 'on a wide screen' : 'only on a wide screen'} ($width)',
        (tester) async {
      await openAbout(tester, width: width);
      expect(find.byType(TitlePageFrame), framed ? findsOneWidget : findsNothing);
    });
  }
}
