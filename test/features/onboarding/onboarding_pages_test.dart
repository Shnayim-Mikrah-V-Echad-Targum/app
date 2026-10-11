import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/settings/widgets/settings_widgets.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/lang.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';

import '../../helpers.dart';

/// Onboarding as a title page and paper radio cards (docs/DESIGN_SYSTEM.md
/// §9 Onboarding): the welcome's language and title block, and each step's
/// place, question and way on.
void main() {
  /// A Wednesday, when the plan step also asks about this week.
  final wednesday = DateTime(2026, 10, 14, 10);
  const fresh = AppSettings();
  const appTitleFull = 'Shnayim Mikra v’Echad Targum';

  /// Expects [finder]'s node to be a heading of [level], labelled [label] if
  /// given.
  void expectHeading(WidgetTester tester, Finder finder, int level, {String? label}) {
    final data = tester.getSemantics(finder).getSemanticsData();
    expect(data.flagsCollection.isHeader, isTrue);
    expect(data.headingLevel, level);
    if (label != null) expect(data.label, label);
  }

  SegmentedButton<AppLanguage> languages(WidgetTester tester) =>
      tester.widget<SegmentedButton<AppLanguage>>(find.byType(SegmentedButton<AppLanguage>));

  group('welcome', () {
    testWidgets("shows the language it is shown in as chosen, the device's too", (tester) async {
      final c = await openRoute(tester, '/welcome', settings: fresh);
      expect(languages(tester).selected, {AppLanguage.english});
      expect(languages(tester).emptySelectionAllowed, isFalse);

      // Choosing it again changes nothing: the app goes on following the
      // device.
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).language, AppLanguage.system);

      await tester.tap(find.text('עברית'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).language, AppLanguage.hebrew);
      expect(languages(tester).selected, {AppLanguage.hebrew});
      expect(find.text('להתחיל את פרשת השבוע'), findsOneWidget);
    });

    testWidgets("names each language in itself, read in that language's voice", (tester) async {
      for (final hebrewUi in [false, true]) {
        await openRoute(tester, '/welcome', settings: hebrewUi ? const AppSettings(language: AppLanguage.hebrew) : fresh);
        for (final (name, code) in [('English', 'en'), ('עברית', 'he')]) {
          expect(
            find.ancestor(
              of: find.text(name),
              matching: find.byWidgetPredicate((w) => w is Lang && w.locale == Locale(code)),
            ),
            findsOneWidget,
            reason: '$name in the ${hebrewUi ? 'Hebrew' : 'English'} UI',
          );
        }
      }
    });

    testWidgets('keeps the title from crowding out the way on with very large text', (tester) async {
      await openRoute(tester, '/welcome', settings: fresh, textScale: 2);
      // The names, display sizes already, grow to 1.4 times at most, so the
      // call to action stays near the fold.
      for (final name in [find.text('שְׁנַיִם מִקְרָא\nוְאֶחָד תַּרְגּוּם'), find.text(appTitleFull)]) {
        expect(MediaQuery.textScalerOf(tester.element(name)).scale(10), closeTo(14, 0.01));
      }
      // What the practice is, and the buttons, grow in full.
      for (final text in [find.textContaining('Read the parsha twice'), find.text('Start this week’s parsha')]) {
        expect(MediaQuery.textScalerOf(tester.element(text)).scale(10), 20);
      }
    });

    testWidgets('on a device in Hebrew, shows Hebrew as chosen', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('he', 'IL')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final c = await openRoute(tester, '/welcome', settings: fresh);
      expect(c.read(settingsProvider).language, AppLanguage.system);
      expect(languages(tester).selected, {AppLanguage.hebrew});
    });

    testWidgets("heads the page with the practice's name in pointed Hebrew, then in English", (tester) async {
      final handle = tester.ensureSemantics();
      await openRoute(tester, '/welcome', settings: fresh);
      expect(find.byType(TitlePageFrame), findsOneWidget);
      final title = find.text('שְׁנַיִם מִקְרָא\nוְאֶחָד תַּרְגּוּם');
      expect(title, findsOneWidget);
      expect(find.descendant(of: find.byType(TitlePageFrame), matching: title), findsOneWidget);
      expectHeading(tester, title, 1, label: appTitleFull);
      // The English name, once, for the eye alone: the heading says it.
      expect(find.text(appTitleFull), findsOneWidget);
      expect(tester.widget<Text>(find.text(appTitleFull)).style?.fontStyle, FontStyle.italic);
      expect(find.semantics.byLabel(appTitleFull), findsOneWidget);
      handle.dispose();
    });

    testWidgets('in the Hebrew UI, names the practice once, pointed', (tester) async {
      final handle = tester.ensureSemantics();
      await openRoute(tester, '/welcome', settings: const AppSettings(language: AppLanguage.hebrew));
      expectHeading(tester, find.text('שְׁנַיִם מִקְרָא\nוְאֶחָד תַּרְגּוּם'), 1, label: 'שניים מקרא ואחד תרגום');
      expect(find.text('שניים מקרא ואחד תרגום'), findsNothing, reason: 'no unpointed repeat');
      expect(find.text(appTitleFull), findsNothing);
      handle.dispose();
    });

    testWidgets('sets its call to action 52 high and at most 400 wide, in the middle', (tester) async {
      await openRoute(tester, '/welcome', settings: fresh, size: const Size(1366, 860));
      final start = find.widgetWithText(FilledButton, 'Start this week’s parsha');
      expect(tester.getSize(start), const Size(400, 52));
      expect(tester.getCenter(start).dx, 683);
      // The way back in for a reader who already uses the app, as wide.
      final restore = find.widgetWithText(TextButton, 'I already use Shnayim Mikra');
      expect(tester.getSize(restore).width, 400);
      expect(tester.getCenter(restore).dx, 683);
      // The title block is at most 520 wide, in the middle.
      final frame = tester.getRect(find.byType(TitlePageFrame));
      expect((frame.width, frame.center.dx), (520, 683));
      // The language ends where the block does.
      expect(tester.getRect(find.byType(SegmentedButton<AppLanguage>)).right, frame.right);
    });
  });

  group('steps', () {
    /// The step marks: filled, or outlined.
    List<bool> marks(WidgetTester tester) =>
        [for (final l in tester.widgetList<Lozenge>(find.byType(Lozenge))) !l.outlined];

    testWidgets('each shows its place among the four pages in lozenges, and says it in its title', (tester) async {
      final c = await openRoute(tester, '/welcome/location', settings: fresh, now: wednesday);
      expect(marks(tester), [true, true, false, false]);
      expect(find.text('Step 1 of 3'), findsOneWidget);
      for (final lozenge in tester.widgetList<Lozenge>(find.byType(Lozenge))) {
        expect(lozenge.size, Lozenge.large);
      }
      // Set clear of the app bar: 16 below it, the page's 8 and 8 more.
      expect(tester.getTopLeft(find.byType(Lozenge).first).dy - tester.getBottomLeft(find.byType(AppBar)).dy, 16);

      c.read(routerProvider).go('/welcome/method');
      await tester.pumpAndSettle();
      expect(marks(tester), [true, true, true, false]);
      expect(find.text('Step 2 of 3'), findsOneWidget);

      c.read(routerProvider).go('/welcome/plan');
      await tester.pumpAndSettle();
      expect(marks(tester), [true, true, true, true]);
      expect(find.text('Step 3 of 3'), findsOneWidget);
    });

    testWidgets("asks each step's question as a heading over radio cards", (tester) async {
      final handle = tester.ensureSemantics();
      final c = await openRoute(tester, '/welcome/location', settings: fresh, now: wednesday);
      expectHeading(tester, find.text('Where will you be this Shabbat?'), 2);
      expect(find.byType(PaperGroup), findsNothing);
      expect(
        tester.getSemantics(find.text('Outside Israel')),
        isSemantics(hasCheckedState: true, isChecked: true, isInMutuallyExclusiveGroup: true),
      );

      // The second reading, and this week's start, keep the usual paper rows.
      c.read(routerProvider).go('/welcome/method');
      await tester.pumpAndSettle();
      expectHeading(tester, find.text('How do you read?'), 2);
      expect(find.widgetWithText(GroupHeader, 'Targum or Rashi'), findsOneWidget);
      expect(find.byType(PaperGroup), findsOneWidget);

      c.read(routerProvider).go('/welcome/plan');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(GroupHeader, 'This week'), findsOneWidget);
      expect(find.byType(PaperGroup), findsOneWidget);
      handle.dispose();
    });

    testWidgets('sets the honor statement as marginalia in a notice', (tester) async {
      await openRoute(tester, '/welcome/plan', settings: fresh, now: wednesday);
      final notice = tester.widget<NoticeBanner>(find.byType(NoticeBanner));
      expect(notice.marginalia, isTrue);
      expect(notice.text, startsWith('Shnayim Mikra runs on the honor system.'));
    });

    for (final (route, label) in [
      ('/welcome/location', 'Continue'),
      ('/welcome/method', 'Continue'),
      ('/welcome/plan', 'Start reading'),
    ]) {
      testWidgets('at 200% text, keeps "$label" in view on $route, docked below the page', (tester) async {
        await openRoute(tester, route, settings: fresh, now: wednesday, textScale: 2);
        expect(tester.takeException(), isNull);
        final button = find.widgetWithText(FilledButton, label);
        expect(button, findsOneWidget);
        final rect = tester.getRect(button);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(915));
        expect(rect.height, greaterThanOrEqualTo(52));
        // Not in the page that scrolls: where the page is scrolled to, it stays.
        expect(find.ancestor(of: button, matching: find.byType(Scrollable)), findsNothing);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.getRect(button), rect);
        // Every choice can be changed later, it says above the button.
        final note = tester.getRect(find.text('You can change this anytime in Settings.'));
        expect(note.bottom, lessThanOrEqualTo(rect.top));
      });
    }

    testWidgets('goes on from the docked button', (tester) async {
      final c = await openRoute(tester, '/welcome', settings: fresh, now: wednesday);
      await tester.tap(find.text('Start this week’s parsha'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(c.read(routerProvider).state.uri.path, '/welcome/method');
      // The step's way on, not a choice of its own.
      expect(find.byType(ChoiceGroup<SecondReading>), findsOneWidget);
    });
  });
}
