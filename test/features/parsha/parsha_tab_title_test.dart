import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/ui/widgets/common.dart';
import 'package:shnayim_mikrah/ui/widgets/progress_widgets.dart';

import '../../helpers.dart';

/// The Parsha tab's app bar on a phone (docs/DESIGN_SYSTEM.md §9 Parsha tab,
/// 1): once the parsha's name has scrolled away, the app bar names it, and
/// never in part, beside All parshiyot, search and the week's menu.
final _settings = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4));

void main() {
  setUpAll(loadBundledFonts);
  setUp(ParshaRings.forgetShown);

  Future<void> scrolledTab(WidgetTester tester, double width, {AppSettings? settings, DateTime? now}) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: settings ?? _settings, now: now ?? DateTime(2026, 10, 9, 11));
    c.read(routerProvider).go('/parsha');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
  }

  /// The title the app bar shows, if any.
  Finder title() => find.descendant(of: find.byType(AppBarTitle), matching: find.byType(Text));

  /// Expects the app bar to show [name], whole, at 75% of its size or more.
  void expectWhole(WidgetTester tester, String name) {
    expect(title(), findsOneWidget, reason: name);
    final text = tester.widget<Text>(title());
    expect(text.data, name);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: title(), matching: find.byType(RichText)),
    );
    expect(paragraph.didExceedMaxLines, isFalse, reason: '$name is not cut short');
    final size = DefaultTextStyle.of(tester.element(title())).style.fontSize!;
    expect(text.style?.fontSize ?? size, greaterThanOrEqualTo(size * AppBarTitle.minScale - 0.01));
  }

  for (final width in [360.0, 412.0]) {
    testWidgets('at ${width.round()} dp, names the parsha alone, whole, once its name has scrolled away',
        (tester) async {
      await scrolledTab(tester, width);
      expectWhole(tester, 'Bereshit');
      await scrolledTab(tester, width, settings: _settings.copyWith(language: AppLanguage.hebrew));
      expectWhole(tester, 'בראשית');
    });
  }

  // Acharei Mot-Kedoshim, the longest name of a week, read together in 5788.
  testWidgets('shows the longest name whole on a 412 dp phone, and leaves it out rather than cut it at 360',
      (tester) async {
    const schedule = ParshaSchedule(israel: false);
    var shabbat = LocalDate(2028, 4, 1);
    while (schedule.portionOnShabbat(shabbat) != const PortionId(29, combined: true)) {
      shabbat = shabbat.addDays(7);
    }
    final wednesday = shabbat.addDays(-3);
    final now = DateTime(wednesday.year, wednesday.month, wednesday.day, 11);

    await scrolledTab(tester, 412, now: now);
    expectWhole(tester, 'Acharei Mot-Kedoshim');
    // In Hebrew it is shorter, and fits a 360 dp phone too.
    await scrolledTab(tester, 360, now: now, settings: _settings.copyWith(language: AppLanguage.hebrew));
    expectWhole(tester, 'אחרי מות־קדשים');

    await scrolledTab(tester, 360, now: now);
    expect(tester.takeException(), isNull);
    expect(title(), findsNothing, reason: 'too long for the room at 75%: left out, not cut short');
    expect(find.textContaining('Kedoshim', findRichText: true), findsWidgets, reason: 'the page still names it');
  });
}
