import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/settings/screens/reminder_settings_screen.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/widgets/read_date_sheet.dart';

/// The date and time pickers, which the app builds itself to show them its
/// own way (showAppDialog): a confirmed choice comes back to the caller, with
/// motion and without.
void main() {
  /// A page with one button, which runs [open] and keeps what it returns.
  Future<void> pumpLauncher(WidgetTester tester, Future<Object?> Function(BuildContext) open,
      {required bool reduceMotion, required void Function(Object?) onResult}) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(
          mode: AppThemeMode.light, uiFont: UiFont.standard, hebrewUi: false, reduceMotion: reduceMotion),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(onPressed: () async => onResult(await open(context)), child: const Text('Open')),
          ),
        ),
      ),
    ));
  }

  /// Settles, or with motion reduced checks that one frame is enough.
  Future<void> show(WidgetTester tester, {required bool reduceMotion}) async {
    if (reduceMotion) {
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    } else {
      await tester.pumpAndSettle();
    }
  }

  // The week of Bereshit 5787: Simchat Torah (Diaspora) on Sunday 4 October,
  // read on Shabbat 10 October. Today is the Friday.
  final week = ReadingWeek(
    portion: const PortionId(1),
    occasion: LocalDate(2026, 10, 10),
    start: LocalDate(2026, 10, 5),
    plan: const [],
    israel: false,
  );
  final today = LocalDate(2026, 10, 9);

  for (final reduceMotion in [false, true]) {
    testWidgets('a date picked from the calendar is the date read, reduceMotion $reduceMotion', (tester) async {
      Object? result = 'none';
      await pumpLauncher(
        tester,
        (context) => pickReadDate(context, week: week, today: today),
        reduceMotion: reduceMotion,
        onResult: (r) => result = r,
      );
      await tester.tap(find.text('Open'));
      await show(tester, reduceMotion: reduceMotion);
      await tester.tap(find.text('Choose a date'));
      await show(tester, reduceMotion: reduceMotion);
      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('7'));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result, LocalDate(2026, 10, 7));
      // The sheet closed with it.
      expect(find.text('When did you read it?'), findsNothing);
    });

    testWidgets('a typed reminder time comes back in minutes, reduceMotion $reduceMotion', (tester) async {
      Object? result = 'none';
      await pumpLauncher(
        tester,
        (context) => pickReminderTime(context, 7 * 60 + 30),
        reduceMotion: reduceMotion,
        onResult: (r) => result = r,
      );
      await tester.tap(find.text('Open'));
      await show(tester, reduceMotion: reduceMotion);
      expect(find.byType(TimePickerDialog), findsOneWidget);

      final fields = find.descendant(of: find.byType(TimePickerDialog), matching: find.byType(TextField));
      await tester.enterText(fields.at(0), '9');
      await tester.enterText(fields.at(1), '45');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result, 9 * 60 + 45);
    });
  }

  testWidgets('cancelling the time picker returns nothing', (tester) async {
    Object? result = 'none';
    await pumpLauncher(tester, (context) => pickReminderTime(context, 420),
        reduceMotion: false, onResult: (r) => result = r);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
