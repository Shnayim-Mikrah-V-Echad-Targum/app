import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';
import 'package:shnayim_mikra/ui/theme/layout.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';

import '../helpers.dart';

const _hebrew = AppSettings(onboardingComplete: true, language: AppLanguage.hebrew);
final _en = lookupAppLocalizations(const Locale('en'));
final _he = lookupAppLocalizations(const Locale('he'));

/// The app bar title's Text.
Finder _title(String text) => find.descendant(of: find.byType(AppBar), matching: find.text(text));

/// The start edge of a page's content: the first card's, or for a page of
/// list tiles, the first tile's leading icon.
Rect _firstCard(WidgetTester tester) => tester.getRect(find.byType(InfoCard).first);
Rect _firstTileIcon(WidgetTester tester) =>
    tester.getRect(find.descendant(of: find.byType(ListTile).first, matching: find.byType(Icon)).first);

void main() {
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
      await openRoute(tester, '/settings');
      expect(_firstTileIcon(tester).left, 20);
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
        final content = route == '/settings' ? _firstTileIcon(tester) : _firstCard(tester);
        expect(content.left, 257 + (1109 - 720) / 2 + 32);
        expect(tester.getTopLeft(_title(title)).dx, content.left);
      });
    }

    testWidgets("on a desktop, the actions end at the column's edge", (tester) async {
      await openRoute(tester, '/community', size: const Size(1366, 860));
      final column = 257 + (1109 + 720) / 2;
      expect(tester.getRect(find.byTooltip(_en.signInTitle)).right, column);
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

    testWidgets('the title is the heading of the page, of level 1', (tester) async {
      final handle = tester.ensureSemantics();
      await openRoute(tester, '/progress');
      final title = tester.getSemantics(_title(_en.progressTitle));
      expect(title, isSemantics(label: _en.progressTitle, isHeader: true));
      expect(title.getSemanticsData().headingLevel, 1);
      handle.dispose();
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
