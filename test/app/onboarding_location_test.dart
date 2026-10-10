import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/features/onboarding/onboarding_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../helpers.dart';

/// The location step of onboarding: Israel guessed from the device's IANA
/// time zone, which flutter_timezone gives on every platform (on the web,
/// from Intl's resolvedOptions().timeZone).
void main() {
  const channel = MethodChannel('flutter_timezone');

  /// Answers getLocalTimezone with [zone] (or, given a future, when it
  /// completes), as the platform would.
  void deviceIn(WidgetTester tester, FutureOr<String> zone) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getLocalTimezone') return zone;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
  }

  Future<void> openLocationStep(WidgetTester tester) async {
    await tester.tap(find.text("Start this week's parsha"));
    await tester.pumpAndSettle();
    expect(find.text('Where will you be this Shabbat?'), findsOneWidget);
  }

  ReadingSchedule selected(WidgetTester tester) =>
      tester.widget<RadioGroup<ReadingSchedule>>(find.byType(RadioGroup<ReadingSchedule>)).groupValue!;

  for (final zone in ['Asia/Jerusalem', 'Asia/Tel_Aviv']) {
    testWidgets('a device set to $zone starts on Israel', (tester) async {
      deviceIn(tester, zone);
      final c = await pumpApp(tester, settings: const AppSettings());
      await tester.pumpAndSettle();
      await openLocationStep(tester);
      expect(selected(tester), ReadingSchedule.israel);
      final s = c.read(settingsProvider);
      expect(s.readingSchedule, ReadingSchedule.israel);
      expect(s.oneDayYomTov, isTrue, reason: 'the location sets the days of Yom Tov too');
    });
  }

  // "IST" is India's (and Ireland's) as much as Israel's, and a long name
  // such as the web's DateTime.timeZoneName gives is no IANA name at all.
  for (final zone in ['Europe/London', 'America/New_York', 'IST', 'Israel Daylight Time']) {
    testWidgets('a device set to $zone starts outside Israel', (tester) async {
      deviceIn(tester, zone);
      final c = await pumpApp(tester, settings: const AppSettings());
      await tester.pumpAndSettle();
      await openLocationStep(tester);
      expect(selected(tester), ReadingSchedule.diaspora);
      expect(c.read(settingsProvider).oneDayYomTov, isFalse);
    });
  }

  testWidgets('with no time zone to be had, starts outside Israel', (tester) async {
    // No handler: the plugin is missing, as in any test that doesn't mock it.
    final c = await pumpApp(tester, settings: const AppSettings());
    await tester.pumpAndSettle();
    await openLocationStep(tester);
    expect(selected(tester), ReadingSchedule.diaspora);
    expect(tester.takeException(), isNull);
    expect(c.read(settingsProvider).readingSchedule, ReadingSchedule.diaspora);
  });

  testWidgets("a late guess never overrides the reader's own choice", (tester) async {
    final zone = Completer<String>();
    deviceIn(tester, zone.future);
    final c = await pumpApp(tester, settings: const AppSettings());
    await tester.pumpAndSettle();
    await openLocationStep(tester);
    await tester.tap(find.text('In Israel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outside Israel'));
    await tester.pumpAndSettle();

    zone.complete('Asia/Jerusalem');
    await tester.pumpAndSettle();
    expect(selected(tester), ReadingSchedule.diaspora);
    expect(c.read(settingsProvider).readingSchedule, ReadingSchedule.diaspora);
  });

  testWidgets('a late guess never overrides the location the reader went on with', (tester) async {
    final zone = Completer<String>();
    deviceIn(tester, zone.future);
    final c = await pumpApp(tester, settings: const AppSettings());
    await tester.pumpAndSettle();
    await openLocationStep(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('How do you read?'), findsOneWidget);

    zone.complete('Asia/Jerusalem');
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).readingSchedule, ReadingSchedule.diaspora);
    expect(c.read(settingsProvider).oneDayYomTov, isFalse);
  });

  testWidgets('a choice made before the app was closed outlasts the guess when it opens again', (tester) async {
    // Outside Israel, chosen and saved; then the app was closed before the
    // end of onboarding, on a phone that has since moved to Israel time.
    deviceIn(tester, 'Asia/Jerusalem');
    final c = await pumpApp(
      tester,
      settings: const AppSettings().locatedIn(ReadingSchedule.diaspora),
      stored: {OnboardingScreen.locationChosenKey: true},
    );
    await tester.pumpAndSettle();
    await openLocationStep(tester);
    expect(selected(tester), ReadingSchedule.diaspora);
    final s = c.read(settingsProvider);
    expect(s.readingSchedule, ReadingSchedule.diaspora);
    expect(s.oneDayYomTov, isFalse);
  });

  testWidgets('choosing is remembered for the next time the app opens', (tester) async {
    deviceIn(tester, 'Asia/Jerusalem');
    final c = await pumpApp(tester, settings: const AppSettings());
    await tester.pumpAndSettle();
    final prefs = c.read(sharedPreferencesProvider);
    expect(prefs.getBool(OnboardingScreen.locationChosenKey), isNull, reason: 'the guess is no choice');
    await openLocationStep(tester);
    await tester.tap(find.text('Outside Israel'));
    await tester.pumpAndSettle();
    expect(prefs.getBool(OnboardingScreen.locationChosenKey), isTrue);
  });

  testWidgets('the guess is made once: going back to the welcome keeps the choice', (tester) async {
    deviceIn(tester, 'Asia/Jerusalem');
    final c = await pumpApp(tester, settings: const AppSettings());
    await tester.pumpAndSettle();
    await openLocationStep(tester);
    expect(selected(tester), ReadingSchedule.israel);
    await tester.tap(find.text('Outside Israel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await openLocationStep(tester);
    expect(selected(tester), ReadingSchedule.diaspora);
    expect(c.read(settingsProvider).readingSchedule, ReadingSchedule.diaspora);
  });

  testWidgets('"Why we ask" shows and hides the reason, and says which', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, settings: const AppSettings());
    await tester.pumpAndSettle();
    await openLocationStep(tester);
    final help = find.textContaining('Israel and the Diaspora sometimes read different parshiyot');
    final why = find.widgetWithText(TextButton, 'Why we ask');
    expect(help, findsNothing);
    expect(
      tester.getSemantics(why),
      isSemantics(label: 'Why we ask', isButton: true, hasExpandedState: true, isExpanded: false, hasTapAction: true),
    );

    await tester.tap(why);
    await tester.pumpAndSettle();
    expect(help, findsOneWidget);
    expect(tester.getSemantics(why), isSemantics(label: 'Why we ask', hasExpandedState: true, isExpanded: true));

    await tester.tap(why);
    await tester.pumpAndSettle();
    expect(help, findsNothing);
    handle.dispose();
  });
}
