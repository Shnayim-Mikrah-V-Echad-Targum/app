import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/features/parsha/week_context.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';
import 'package:shnayim_mikra/services/feedback.dart';
import 'package:shnayim_mikra/ui/theme/layout.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';

import '../helpers.dart';

const _hebrew = AppSettings(onboardingComplete: true, language: AppLanguage.hebrew);
final _en = lookupAppLocalizations(const Locale('en'));
final _he = lookupAppLocalizations(const Locale('he'));

/// The app bar title's Text.
Finder _title(String text) => find.descendant(of: find.byType(AppBar), matching: find.text(text));

/// The start edge of a page's content: the first card's, or for a page of
/// paper groups, the first group's.
Rect _firstCard(WidgetTester tester) => tester.getRect(find.byType(InfoCard).first);
Rect _firstPaper(WidgetTester tester) => tester.getRect(find.byType(PaperGroup).first);

void main() {
  // Real glyphs, so that a title is as wide as it is on a screen.
  setUpAll(loadBundledFonts);

  group('layout tokens', () {
    test('the gutters follow the window: 20, 24 from 600 and 32 from 1200', () {
      expect(Gutter.forWidth(360), 20);
      expect(Gutter.forWidth(599), 20);
      expect(Gutter.forWidth(600), 24);
      expect(Gutter.forWidth(1199), 24);
      expect(Gutter.forWidth(1200), 32);
      expect(Gutter.forWidth(1366), 32);
    });

    test('the spacing scale is on the 4 pt grid', () {
      for (final step in [Space.xs, Space.sm, Space.md, Space.lg, Space.xl, Space.xxl, Space.s28, Space.s32, Space.s40, Space.s48]) {
        expect(step % 4, 0, reason: '$step');
      }
      expect([ContentWidth.list, ContentWidth.longform, ContentWidth.account, ContentWidth.todayWide], [720, 620, 440, 1040]);
    });
  });

  group('PageBody', () {
    Future<void> pumpBody(WidgetTester tester, Size size, {EdgeInsets safeArea = EdgeInsets.zero}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(bottom: safeArea.bottom);
      addTearDown(tester.view.reset);
      await pumpThemed(tester, const PageBody(children: [SizedBox(height: 10, key: Key('first'))]));
    }

    for (final (width, gutter) in [(412.0, 20.0), (800.0, 24.0), (1366.0, 32.0)]) {
      testWidgets('lays a ${width.round()} dp window out in a column of 720 at most, with $gutter dp gutters',
          (tester) async {
        await pumpBody(tester, Size(width, 900));
        final first = tester.getRect(find.byKey(const Key('first')));
        final column = width < 720 ? width : 720.0;
        expect(first.left, (width - column) / 2 + gutter);
        expect(first.width, column - 2 * gutter);
        expect(first.top, 8);
      });
    }

    testWidgets('ends 40 below its content, and clears the gesture bar of a page over the whole screen',
        (tester) async {
      await pumpBody(tester, const Size(412, 50), safeArea: const EdgeInsets.only(bottom: 24));
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      // 8 above, 10 of content, then 40 and the 24 of the gesture bar.
      expect(scrollable.position.maxScrollExtent + scrollable.position.viewportDimension, 8 + 10 + 40 + 24);
    });

    testWidgets("a page of list tiles pads the rest of the gutter, so their text starts on the gutter",
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => PageBody(
            padding: PageBody.tilePadding(context),
            children: const [ListTile(leading: Icon(Icons.person_outline), title: Text('Account'))],
          ),
        ),
      );
      expect(tester.getRect(find.byType(Icon)).left, 20);
    });

    testWidgets('a page of paper groups stands them on the gutters', (tester) async {
      await openRoute(tester, '/settings');
      expect(_firstPaper(tester).left, 20);
      expect(_firstPaper(tester).right, 412 - 20);
    });
  });

  group('PageScaffold', () {
    // 1366 wide: the extended rail (256 and its hairline) beside a pane of
    // 1109, whose 720 column starts at 451.5 and its content 32 in.
    for (final route in ['/settings', '/settings/display', '/community']) {
      testWidgets('on a desktop, the title of $route starts where its content does', (tester) async {
        await openRoute(tester, route, size: const Size(1366, 860));
        final title = switch (route) {
          '/settings' => _en.settingsTitle,
          '/settings/display' => _en.settingsDisplay,
          _ => _en.communityTitle,
        };
        final content = route == '/community' ? _firstCard(tester) : _firstPaper(tester);
        expect(content.left, 257 + (1109 - 720) / 2 + 32);
        expect(tester.getTopLeft(_title(title)).dx, content.left);
      });
    }

    testWidgets("on a desktop, a narrow column's title shows, starting where its content does", (tester) async {
      await openRoute(tester, '/community/account', size: const Size(1366, 860));
      final title = _title(_en.settingsAccount);
      expect(title, findsOneWidget);
      final field = tester.getRect(find.byType(TextField));
      expect(field.left, 257 + (1109 - ContentWidth.account) / 2 + 32);
      expect(tester.getTopLeft(title).dx, field.left);
      expect(tester.getSize(title).width, greaterThan(100), reason: 'room for the title, not squeezed out');
    });

    testWidgets("on a desktop, the actions end at the column's edge", (tester) async {
      await openRoute(tester, '/community', size: const Size(1366, 860));
      final column = 257 + (1109 + 720) / 2;
      expect(tester.getRect(find.byTooltip(_en.signInTitle)).right, column);
    });

    testWidgets("on a desktop, the floating button ends where the column's content does", (tester) async {
      await openRoute(tester, '/community/forum/questions', size: const Size(1366, 860));
      final content = 257 + (1109 + 720) / 2 - 32;
      expect(tester.getRect(find.byType(FloatingActionButton)).right, content);

      // In Hebrew, at the left, with the rail at the right.
      await openRoute(tester, '/community/forum/questions', size: const Size(1366, 860), settings: _hebrew);
      expect(tester.getRect(find.byType(FloatingActionButton)).left, (1109 - 720) / 2 + 32);

      // Where the column fills the pane, Material's 16 from its edge.
      for (final size in [const Size(412, 915), const Size(800, 1180)]) {
        await openRoute(tester, '/community/forum/questions', size: size);
        expect(tester.getRect(find.byType(FloatingActionButton)).right, size.width - 16);
      }
    });

    testWidgets('in Hebrew, the title ends where the content does, at the right', (tester) async {
      await openRoute(tester, '/community', size: const Size(1366, 860), settings: _hebrew);
      expect(tester.getTopRight(_title(_he.communityTitle)).dx, _firstCard(tester).right);
    });

    for (final (size, gutter) in [(const Size(412, 915), 20.0), (const Size(800, 1180), 24.0)]) {
      testWidgets('at ${size.width.round()} dp, the title is on the gutter, or after the back button', (tester) async {
        await openRoute(tester, '/settings', size: size);
        final pane = tester.getTopLeft(find.byType(AppBar)).dx;
        expect(tester.getTopLeft(_title(_en.settingsTitle)).dx, pane + gutter);
        await openRoute(tester, '/settings/display', size: size);
        expect(tester.getTopLeft(_title(_en.settingsDisplay)).dx, pane + 56 + gutter);
      });
    }

    group('on a 1920 dp desktop', () {
      // Within a tab, the extended rail (256 and its hairline) is beside a
      // pane of 1663, whose 720 column's content starts 503.5 in; a page over
      // the tabs has the whole window. The inset goes before the title alone:
      // kept after it too, it would leave a title beside actions a few dozen
      // pixels.
      const size = Size(1920, 1080);
      const inTab = 257 + (1663 - 720) / 2 + 32;
      const overTabs = (1920 - 720) / 2 + 32;
      // The week of Vayakhel-Pekudei 5786, read together: the Parsha tab's
      // longest title, beside its three actions.
      final combined = findWeekById(const ParshaSchedule(israel: false), '5786:22-23')!.occasion.addDays(-2);
      final inCombinedWeek = DateTime(combined.year, combined.month, combined.day, 10);

      for (final (route, title, start, now) in [
        ('/parsha', 'Parshat Vayakhel-Pekudei', inTab, inCombinedWeek),
        ('/week/5786:22-23', 'Parshat Vayakhel-Pekudei', overTabs, null),
        ('/community', 'Community', inTab, null),
        ('/community/forum/chavruta', 'Chavruta & encouragement', inTab, null),
        // A thread, named for its forum.
        ('/community/thread/41', 'Chavruta & encouragement', inTab, null),
      ]) {
        testWidgets('the title of $route starts on the content edge and runs whole', (tester) async {
          await openRoute(tester, route, size: size, now: now);
          final text = _title(title);
          expect(text, findsOneWidget);
          expect(tester.getTopLeft(text).dx, start);
          final paragraph = tester.renderObject<RenderParagraph>(text);
          expect(paragraph.didExceedMaxLines, isFalse, reason: 'never cut short');
          expect(paragraph.size.width, greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5));
        });
      }
    });

    testWidgets('the title is the heading of the page, of level 1', (tester) async {
      final handle = tester.ensureSemantics();
      await openRoute(tester, '/progress');
      final title = tester.getSemantics(_title(_en.progressTitle));
      expect(title, isSemantics(label: _en.progressTitle, isHeader: true));
      expect(title.getSemanticsData().headingLevel, 1);
      handle.dispose();
    });

    group('a title with little room beside its actions', () {
      /// The size the app bar sets a title at, and the size [text] is set at.
      (double, double) sizes(WidgetTester tester, Finder text) {
        final context = tester.element(text);
        final full = MediaQuery.textScalerOf(context).scale(Theme.of(context).appBarTheme.titleTextStyle!.fontSize!);
        final paragraph = tester.renderObject<RenderParagraph>(text);
        return (full, paragraph.textScaler.scale(paragraph.text.style!.fontSize!));
      }

      // Lexend is wider than the standard font: on a 412 dp phone, "New
      // discussion" has no room at its full size beside the Demo tag and Post,
      // nor a thread's forum beside the Demo tag and Refresh.
      for (final (route, title) in [
        ('/community/new', _en.newThread),
        ('/community/thread/1', 'Questions & answers'),
      ]) {
        testWidgets('is set a little smaller rather than cut short: $route', (tester) async {
          await openRoute(tester, route, settings: const AppSettings(onboardingComplete: true, uiFont: UiFont.lexend));
          final text = _title(title);
          expect(text, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(text);
          expect(paragraph.didExceedMaxLines, isFalse, reason: 'never cut short');
          expect(paragraph.size.width, greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5));
          final (full, set) = sizes(tester, text);
          expect(set, lessThan(full));
          expect(set, greaterThanOrEqualTo(full * 0.75));
        });
      }

      testWidgets('keeps its full size where it fits', (tester) async {
        await openRoute(tester, '/community/new');
        final (full, set) = sizes(tester, _title(_en.newThread));
        expect(set, full);
      });

      testWidgets('is never set below 75% of its size, and only then cut short', (tester) async {
        // The longest forum's name, enlarged, on a 360 dp phone.
        await openRoute(tester, '/community/forum/chavruta', size: const Size(360, 800), textScale: 2);
        final text = _title('Chavruta & encouragement');
        final (full, set) = sizes(tester, text);
        expect(set, moreOrLessEquals(full * 0.75));
        expect(tester.renderObject<RenderParagraph>(text).didExceedMaxLines, isTrue);
      });
    });

    testWidgets("a page whose heading is in its body shows the title once it is revealed, for the eye alone",
        (tester) async {
      final handle = tester.ensureSemantics();
      Future<void> pump({required bool revealed}) => pumpThemed(
            tester,
            PageScaffold(
              titleText: 'Parshat Bereshit',
              titleRevealed: revealed,
              body: const PageBody(children: [Text('Body')]),
            ),
          );
      double opacity() => tester
          .widget<AnimatedOpacity>(find.ancestor(of: _title('Parshat Bereshit'), matching: find.byType(AnimatedOpacity)))
          .opacity;

      await pump(revealed: false);
      expect(opacity(), 0);
      // Screen readers find the heading in the page instead.
      expect(find.bySemanticsLabel('Parshat Bereshit'), findsNothing);

      await pump(revealed: true);
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      expect(find.bySemanticsLabel('Parshat Bereshit'), findsNothing);
      handle.dispose();
    });
  });

  group('status messages', () {
    /// Shows a message from the page on show, and gives where it is set.
    Future<Rect> show(WidgetTester tester) async {
      showStatus(tester.element(find.byType(PageScaffold).last), 'Updated');
      await tester.pumpAndSettle();
      // Its paper, within its margins.
      return tester.getRect(find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first);
    }

    testWidgets('on a phone, run 16 from the edges', (tester) async {
      await openRoute(tester, '/settings');
      final bar = await show(tester);
      expect((bar.left, bar.right), (16, 412 - 16));
    });

    testWidgets("on a desktop, are a sheet's width at most, centred on the page beside the rail", (tester) async {
      await openRoute(tester, '/settings', size: const Size(1366, 860));
      final bar = await show(tester);
      expect(bar.width, 640);
      expect(bar.center.dx, 257 + 1109 / 2);
      expect(bar.bottom, 860 - 16);

      // In Hebrew, the rail is at the right.
      await openRoute(tester, '/settings', size: const Size(1366, 860), settings: _hebrew);
      expect((await show(tester)).center.dx, 1109 / 2);

      // Over the tabs, the page is the window.
      await openRoute(tester, '/guide', size: const Size(1366, 860));
      expect((await show(tester)).center.dx, 1366 / 2);
    });

    testWidgets('on a tablet, keep 16 from the pane where it is narrower', (tester) async {
      await openRoute(tester, '/settings', size: const Size(640, 900));
      final bar = await show(tester);
      // The compact rail (80 and its hairline) beside a pane of 559.
      expect((bar.left, bar.right), (81 + 16, 640 - 16));
    });
  });

  group('DocumentTitle', () {
    /// The labels the app gives the platform, in order.
    List<String> recordTitles(WidgetTester tester) {
      final labels = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setApplicationSwitcherDescription') {
          labels.add((call.arguments as Map)['label'] as String);
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
      return labels;
    }

    void onTheWeb() {
      DocumentTitle.enabled = true;
      addTearDown(() => DocumentTitle.enabled = false);
    }

    testWidgets('each page names the tab, and names it again when shown again', (tester) async {
      onTheWeb();
      final labels = recordTitles(tester);
      final c = await pumpApp(tester);
      String named(String page) => '$page · ${_en.appTitle}';
      expect(labels.last, named(_en.navToday));

      final router = c.read(routerProvider);
      final seen = <String>{};
      for (final route in ['/parsha', '/progress', '/community', '/settings', '/guide', '/search']) {
        router.go(route);
        await tester.pumpAndSettle();
        seen.add(labels.last);
      }
      expect(seen, hasLength(6), reason: 'a title of its own for each');
      expect(seen, containsAll([named(_en.progressTitle), named(_en.settingsTitle)]));

      // Back from a page over Settings, and back to Settings' tab.
      router.go('/settings');
      await tester.pumpAndSettle();
      unawaited(router.push('/settings/display'));
      await tester.pumpAndSettle();
      expect(labels.last, named(_en.settingsDisplay));
      router.pop();
      await tester.pumpAndSettle();
      expect(labels.last, named(_en.settingsTitle));
      router.go('/progress');
      await tester.pumpAndSettle();
      router.go('/settings');
      await tester.pumpAndSettle();
      expect(labels.last, named(_en.settingsTitle));

      // The reader, over the tabs, named while its text loads, and the tab
      // beneath it once it closes.
      unawaited(router.push('/read/5787:1/0'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(labels.last, named('Bereshit · ${_en.aliyah1}'));
      router.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(labels.last, named(_en.settingsTitle));
    });

    testWidgets('a page beneath another never takes the title back as it changes', (tester) async {
      onTheWeb();
      final labels = recordTitles(tester);
      final c = await pumpApp(tester);
      final router = c.read(routerProvider);
      unawaited(router.push('/guide'));
      await tester.pumpAndSettle();
      expect(labels.last, '${_en.guideTitle} · ${_en.appTitle}');
      // Today, beneath, rebuilds with the language too.
      c.read(settingsProvider.notifier).update((s) => s.copyWith(language: AppLanguage.hebrew));
      await tester.pumpAndSettle();
      expect(labels.last, '${_he.guideTitle} · ${_he.appTitle}');
    });

    testWidgets('names nothing off the web, where the platform keeps the app\'s name', (tester) async {
      final labels = recordTitles(tester);
      final c = await pumpApp(tester);
      c.read(routerProvider).go('/settings');
      await tester.pumpAndSettle();
      expect(labels, everyElement(_en.appTitle));
    });
  });
}
