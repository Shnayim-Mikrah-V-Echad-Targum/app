import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/features/settings/screens/reminder_settings_screen.dart';
import 'package:shnayim_mikrah/l10n/app_localizations.dart';
import 'package:shnayim_mikrah/ui/theme/app_theme.dart';
import 'package:shnayim_mikrah/ui/widgets/read_date_sheet.dart';

/// The date and time pickers, which the app builds itself to show them its
/// own way (showAppDialog): a confirmed choice comes back to the caller, with
/// motion and without.
void main() {
  /// A page with one button, which runs [open] and keeps what it returns.
  Future<void> pumpLauncher(WidgetTester tester, Future<Object?> Function(BuildContext) open,
      {required bool reduceMotion, required void Function(Object?) onResult, bool hebrew = false}) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(
          mode: AppThemeMode.light, uiFont: UiFont.standard, hebrewUi: hebrew, reduceMotion: reduceMotion),
      locale: Locale(hebrew ? 'he' : 'en'),
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
  // read on Shabbat 10 October. Today is the Wednesday after, with too many
  // days since Simchat Torah for the read-date sheet to list them
  // (read_date_sheet_test.dart), so it offers the calendar.
  final week = ReadingWeek(
    portion: const PortionId(1),
    occasion: LocalDate(2026, 10, 10),
    start: LocalDate(2026, 10, 5),
    plan: const [],
    israel: false,
  );
  final today = LocalDate(2026, 10, 14);

  for (final reduceMotion in [false, true]) {
    testWidgets('a date picked from the calendar is the date read, reduceMotion $reduceMotion', (tester) async {
      Object? result = 'none';
      await pumpLauncher(
        tester,
        (context) => pickReadDate(context, week: week, today: today, oneDayYomTov: false),
        reduceMotion: reduceMotion,
        onResult: (r) => result = r,
      );
      await tester.tap(find.text('Open'));
      await show(tester, reduceMotion: reduceMotion);
      await tester.tap(find.text('Choose a date'));
      await show(tester, reduceMotion: reduceMotion);
      expect(find.byType(DatePickerDialog), findsOneWidget);
      // Today is the app's reading day, whatever the device's clock says (a
      // day later until 3 a.m.): the last day offered.
      final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      expect((picker.currentDate, picker.lastDate), (DateTime(2026, 10, 14), DateTime(2026, 10, 14)));
      expect(picker.firstDate, DateTime(2026, 10, 4));

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

  testWidgets('in the Hebrew UI, the calendar is in Hebrew and a date picked from it is the date read',
      (tester) async {
    Object? result = 'none';
    await pumpLauncher(
      tester,
      (context) => pickReadDate(context, week: week, today: today, oneDayYomTov: false),
      reduceMotion: false,
      onResult: (r) => result = r,
      hebrew: true,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('בחירת תאריך'));
    await tester.pumpAndSettle();
    final dialog = find.byType(DatePickerDialog);
    expect(dialog, findsOneWidget);
    final material = MaterialLocalizations.of(tester.element(dialog));
    expect(Directionality.of(tester.element(dialog)), TextDirection.rtl);
    expect(material.okButtonLabel, isNot('OK'), reason: "the picker's own words in Hebrew");
    await tester.tap(find.text('7'));
    await tester.pump();
    await tester.tap(find.text(material.okButtonLabel));
    await tester.pumpAndSettle();
    expect(result, LocalDate(2026, 10, 7));
  });

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
