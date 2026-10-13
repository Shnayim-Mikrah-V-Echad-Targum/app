import 'package:flutter/material.dart';

import '../../core/calendar/hebrew_date.dart';
import '../../core/calendar/jewish_holidays.dart';
import '../../core/calendar/local_date.dart';
import '../../core/calendar/parsha_schedule.dart';
import '../l10n.dart';
import '../theme/layout.dart';
import 'common.dart';
import 'lines.dart';
import 'paper_group.dart';

/// Whether [day] is a Yom Tov by the reader's custom ([oneDayYomTov]), as
/// the app names one: Yom Kippur, a day of rest too, is not called Yom Tov.
bool isNamedYomTov(LocalDate day, {required bool oneDayYomTov}) {
  final hebrew = HebrewDate.fromLocalDate(day);
  return JewishHolidays.isYomTov(hebrew, israel: oneDayYomTov) && !JewishHolidays.isYomKippur(hebrew);
}

/// The most other days the sheet lists one by one, rather than behind a
/// date picker: a calendar of five weeks to choose among so few is more than
/// the choice needs.
const kListedReadDays = 6;

/// Asks when something was read — supporting the honor-system logging of
/// reading done from a printed Chumash, on Shabbat itself and on each Yom
/// Tov of [week] (by the reader's custom, [oneDayYomTov]) before [today],
/// of the days of rest that run on from its Shabbat (Shavuot on the Sunday
/// after, say), which the check-in asks about too, and of the day of rest
/// before the week where it is a Yom Tov (Simchat Torah, before a week of
/// Bereshit that begins on Monday).
///
/// The days it names (today, yesterday, Shabbat, Yom Tov) come first, on
/// one sheet of paper; then the other days it may have been read on since
/// the Shabbat afternoon before the week, latest first: each a row of its
/// own, dated in both calendars, where they are [kListedReadDays] or fewer,
/// and otherwise behind Choose a date, whose picker marks [today] as today:
/// the app's reading day, which runs on to 3 a.m. and passes over Shabbat
/// and Yom Tov, as the device's date does not.
Future<LocalDate?> pickReadDate(
  BuildContext context, {
  required ReadingWeek week,
  required LocalDate today,
  required bool oneDayYomTov,
}) {
  final l = context.l10n;
  final names = Names(context);
  final hebrewUi = context.isHebrewUi;
  final yesterday = today.addDays(-1);
  final earliest = week.start.addDays(-1); // Shabbat afternoon of the previous week
  final onShabbat = week.occasion < today && week.occasion.isShabbat;
  // Latest first, as the rows above them: Vezot HaBerachah's week holds
  // Sukkot, Shemini Atzeret and Simchat Torah, on any of which it may have
  // been read, and a Shabbat may run on into Yom Tov. The earliest day is
  // named too where it is a Yom Tov, as the check-in's line names it, rather
  // than listed as a plain weekday; the Shabbat before the week is listed
  // plainly, as "On Shabbat" is this week's.
  final lastRest = JewishHolidays.lastRestDay(week.occasion, israel: oneDayYomTov);
  final yomTov = [
    for (var d = lastRest < yesterday ? lastRest : yesterday; d >= earliest; d = d.addDays(-1))
      if (isNamedYomTov(d, oneDayYomTov: oneDayYomTov) && !(onShabbat && d == week.occasion)) d,
  ];
  final named = <(IconData, String, String, LocalDate)>[
    (Icons.today_outlined, l.whenToday, names.practiceDate(today), today),
    // Unless it is named as the Shabbat or Yom Tov it was.
    if (yesterday >= earliest && !(onShabbat && yesterday == week.occasion) && !yomTov.contains(yesterday))
      (Icons.history, l.whenYesterday, names.practiceDate(yesterday), yesterday),
    if (onShabbat) (Icons.wb_sunny_outlined, l.whenOnShabbat, names.practiceDate(week.occasion), week.occasion),
    for (final d in yomTov) (Icons.wb_sunny_outlined, l.whenOnYomTov, names.practiceDate(d), d),
  ];
  final shown = {for (final (_, _, _, date) in named) date};
  final others = [
    for (var d = today.addDays(-2); d >= earliest; d = d.addDays(-1))
      if (!shown.contains(d)) d,
  ];
  final listed = others.length <= kListedReadDays;

  return showAppSheet<LocalDate>(
    context: context,
    // As tall as its days, which in a week of Yom Tov are several: at large
    // text, more than the screen holds, and they scroll.
    isScrollControlled: true,
    builder: (context) {
      // Each chooses its day and closes the sheet, in place: no chevron. Its
      // date breaks, if it must, after the weekday's comma ("Saturday, /
      // September 26"), never inside it.
      PaperRow day(IconData? icon, String title, String subtitle, LocalDate date) => PaperRow(
            icon: icon,
            title: title,
            subtitle: subtitle,
            chevron: false,
            onTap: () => Navigator.pop(context, date),
          );

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: Space.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetTitle(l.whenDidYouRead),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: sheetPadding(context)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PaperGroup(
                      children: [
                        for (final (icon, title, subtitle, date) in named) day(icon, title, subtitle, date),
                        if (!listed)
                          PaperRow(
                            icon: Icons.edit_calendar_outlined,
                            title: l.whenPickDate,
                            chevron: false,
                            onTap: () async {
                              // showDatePicker's dialog, shown the app's way
                              // (instantly under Reduce Motion).
                              final picked = await showAppDialog<DateTime>(
                                context: context,
                                builder: (_) => DatePickerDialog(
                                  firstDate: earliest.toDateTime(),
                                  lastDate: today.toDateTime(),
                                  initialDate: today.toDateTime(),
                                  currentDate: today.toDateTime(),
                                ),
                              );
                              if (picked != null && context.mounted) {
                                Navigator.pop(context, LocalDate.fromDateTime(picked));
                              }
                            },
                          ),
                      ],
                    ),
                    // The other days, on paper of their own, with no icon to
                    // repeat down the rows: each dated as the rows above
                    // date theirs, over its day in the other calendar, as a
                    // week's header gives it ("26 Tishrei", "7 באוקטובר").
                    if (listed && others.isNotEmpty) ...[
                      const Gap(Rhythm.cardGap),
                      PaperGroup(
                        children: [
                          for (final d in others)
                            day(
                              null,
                              names.practiceDate(d),
                              (hebrewUi ? names.dateMonthDay(d) : names.hebrewDayMonth(d))
                                  .replaceAll(' ', DotLine.nbsp),
                              d,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
