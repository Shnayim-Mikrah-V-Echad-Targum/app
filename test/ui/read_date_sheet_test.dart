import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';
import 'package:shnayim_mikra/ui/widgets/read_date_sheet.dart';

/// The sheet that asks when something was read (pickReadDate): the days
/// named, then the other days of the week, listed or behind a date picker.
void main() {
  /// Opens the sheet over a phone-sized page, and keeps what it returns.
  Future<void> open(
    WidgetTester tester, {
    required ReadingWeek week,
    required LocalDate today,
    bool oneDayYomTov = false,
    bool hebrew = false,
    void Function(LocalDate?)? onResult,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(mode: AppThemeMode.light, uiFont: UiFont.standard, hebrewUi: hebrew, reduceMotion: false),
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
            child: TextButton(
              onPressed: () async {
                final date = await pickReadDate(context, week: week, today: today, oneDayYomTov: oneDayYomTov);
                onResult?.call(date);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  final sheet = find.byType(BottomSheet);
  final groups = find.descendant(of: sheet, matching: find.byType(PaperGroup));

  /// Each row's title and subtitle in [group] (every group where null),
  /// no-break spaces read as spaces.
  List<(String, String?)> rows(WidgetTester tester, {int? group}) => [
        for (final row in tester.widgetList<PaperRow>(
          find.descendant(of: group == null ? sheet : groups.at(group), matching: find.byType(PaperRow)),
        ))
          (row.title.replaceAll('\u00A0', ' '), row.subtitle?.replaceAll('\u00A0', ' ')),
      ];

  // The week of Bereshit 5787, read on Shabbat 10 October after Simchat
  // Torah (Diaspora) on Sunday the 4th, as the screenshots have it: the
  // reader joined on Simchat Torah, and today is the Friday.
  final bereshit = ReadingWeek(
    portion: const PortionId(1),
    occasion: LocalDate(2026, 10, 10),
    start: LocalDate(2026, 10, 5),
    plan: const [],
    israel: false,
  );
  final friday = LocalDate(2026, 10, 9);

  group('the other days of a week', () {
    testWidgets('are listed one by one when few, under the days named, with no date picker', (tester) async {
      await open(tester, week: bereshit, today: friday);
      expect(groups, findsNWidgets(2));
      expect(find.descendant(of: sheet, matching: find.byType(ListTile)), findsNothing);
      // Simchat Torah, the Sunday before the week, is named as the Yom Tov
      // it was, as the check-in's line names it.
      expect(rows(tester, group: 0), [
        ('Today', 'Friday, October 9'),
        ('Yesterday', 'Thursday, October 8'),
        ('On Yom Tov', 'Sunday, October 4'),
      ]);
      // Back to the Monday the week began, latest first, each over its day
      // in the Hebrew calendar.
      expect(rows(tester, group: 1), [
        ('Wednesday, October 7', '26 Tishrei'),
        ('Tuesday, October 6', '25 Tishrei'),
        ('Monday, October 5', '24 Tishrei'),
      ]);
      expect(find.text('Choose a date'), findsNothing);
    });

    testWidgets('are dated in the Hebrew calendar in Hebrew, over the civil date', (tester) async {
      await open(tester, week: bereshit, today: friday, hebrew: true);
      expect(rows(tester), [
        ('היום', 'יום שישי, כ״ח בתשרי'),
        ('אתמול', 'יום חמישי, כ״ז בתשרי'),
        ('ביום טוב', 'יום ראשון, כ״ג בתשרי'),
        ('יום רביעי, כ״ו בתשרי', '7 באוקטובר'),
        ('יום שלישי, כ״ה בתשרי', '6 באוקטובר'),
        ('יום שני, כ״ד בתשרי', '5 באוקטובר'),
      ]);
    });

    testWidgets('are each the day read, as the sheet closes', (tester) async {
      LocalDate? result;
      await open(tester, week: bereshit, today: friday, onResult: (d) => result = d);
      await tester.tap(find.text('Tuesday, October\u00A06'));
      await tester.pumpAndSettle();
      expect(result, LocalDate(2026, 10, 6));
      expect(find.text('When did you read it?'), findsNothing);
    });

    testWidgets('are listed up to $kListedReadDays', (tester) async {
      // The Tuesday after Shabbat: six days besides today, yesterday,
      // Shabbat and Simchat Torah.
      await open(tester, week: bereshit, today: LocalDate(2026, 10, 13));
      expect(
        [for (final (title, _) in rows(tester, group: 0)) title],
        ['Today', 'Yesterday', 'On Shabbat', 'On Yom Tov'],
      );
      expect(rows(tester, group: 1), hasLength(kListedReadDays));
      expect(rows(tester, group: 1).first, ('Sunday, October 11', '30 Tishrei'));
      expect(rows(tester, group: 1).last, ('Monday, October 5', '24 Tishrei'));
      expect(find.text('Choose a date'), findsNothing);
    });

    testWidgets('are left to the date picker beyond $kListedReadDays', (tester) async {
      // The Wednesday after Shabbat: seven.
      await open(tester, week: bereshit, today: LocalDate(2026, 10, 14));
      expect(groups, findsOneWidget);
      expect(rows(tester), [
        ('Today', 'Wednesday, October 14'),
        ('Yesterday', 'Tuesday, October 13'),
        ('On Shabbat', 'Saturday, October 10'),
        ('On Yom Tov', 'Sunday, October 4'),
        ('Choose a date', null),
      ]);
    });

    testWidgets('are none when the week has only begun, and nothing is left to choose', (tester) async {
      // The Monday the week opens: yesterday was the earliest day, Simchat
      // Torah, named as the Yom Tov it was.
      await open(tester, week: bereshit, today: LocalDate(2026, 10, 5));
      expect(groups, findsOneWidget);
      expect(rows(tester), [
        ('Today', 'Monday, October 5'),
        ('On Yom Tov', 'Sunday, October 4'),
      ]);
    });

    // A week of the usual shape, Sunday to Shabbat: Noach 5787. The Shabbat
    // before it, Bereshit's, is a plain day of the list.
    final noach = ReadingWeek(
      portion: const PortionId(2),
      occasion: LocalDate(2026, 10, 17),
      start: LocalDate(2026, 10, 11),
      plan: const [],
      israel: false,
    );

    testWidgets('of a usual week are listed through the week, back to the Shabbat before it', (tester) async {
      // Its Friday: five days besides today and yesterday.
      await open(tester, week: noach, today: LocalDate(2026, 10, 16));
      expect([for (final (title, _) in rows(tester, group: 0)) title], ['Today', 'Yesterday']);
      expect(rows(tester, group: 1), hasLength(5));
      expect(rows(tester, group: 1).last, ('Saturday, October 10', '29 Tishrei'));
    });

    // After Shabbat, the check-in's usual days, a week of seven days leaves
    // seven others (Friday back to the Shabbat before), one more than
    // kListedReadDays, so the date picker offers them, as it does on the
    // Sunday and the Monday after.
    for (final (day, today) in [('Sunday', LocalDate(2026, 10, 18)), ('Monday', LocalDate(2026, 10, 19))]) {
      testWidgets('of a usual week are left to the date picker on the $day after its Shabbat', (tester) async {
        await open(tester, week: noach, today: today);
        expect(groups, findsOneWidget);
        expect([for (final (title, _) in rows(tester)) title], [
          'Today',
          if (day == 'Monday') 'Yesterday',
          'On Shabbat',
          'Choose a date',
        ]);
      });
    }
  });

  group('the rows', () {
    testWidgets('take outlined icons where they name the day, and no chevron, as each chooses in place',
        (tester) async {
      // The Tuesday after Shabbat: today, yesterday, Shabbat, Simchat Torah,
      // and six days listed.
      await open(tester, week: bereshit, today: LocalDate(2026, 10, 13));
      final all = tester.widgetList<PaperRow>(find.descendant(of: sheet, matching: find.byType(PaperRow))).toList();
      expect([for (final r in all) r.icon], [
        Icons.today_outlined,
        Icons.history,
        Icons.wb_sunny_outlined,
        Icons.wb_sunny_outlined,
        ...List.filled(kListedReadDays, null),
      ]);
      expect(all.where((r) => r.chevron), isEmpty);
    });

    testWidgets('choose a date from an outlined calendar with a pen, with no chevron', (tester) async {
      await open(tester, week: bereshit, today: LocalDate(2026, 10, 14));
      final picker =
          tester.widget<PaperRow>(find.ancestor(of: find.text('Choose a date'), matching: find.byType(PaperRow)));
      expect((picker.icon, picker.chevron), (Icons.edit_calendar_outlined, false));
    });

    for (final hebrew in [false, true]) {
      testWidgets("${hebrew ? 'he' : 'en'}: are on paper on the sheet's padding, lined up with its title",
          (tester) async {
        await open(tester, week: bereshit, today: friday, hebrew: hebrew);
        final box = tester.getRect(sheet);
        final heading = find.descendant(of: sheet, matching: find.byType(SheetTitle));
        final title = tester.getRect(find.descendant(of: heading, matching: find.byType(RichText)));
        double fromStart(Rect r) => hebrew ? box.right - r.right : r.left - box.left;
        expect(fromStart(title), 24);
        for (var g = 0; g < 2; g++) {
          expect(fromStart(tester.getRect(groups.at(g))), 24);
        }
        // The days named, past their icons; the days listed, which have
        // none, at the paper's own inset.
        for (final (g, inset) in [(0, PaperGroup.iconInset), (1, PaperGroup.plainInset)]) {
          final inGroup = find.descendant(of: groups.at(g), matching: find.byType(PaperRow));
          for (final row in tester.widgetList<PaperRow>(inGroup)) {
            final text = tester.getRect(find.descendant(of: sheet, matching: find.text(row.title)));
            expect(fromStart(text), 24 + inset, reason: row.title);
          }
        }
      });
    }

    testWidgets('ring their focus from the keyboard, rather than wash it', (tester) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      await open(tester, week: bereshit, today: friday);
      final row = find.ancestor(of: find.text('Tuesday, October\u00A06'), matching: find.byType(PaperRow));
      final well = find.descendant(of: row, matching: find.byType(SeferInkWell));
      // The ink well's own node, as Tab would reach it.
      tester.widget<Focus>(find.descendant(of: well, matching: find.byType(Focus)).first).focusNode!.requestFocus();
      await tester.pumpAndSettle();
      final box = tester.widget<DecoratedBox>(find.descendant(of: well, matching: find.byType(DecoratedBox)).first);
      final shape = (box.decoration as ShapeDecoration).shape as RoundedRectangleBorder;
      expect(shape.side.color, SeferColors.of(tester.element(row)).focus);
      expect(shape.side.width, 3);
      expect(tester.widget<InkWell>(find.descendant(of: well, matching: find.byType(InkWell))).focusColor,
          Colors.transparent);
    });
  });

  group('the days of rest offered', () {
    // The week of Vezot HaBerachah 5787 outside Israel, from Shabbat Shuva to
    // Simchat Torah on Sunday 4 October; today is the Monday after.
    final vezot = ReadingWeek(
      portion: const PortionId(kVezotHaberakhah),
      occasion: LocalDate(2026, 10, 4),
      start: LocalDate(2026, 9, 20),
      plan: const [],
      israel: false,
    );
    final monday = LocalDate(2026, 10, 5);

    testWidgets('are each Yom Tov of the week, latest first, Yom Kippur not among them', (tester) async {
      await open(tester, week: vezot, today: monday);
      expect(rows(tester), [
        ('Today', 'Monday, October 5'),
        // Yesterday is named as the Yom Tov it was.
        ('On Yom Tov', 'Sunday, October 4'),
        ('On Yom Tov', 'Saturday, October 3'),
        ('On Yom Tov', 'Sunday, September 27'),
        ('On Yom Tov', 'Saturday, September 26'),
        // Two weeks of other days: too many to list.
        ('Choose a date', null),
      ]);
    });

    testWidgets('follow the days of Yom Tov the reader keeps', (tester) async {
      // An Israeli abroad, who hears the Diaspora's reading: Simchat Torah
      // was the day after Yom Tov for them.
      await open(tester, week: vezot, today: monday, oneDayYomTov: true);
      expect(rows(tester), [
        ('Today', 'Monday, October 5'),
        ('Yesterday', 'Sunday, October 4'),
        ('On Yom Tov', 'Saturday, October 3'),
        ('On Yom Tov', 'Saturday, September 26'),
        ('Choose a date', null),
      ]);
    });

    testWidgets('are dated in the Hebrew calendar in Hebrew, as the check-in dates them', (tester) async {
      await open(tester, week: vezot, today: monday, hebrew: true);
      expect(rows(tester), [
        ('היום', 'יום שני, כ״ד בתשרי'),
        ('ביום טוב', 'יום ראשון, כ״ג בתשרי'),
        ('ביום טוב', 'יום שבת, כ״ב בתשרי'),
        ('ביום טוב', 'יום ראשון, ט״ז בתשרי'),
        ('ביום טוב', 'יום שבת, ט״ו בתשרי'),
        ('בחירת תאריך', null),
      ]);
    });

    testWidgets('name Shabbat as such, though it is Yom Tov too', (tester) async {
      // Israel's week of Vezot HaBerachah, read on Shabbat 3 October.
      final israel = ReadingWeek(
        portion: const PortionId(kVezotHaberakhah),
        occasion: LocalDate(2026, 10, 3),
        start: LocalDate(2026, 9, 20),
        plan: const [],
        israel: true,
      );
      await open(tester, week: israel, today: LocalDate(2026, 10, 4), oneDayYomTov: true);
      expect(
        [for (final (title, _) in rows(tester)) title],
        ['Today', 'On Shabbat', 'On Yom Tov', 'Choose a date'],
      );
    });
  });
}
