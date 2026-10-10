import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/city_providers.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/city.dart';
import 'package:shnayim_mikra/core/calendar/zmanim.dart';
import 'package:shnayim_mikra/data/city_directory.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/settings/screens/city_picker_screen.dart';
import 'package:shnayim_mikra/services/reminder_planner.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/sefer_choice_chip.dart';

import '../../helpers.dart';

/// Reminders that can be scheduled, where the OS [allows] them or not, and
/// the device's settings for them can be opened or not.
class _Notifications extends PhoneNotifications {
  _Notifications({this.allows = true, this.opensSettings = true});

  final bool allows;
  final bool opensSettings;

  @override
  Future<bool> requestPermission() async => allows;

  @override
  bool get canOpenSystemSettings => opensSettings;
}

void main() {
  late CityDirectory directory;
  setUpAll(() {
    directory = CityDirectory.parse(File('assets/data/cities.json').readAsStringSync());
    // Loaded as the app loads it once the first frame is up, which tests
    // never report.
    Zmanim.timeZone('UTC');
  });

  Future<ProviderContainer> openReminders(WidgetTester tester, _Notifications service,
      {AppSettings settings = const AppSettings(onboardingComplete: true)}) async {
    final c = await pumpApp(
      tester,
      settings: settings,
      notifications: service,
      overrides: [cityDirectoryProvider.overrideWith((ref) => directory)],
    );
    c.read(routerProvider).go('/settings/reminders');
    await tester.pumpAndSettle();
    return c;
  }

  /// The chosen routines' labels.
  List<String> selected(WidgetTester tester) => [
        for (final chip in tester.widgetList<SeferChoiceChip>(find.byType(SeferChoiceChip)))
          if (chip.selected) (chip.label as Text).data!,
      ];

  testWidgets('a routine chosen stays chosen when the language changes, and is saved by name', (tester) async {
    final c = await openReminders(
      tester,
      _Notifications(),
      settings: const AppSettings(onboardingComplete: true, dailyReminder: true),
    );
    expect(find.text('After I…'), findsOneWidget);
    expect(selected(tester), isEmpty);

    await tester.tap(find.text('finish Shacharit'));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).habitAnchor, HabitAnchor.shacharit);
    expect(c.read(settingsProvider).toJson()['habitAnchor'], 'shacharit');
    expect(selected(tester), ['finish Shacharit']);

    c.read(settingsProvider.notifier).update((s) => s.copyWith(language: AppLanguage.hebrew));
    await tester.pumpAndSettle();
    expect(selected(tester), ['אסיים שחרית']);

    // Chosen again, it is cleared.
    await tester.tap(find.text('אסיים שחרית'));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).habitAnchor, isNull);
    expect(selected(tester), isEmpty);
  });

  testWidgets('a routine chosen moves a time that is only a suggestion to its usual time', (tester) async {
    final c = await openReminders(
      tester,
      _Notifications(),
      settings: const AppSettings(onboardingComplete: true, dailyReminder: true),
    );
    int minutes() => c.read(settingsProvider).dailyReminderMinutes;
    expect(minutes(), 20 * 60);
    final handle = tester.ensureSemantics();
    expect(tester.getSemantics(find.text('Daily reminder time')), isSemantics(isLiveRegion: false));

    // A morning routine at the default 8 PM would contradict its time.
    await tester.tap(find.text('finish Shacharit'));
    await tester.pumpAndSettle();
    expect(minutes(), 7 * 60 + 30);
    expect(
      tester.getSemantics(find.text('Daily reminder time')),
      isSemantics(isLiveRegion: true),
      reason: 'the time it shows is read out as it changes',
    );
    await tester.tap(find.text('start my commute'));
    await tester.pumpAndSettle();
    expect(minutes(), 8 * 60);
    // Cleared, the time stays.
    await tester.tap(find.text('start my commute'));
    await tester.pumpAndSettle();
    expect(minutes(), 8 * 60);

    // A time of the reader's own stays.
    c.read(settingsProvider.notifier).update((s) => s.copyWith(dailyReminderMinutes: 6 * 60 + 45));
    await tester.pumpAndSettle();
    await tester.tap(find.text('finish dinner'));
    await tester.pumpAndSettle();
    expect(minutes(), 6 * 60 + 45);
    handle.dispose();
  });

  testWidgets('one chosen by an earlier version, saved as its label, shows as chosen', (tester) async {
    await openReminders(
      tester,
      _Notifications(),
      settings: AppSettings.fromJson(
        {...const AppSettings(onboardingComplete: true, dailyReminder: true).toJson(), 'habitAnchor': 'אסיים ארוחת ערב'},
      ),
    );
    expect(selected(tester), ['finish dinner']);
  });

  testWidgets('the times read as values and the prompt as a subtitle, not in small print', (tester) async {
    await openReminders(
      tester,
      _Notifications(),
      settings: const AppSettings(onboardingComplete: true, dailyReminder: true, fridayReminder: true),
    );
    final theme = Theme.of(tester.element(find.text('Daily reminder time')));
    for (final text in [
      find.textContaining(RegExp(r'^8:00\sPM$')),
      find.textContaining(RegExp(r'^10:00\sAM$')),
      find.text('Tie your reading to something you already do every day.'),
    ]) {
      final style = tester.renderObject<RenderParagraph>(text).text.style!;
      expect(style.fontSize, theme.textTheme.bodyMedium!.fontSize, reason: '$text');
      expect(style.color, theme.colorScheme.onSurfaceVariant, reason: '$text');
    }
  });

  group('notifications refused', () {
    const channel = MethodChannel('com.spencerccf.app_settings/methods');
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    testWidgets("can be allowed in the device's notification settings for the app", (tester) async {
      final c = await openReminders(tester, _Notifications(allows: false));
      await tester.tap(find.text('Daily reminder'));
      await tester.pumpAndSettle();
      expect(find.text('Notifications are off'), findsOneWidget);

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(calls.single.method, 'openSettings');
      expect((calls.single.arguments as Map)['type'], 'notification');
      expect(c.read(settingsProvider).dailyReminder, isFalse);
    });

    testWidgets("where the device's settings can't be opened, only say so", (tester) async {
      await openReminders(tester, _Notifications(allows: false, opensSettings: false));
      await tester.tap(find.text('Daily reminder'));
      await tester.pumpAndSettle();
      expect(find.text('Notifications are off'), findsOneWidget);
      expect(find.text('Open settings'), findsNothing);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(calls, isEmpty);
    });
  });
  group('the city for Shabbat times', () {
    const offer = 'Choose your city, and reminders will follow its Shabbat times: '
        'before candle-lighting on Friday, and after Shabbat ends.';
    City jerusalem() => directory.cities.firstWhere((c) => c.nameEn == 'Jerusalem');

    /// The text [data], whatever spaces the time format puts before "PM".
    Finder text(String data) => find.byWidgetPredicate(
          (w) => w is Text && w.data?.replaceAll(RegExp('[\u00A0\u202F]'), ' ') == data,
        );

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    testWidgets('is offered when the first reminder is turned on without one, and can be put aside', (tester) async {
      final c = await openReminders(tester, _Notifications());
      expect(find.text(offer), findsNothing);

      await tapText(tester, 'Daily reminder');
      expect(find.text(offer), findsOneWidget);
      await tapText(tester, 'Not now');
      expect(find.text(offer), findsNothing);
      expect(c.read(settingsProvider).cityOfferAnswered, isTrue);

      // Not again for the next reminder turned on, nor on coming back.
      await tapText(tester, 'Erev Shabbat reminder');
      expect(find.text(offer), findsNothing);
      c.read(routerProvider).go('/settings');
      await tester.pumpAndSettle();
      c.read(routerProvider).go('/settings/reminders');
      await tester.pumpAndSettle();
      expect(find.text(offer), findsNothing);
    });

    group('appearing below the screen, it is scrolled into view and read out', () {
      /// Turns the daily reminder on in a [height] high view at [scale],
      /// which opens its time and routines above the offer, and returns
      /// where the offer and the screen are.
      Future<(Rect, Rect)> turnOn(WidgetTester tester, {required double height, required double scale}) async {
        tester.view.physicalSize = Size(412, height);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await openReminders(tester, _Notifications());
        await tester.tap(find.text('Daily reminder'));
        await tester.pumpAndSettle();
        expect(tester.getSemantics(find.text(offer)), isSemantics(label: offer, isLiveRegion: true));
        final banner = find.ancestor(of: find.text(offer), matching: find.byType(NoticeBanner));
        return (tester.getRect(banner), tester.getRect(find.byType(Scrollable).last));
      }

      testWidgets('whole, on a short screen', (tester) async {
        final handle = tester.ensureSemantics();
        final (banner, screen) = await turnOn(tester, height: 640, scale: 1);
        expect(banner.bottom, lessThanOrEqualTo(screen.bottom));
        expect(banner.top, greaterThanOrEqualTo(screen.top));
        handle.dispose();
      });

      testWidgets('from its start, at 200% text, where it is taller than the screen', (tester) async {
        final handle = tester.ensureSemantics();
        final (banner, screen) = await turnOn(tester, height: 915, scale: 2);
        expect(banner.height, greaterThan(screen.height));
        expect(banner.top, inInclusiveRange(screen.top, screen.top + 16));
        handle.dispose();
      });
    });

    testWidgets('is offered while reminders are on without one, however they were turned on, and not read out',
        (tester) async {
      final handle = tester.ensureSemantics();
      // As by the offer after the first aliyah.
      await openReminders(tester, _Notifications(),
          settings: const AppSettings(onboardingComplete: true, dailyReminder: true, fridayReminder: true));
      expect(find.text(offer), findsOneWidget);
      expect(tester.getSemantics(find.text(offer)), isSemantics(isLiveRegion: false));
      expect(tester.state<ScrollableState>(find.byType(Scrollable).last).position.pixels, 0, reason: 'nothing moves');

      // Not once every reminder is off.
      await tapText(tester, 'Daily reminder');
      expect(find.text(offer), findsOneWidget);
      await tapText(tester, 'Erev Shabbat reminder');
      expect(find.text(offer), findsNothing);
      handle.dispose();
    });

    testWidgets('once answered, is not offered again', (tester) async {
      await openReminders(tester, _Notifications(),
          settings: const AppSettings(onboardingComplete: true, dailyReminder: true, cityOfferAnswered: true));
      expect(find.text(offer), findsNothing);
      await tapText(tester, 'Erev Shabbat reminder');
      expect(find.text(offer), findsNothing);
    });

    testWidgets('the offer meets the accessibility guidelines, at 200% text too', (tester) async {
      final handle = tester.ensureSemantics();
      for (final scale in [1.0, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await openReminders(tester, _Notifications());
        await tapText(tester, 'Daily reminder');
        await tester.ensureVisible(find.text('Choose a city'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
      handle.dispose();
    });

    testWidgets('opens the list of cities, and the reminders then follow the city chosen', (tester) async {
      final c = await openReminders(tester, _Notifications());
      await tapText(tester, 'After-Shabbat check-in');
      await tapText(tester, 'Choose a city');
      expect(find.byType(CityPickerScreen), findsOneWidget);
      expect(c.read(routerProvider).state.uri.path, '/settings/reminders/city');

      await tester.enterText(find.byType(TextField), 'Jerusalem');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jerusalem').last);
      await tester.pumpAndSettle();

      expect(c.read(settingsProvider).city, jerusalem());
      expect(c.read(settingsProvider).cityOfferAnswered, isTrue, reason: 'not offered again without one');
      expect(c.read(routerProvider).state.uri.path, '/settings/reminders');
      expect(find.text(offer), findsNothing);
      expect(
        find.text('Reminders are never sent on Shabbat or Yom Tov, and never more than one a day. '
            'They follow the Shabbat times in \u2068Jerusalem\u2069.'),
        findsOneWidget,
      );
      expect(
        find.text('An hour after Shabbat ends, or Sunday morning when it ends late, to log what you read on Shabbat'),
        findsOneWidget,
      );
    });

    testWidgets('is not offered with a city chosen', (tester) async {
      await openReminders(tester, _Notifications(), settings: AppSettings(onboardingComplete: true, city: jerusalem()));
      await tapText(tester, 'Daily reminder');
      expect(find.text(offer), findsNothing);
    });

    testWidgets('is not offered where the OS refuses notifications', (tester) async {
      await openReminders(tester, _Notifications(allows: false));
      await tapText(tester, 'Daily reminder');
      await tapText(tester, 'OK');
      expect(find.text(offer), findsNothing);
    });

    testWidgets('chosen, the reminders say how they follow its times', (tester) async {
      await openReminders(
        tester,
        _Notifications(),
        settings: AppSettings(
          onboardingComplete: true,
          dailyReminder: true,
          fridayReminder: true,
          checkInReminder: true,
          city: jerusalem(),
        ),
      );
      expect(
        find.text('A gentle nudge at your chosen time, or before candle-lighting on the eve of Shabbat or Yom Tov'),
        findsOneWidget,
      );
      expect(
        find.text("Friday, at least three hours before candle-lighting, only if the parsha isn't finished"),
        findsOneWidget,
      );
      expect(find.text('A gentle nudge at your chosen time'), findsNothing);
      expect(find.text("Friday morning, only if the parsha isn't finished"), findsNothing);
      expect(find.text('Sunday morning, to log what you read on Shabbat'), findsNothing);
    });

    group('the Erev Shabbat time picked', () {
      /// Picks 2:00 PM for the Erev Shabbat reminder, now at 10:00 AM.
      Future<void> pickTwoPm(WidgetTester tester) async {
        await tapText(tester, 'Erev Shabbat reminder time');
        final fields = find.descendant(of: find.byType(TimePickerDialog), matching: find.byType(TextField));
        await tester.enterText(fields.at(0), '2');
        await tester.enterText(fields.at(1), '00');
        await tester.tap(find.text('PM'));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }

      const friday = AppSettings(onboardingComplete: true, fridayReminder: true);

      testWidgets('is kept as it is with a city', (tester) async {
        final c = await openReminders(tester, _Notifications(), settings: friday.copyWith(city: jerusalem()));
        await pickTwoPm(tester);
        expect(c.read(settingsProvider).fridayReminderMinutes, 14 * 60);
        expect(text('2:00 PM'), findsOneWidget);
      });

      testWidgets('comes before midday without one', (tester) async {
        final c = await openReminders(tester, _Notifications(), settings: friday);
        await pickTwoPm(tester);
        expect(c.read(settingsProvider).fridayReminderMinutes, kErevShabbatLatestMinutes);
        expect(text('11:30 AM'), findsOneWidget);
      });
    });

    testWidgets('the Erev Shabbat reminder may be set for the afternoon only with a city', (tester) async {
      const afternoon = AppSettings(onboardingComplete: true, fridayReminder: true, fridayReminderMinutes: 14 * 60);
      final c = await openReminders(tester, _Notifications(), settings: afternoon.copyWith(city: jerusalem()));
      expect(text('2:00 PM'), findsOneWidget);

      // Without one, it comes before midday, and says so.
      c.read(settingsProvider.notifier).update((s) => s.copyWith(city: null));
      await tester.pumpAndSettle();
      expect(text('11:30 AM'), findsOneWidget);
      expect(text('2:00 PM'), findsNothing);
    });
  });
}
