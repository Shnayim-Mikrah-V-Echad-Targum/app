import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/city_providers.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/data/city_directory.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/settings/screens/city_picker_screen.dart';
import 'package:shnayim_mikra/ui/widgets/sefer_choice_chip.dart';

import '../../helpers.dart';

/// Reminders that can be scheduled, where the OS [allows] them or not.
class _AskingNotifications extends PhoneNotifications {
  _AskingNotifications({required this.allows});

  final bool allows;
  var asked = 0;

  @override
  Future<bool> requestPermission() async {
    asked++;
    return allows;
  }
}

/// The offer of reminders after the first aliyah ever finished: the routine
/// to read after and the time, kept when the reader says yes.
void main() {
  final monday = DateTime(2026, 10, 12, 10); // week of Noach, 5787
  late CityDirectory directory;
  setUpAll(() => directory = CityDirectory.parse(File('assets/data/cities.json').readAsStringSync()));
  const cityOffer = "Reminders are on. Choose your city, and they'll follow its Shabbat times.";

  /// Finishes Rishon of Noach, the reader's first aliyah, read by aliyah, so
  /// that reminders are offered.
  Future<ProviderContainer> finishFirstAliyah(WidgetTester tester, _AskingNotifications service,
      {AppSettings settings = const AppSettings(onboardingComplete: true, method: ReadingMethod.aliyahByAliyah),
      Size size = const Size(412, 915)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(
      tester,
      settings: settings,
      now: monday,
      notifications: service,
      overrides: [cityDirectoryProvider.overrideWith((ref) => directory)],
    );
    c.read(routerProvider).go('/read/5787:2/0');
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    // Next, and on the aliyah's last step Finish.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byWidgetPredicate((w) => w is Text && (w.data == 'Next' || w.data == 'Finish')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Want a gentle daily nudge?'), findsOneWidget);
    return c;
  }

  Finder inDialog(Finder f) => find.descendant(of: find.byType(AlertDialog), matching: f);

  SeferChoiceChip chip(WidgetTester tester, String label) =>
      tester.widget<SeferChoiceChip>(find.ancestor(of: find.text(label), matching: find.byType(SeferChoiceChip)));

  /// The time in the offer, as "At 8:00 PM" (which has a narrow space).
  Finder at(String time) => inDialog(find.textContaining(RegExp('^At ${time.replaceAll(' ', r'\s')}\$')));

  /// Changes the time in the offer, [from] as [at] finds it, to [hour]:[minute]
  /// in the same half of the day.
  Future<void> changeTime(WidgetTester tester, {required String from, required int hour, required int minute}) async {
    await tester.tap(at(from));
    await tester.pumpAndSettle();
    final fields = find.descendant(of: find.byType(TimePickerDialog), matching: find.byType(TextField));
    await tester.enterText(fields.at(0), '$hour');
    await tester.enterText(fields.at(1), '$minute');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('asks after which routine and when, and Yes keeps both with the reminders on', (tester) async {
    final service = _AskingNotifications(allows: true);
    final c = await finishFirstAliyah(tester, service);

    expect(inDialog(find.text('After I…')), findsOneWidget);
    for (final label in ['finish Shacharit', 'eat breakfast', 'start my commute', 'finish dinner', 'get ready for bed']) {
      expect(chip(tester, label).selected, isFalse, reason: label);
    }
    await tester.tap(find.text('finish dinner'));
    await tester.pumpAndSettle();
    expect(chip(tester, 'finish dinner').selected, isTrue);

    await changeTime(tester, from: '8:00 PM', hour: 9, minute: 15);
    expect(at('9:15 PM'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'the offer stays open');
    expect(c.read(settingsProvider).dailyReminderMinutes, 20 * 60, reason: 'nothing is kept before the answer');

    await tester.tap(find.text('Yes, remind me'));
    await tester.pumpAndSettle();
    expect(service.asked, 1);
    final s = c.read(settingsProvider);
    expect(s.habitAnchor, HabitAnchor.dinner);
    expect(s.dailyReminderMinutes, 21 * 60 + 15);
    expect((s.dailyReminder, s.fridayReminder, s.checkInReminder), (true, true, true));
    expect(s.notificationPromptShown, isTrue);
  });

  testWidgets('refused by the OS, the routine and time are kept for later, with the reminders off', (tester) async {
    final service = _AskingNotifications(allows: false);
    final c = await finishFirstAliyah(tester, service);

    await tester.tap(find.text('finish Shacharit'));
    await tester.pumpAndSettle();
    await changeTime(tester, from: '7:30 AM', hour: 6, minute: 30);
    await tester.tap(find.text('Yes, remind me'));
    await tester.pumpAndSettle();

    final s = c.read(settingsProvider);
    expect(s.habitAnchor, HabitAnchor.shacharit);
    expect(s.dailyReminderMinutes, 6 * 60 + 30);
    expect((s.dailyReminder, s.fridayReminder, s.checkInReminder), (false, false, false));
    expect(find.text(cityOffer), findsNothing, reason: 'no reminders to time');
  });

  testWidgets('a routine chosen proposes its usual time, which is read out, until the reader picks one',
      (tester) async {
    final handle = tester.ensureSemantics();
    final c = await finishFirstAliyah(tester, _AskingNotifications(allows: true));
    expect(at('8:00 PM'), findsOneWidget);
    expect(tester.getSemantics(at('8:00 PM')), isSemantics(isLiveRegion: false, isButton: true));

    // A morning routine at 8 PM would be a cue that contradicts its time.
    await tester.tap(find.text('finish Shacharit'));
    await tester.pumpAndSettle();
    expect(at('7:30 AM'), findsOneWidget);
    expect(tester.getSemantics(at('7:30 AM')), isSemantics(isLiveRegion: true, isButton: true));
    await tester.tap(find.text('get ready for bed'));
    await tester.pumpAndSettle();
    expect(at('9:30 PM'), findsOneWidget);
    // Cleared, the time stays.
    await tester.tap(find.text('get ready for bed'));
    await tester.pumpAndSettle();
    expect(at('9:30 PM'), findsOneWidget);

    // A time picked stays, even the default, whatever routine is chosen.
    await changeTime(tester, from: '9:30 PM', hour: 8, minute: 0);
    await tester.tap(find.text('eat breakfast'));
    await tester.pumpAndSettle();
    expect(at('8:00 PM'), findsOneWidget);

    await tester.tap(find.text('Yes, remind me'));
    await tester.pumpAndSettle();
    final s = c.read(settingsProvider);
    expect((s.habitAnchor, s.dailyReminderMinutes), (HabitAnchor.breakfast, 20 * 60));
    handle.dispose();
  });

  testWidgets('once reminders are on without a city, the list of cities is offered, and leads back to the reader',
      (tester) async {
    final c = await finishFirstAliyah(tester, _AskingNotifications(allows: true));
    await tester.tap(find.text('Yes, remind me'));
    await tester.pumpAndSettle();
    expect(find.text(cityOffer), findsOneWidget);

    await tester.tap(find.text('Choose a city'));
    await tester.pumpAndSettle();
    expect(find.byType(CityPickerScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Jerusalem');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jerusalem').last);
    await tester.pumpAndSettle();

    final s = c.read(settingsProvider);
    expect(s.city?.nameEn, 'Jerusalem');
    expect(s.cityOfferAnswered, isTrue, reason: 'Reminders offers it no more');
    expect(c.read(routerProvider).state.uri.path, '/read/5787:2/0');
  });

  testWidgets('with a city chosen, or the offer of one answered, no city is offered', (tester) async {
    for (final settings in [
      AppSettings(
        onboardingComplete: true,
        method: ReadingMethod.aliyahByAliyah,
        city: directory.cities.firstWhere((c) => c.nameEn == 'London'),
      ),
      const AppSettings(onboardingComplete: true, method: ReadingMethod.aliyahByAliyah, cityOfferAnswered: true),
    ]) {
      final c = await finishFirstAliyah(tester, _AskingNotifications(allows: true), settings: settings);
      await tester.tap(find.text('Yes, remind me'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).dailyReminder, isTrue);
      expect(find.text(cityOffer), findsNothing);
    }
  });

  testWidgets('the offer is about notifications, with their icon', (tester) async {
    await finishFirstAliyah(tester, _AskingNotifications(allows: true));
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.byIcon(Icons.notifications_outlined)),
        findsOneWidget);
    expect(find.byIcon(Icons.celebration_outlined), findsNothing);
  });

  testWidgets('on a wide screen, the offer is no wider than a Material dialog', (tester) async {
    await finishFirstAliyah(tester, _AskingNotifications(allows: true), size: const Size(1366, 860));
    final dialog = find.descendant(of: find.byType(AlertDialog), matching: find.byType(Material)).first;
    expect(tester.getSize(dialog).width, 560);
  });

  testWidgets('Not now keeps nothing chosen in the offer, and it is not made again', (tester) async {
    final service = _AskingNotifications(allows: true);
    final c = await finishFirstAliyah(tester, service);

    await tester.tap(find.text('get ready for bed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(service.asked, 0);
    final s = c.read(settingsProvider);
    expect(s.habitAnchor, isNull);
    expect(s.dailyReminder, isFalse);
    expect(s.notificationPromptShown, isTrue);
  });

  testWidgets('starts from the routine and time already chosen, and a chosen routine can be cleared', (tester) async {
    final service = _AskingNotifications(allows: true);
    final c = await finishFirstAliyah(
      tester,
      service,
      settings: const AppSettings(
        onboardingComplete: true,
        method: ReadingMethod.aliyahByAliyah,
        habitAnchor: HabitAnchor.commute,
        dailyReminderMinutes: 7 * 60,
      ),
    );

    expect(chip(tester, 'start my commute').selected, isTrue);
    expect(at('7:00 AM'), findsOneWidget);
    await tester.tap(find.text('start my commute'));
    await tester.pumpAndSettle();
    expect(chip(tester, 'start my commute').selected, isFalse);
    await tester.tap(find.text('Yes, remind me'));
    await tester.pumpAndSettle();

    final s = c.read(settingsProvider);
    expect(s.habitAnchor, isNull);
    expect(s.dailyReminderMinutes, 7 * 60);
  });
}
