import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shnayim_mikra/app/celebrations.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/features/parsha/week_context.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/reader/sefer_complete_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

void main() {
  // Vayechi 5787, the last parsha of Genesis, and the Friday before it is
  // read.
  final vayechi = findWeekById(const ParshaSchedule(israel: false), '5787:12')!;
  final friday = vayechi.occasion.addDays(-1);

  /// Genesis 5787 read: Bereshit to Vayigash a month before [friday], and
  /// Vayechi on it, all but its last [lastAliyot] aliyot.
  ProgressState genesisBut(int lastAliyot) {
    final day = friday.addDays(-30);
    return ProgressState(weeks: {
      for (var n = 1; n <= 11; n++) '5787:$n': WeekProgress(weekId: '5787:$n').withAll(day),
      '5787:12': [for (var a = 0; a < 7 - lastAliyot; a++) a]
          .fold(WeekProgress(weekId: '5787:12'), (w, a) => w.withAliyah(a, friday)),
    });
  }

  String location(GoRouter router) => router.state.uri.toString();

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('finishing Genesis opens its celebration once, and finishing it again does not', (tester) async {
    final c = await pumpApp(
      tester,
      settings: AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4)),
      now: DateTime(friday.year, friday.month, friday.day, 10),
      progress: genesisBut(1),
    );
    final router = c.read(routerProvider);
    final progress = c.read(progressProvider.notifier);
    await settle(tester);
    expect(location(router), '/today');

    progress.markAliyah('5787:12', 6, friday);
    await settle(tester);
    expect(location(router), '/celebrate/sefer:5787:0');
    expect(find.byType(SeferCompleteScreen), findsOneWidget);
    expect(find.text(SeferCompleteScreen.chazak), findsOneWidget);
    expect(find.text('Genesis complete — 1,533 verses, twice, with Targum.'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(CelebrationKeys.storageKey), ['sefer:5787:0']);

    // It stays until Continue.
    await tester.pump(const Duration(minutes: 5));
    expect(find.byType(SeferCompleteScreen), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(location(router), '/today');

    // Marked not read and read again: celebrated already.
    progress.markAliyah('5787:12', 6, null);
    await settle(tester);
    progress.markAliyah('5787:12', 6, friday);
    await settle(tester);
    expect(location(router), '/today');
    expect(find.byType(SeferCompleteScreen), findsNothing);
  });

  testWidgets('finishing Genesis in the reader celebrates it over the finished panel', (tester) async {
    final c = await pumpApp(
      tester,
      settings: AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4), notificationPromptShown: true),
      now: DateTime(friday.year, friday.month, friday.day, 10),
      progress: genesisBut(1),
    );
    final router = c.read(routerProvider);
    router.push('/read/5787:12/6');
    for (var i = 0; i < 20 && find.byTooltip('More options').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark this aliyah as read'));
    await settle(tester);
    expect(find.byType(SeferCompleteScreen), findsOneWidget);
    // The page over the reader has the focus, which the reader never takes
    // back while it is over it...
    final celebration = ModalRoute.of(tester.element(find.byType(SeferCompleteScreen)));
    expect(ModalRoute.of(FocusManager.instance.primaryFocus!.context!), celebration);

    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(find.text('Parshat Vayechi is complete'), findsOneWidget);
    // ... and the panel's first button has it again once the page closes.
    expect(Focus.of(tester.element(find.text('Read the haftarah'))).hasPrimaryFocus, isTrue);
  });

  testWidgets('a book finished on another device, arriving by sync, is recorded without a celebration', (tester) async {
    final c = await pumpApp(
      tester,
      settings: AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4)),
      now: DateTime(friday.year, friday.month, friday.day, 10),
      progress: genesisBut(1),
    );
    final router = c.read(routerProvider);
    await settle(tester);
    // Finished an hour ago on the tablet, and merged in here.
    final now = c.read(progressProvider);
    final vayechi = now.weeks['5787:12']!.withAliyah(6, friday);
    c.read(progressProvider.notifier).replaceAll(now.copyWith(weeks: {...now.weeks, '5787:12': vayechi}));
    await settle(tester);
    expect(location(router), '/today');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(CelebrationKeys.storageKey), ['sefer:5787:0'], reason: 'recorded, so never celebrated later');

    // Read again here, it is celebrated already.
    c.read(progressProvider.notifier).markAliyah('5787:12', 6, null);
    await settle(tester);
    c.read(progressProvider.notifier).markAliyah('5787:12', 6, friday);
    await settle(tester);
    expect(location(router), '/today');
  });

  testWidgets('a book finished before onboarding is complete is recorded without a celebration', (tester) async {
    final c = await pumpApp(
      tester,
      settings: AppSettings(joinDate: LocalDate(2026, 10, 4)),
      now: DateTime(friday.year, friday.month, friday.day, 10),
      progress: genesisBut(1),
    );
    await settle(tester);
    c.read(progressProvider.notifier).markAliyah('5787:12', 6, friday);
    await settle(tester);
    expect(find.byType(SeferCompleteScreen), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(CelebrationKeys.storageKey), ['sefer:5787:0']);
  });

  testWidgets("a book of the last year's cycle, finished now, is celebrated", (tester) async {
    // The week of Bereshit 5787, with Deuteronomy 5786 read but for the last
    // aliyah of Vezot HaBerakhah.
    final day = LocalDate(2026, 10, 7);
    final c = await pumpApp(
      tester,
      settings: AppSettings(onboardingComplete: true, joinDate: LocalDate(2025, 10, 1)),
      now: DateTime(2026, 10, 7, 10),
      progress: ProgressState(weeks: {
        for (var n = 44; n <= 53; n++) '5786:$n': WeekProgress(weekId: '5786:$n').withAll(day.addDays(-40)),
        '5786:54': [0, 1, 2, 3, 4, 5].fold(WeekProgress(weekId: '5786:54'), (w, a) => w.withAliyah(a, day.addDays(-4))),
      }),
    );
    final router = c.read(routerProvider);
    await settle(tester);
    c.read(progressProvider.notifier).markAliyah('5786:54', 6, day);
    await settle(tester);
    expect(location(router), '/celebrate/sefer:5786:4');
    expect(find.text(SeferCompleteScreen.chazak), findsOneWidget);
  });

  testWidgets('a book finished before the app starts, or restored long after, is never celebrated', (tester) async {
    final c = await pumpApp(
      tester,
      settings: AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4)),
      now: DateTime(friday.year, friday.month, friday.day, 10),
      progress: genesisBut(0),
    );
    final router = c.read(routerProvider);
    await settle(tester);
    expect(location(router), '/today');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(CelebrationKeys.storageKey), ['sefer:5787:0'], reason: 'taken as celebrated');

    // Exodus of the cycle before, finished a year ago, arrives in a restore.
    final exodus = {
      for (var n = 13; n <= 23; n++) '5786:$n': WeekProgress(weekId: '5786:$n').withAll(friday.addDays(-300)),
    };
    final now = c.read(progressProvider);
    c.read(progressProvider.notifier).replaceAll(now.copyWith(weeks: {...now.weeks, ...exodus}));
    await settle(tester);
    expect(location(router), '/today');
    expect(prefs.getStringList(CelebrationKeys.storageKey), ['sefer:5786:1', 'sefer:5787:0']);
  });

  testWidgets('a celebration link that names no book leads nowhere', (tester) async {
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true));
    c.read(routerProvider).go('/celebrate/nonsense');
    await settle(tester);
    expect(find.byType(SeferCompleteScreen), findsOneWidget);
    expect(find.text(SeferCompleteScreen.chazak), findsNothing);
  });
}
