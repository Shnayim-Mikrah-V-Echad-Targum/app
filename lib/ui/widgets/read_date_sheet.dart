import 'package:flutter/material.dart';

import '../../core/calendar/hebrew_date.dart';
import '../../core/calendar/jewish_holidays.dart';
import '../../core/calendar/local_date.dart';
import '../../core/calendar/parsha_schedule.dart';
import '../l10n.dart';
import 'common.dart';
import 'lines.dart';

/// Whether [day] is a Yom Tov by the reader's custom ([oneDayYomTov]), as
/// the app names one: Yom Kippur, a day of rest too, is not called Yom Tov.
bool isNamedYomTov(LocalDate day, {required bool oneDayYomTov}) {
  final hebrew = HebrewDate.fromLocalDate(day);
  return JewishHolidays.isYomTov(hebrew, israel: oneDayYomTov) && !JewishHolidays.isYomKippur(hebrew);
}

/// Asks when something was read — supporting the honor-system logging of
/// reading done from a printed Chumash, on Shabbat itself and on each Yom
/// Tov of [week] (by the reader's custom, [oneDayYomTov]) before [today],
/// and of the days of rest that run on from its Shabbat (Shavuot on the
/// Sunday after, say), which the check-in asks about too.
Future<LocalDate?> pickReadDate(
  BuildContext context, {
  required ReadingWeek week,
  required LocalDate today,
  required bool oneDayYomTov,
}) {
  final l = context.l10n;
  final names = Names(context);
  final yesterday = today.addDays(-1);
  final earliest = week.start.addDays(-1); // Shabbat afternoon of the previous week
  final onShabbat = week.occasion < today && week.occasion.isShabbat;
  // Latest first, as the rows above them: Vezot HaBerachah's week holds
  // Sukkot, Shemini Atzeret and Simchat Torah, on any of which it may have
  // been read, and a Shabbat may run on into Yom Tov.
  final lastRest = JewishHolidays.lastRestDay(week.occasion, israel: oneDayYomTov);
  final yomTov = [
    for (var d = lastRest < yesterday ? lastRest : yesterday; d >= week.start; d = d.addDays(-1))
      if (isNamedYomTov(d, oneDayYomTov: oneDayYomTov) && !(onShabbat && d == week.occasion)) d,
  ];
  final options = <(IconData, String, String?, LocalDate)>[
    (Icons.today, l.whenToday, names.practiceDate(today), today),
    // Unless it is named as the Shabbat or Yom Tov it was.
    if (yesterday >= earliest && !(onShabbat && yesterday == week.occasion) && !yomTov.contains(yesterday))
      (Icons.history, l.whenYesterday, names.practiceDate(yesterday), yesterday),
    if (onShabbat) (Icons.wb_sunny_outlined, l.whenOnShabbat, names.practiceDate(week.occasion), week.occasion),
    for (final d in yomTov) (Icons.wb_sunny_outlined, l.whenOnYomTov, names.practiceDate(d), d),
  ];

  return showAppSheet<LocalDate>(
    context: context,
    // As tall as its days, which in a week of Yom Tov are several: at large
    // text, more than the screen holds, and they scroll.
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(l.whenDidYouRead),
            for (final (icon, title, subtitle, date) in options)
              ListTile(
                leading: Icon(icon),
                title: Text(title),
                // Broken, if it must be, after its comma: "Saturday, /
                // September 26", never inside the date.
                subtitle: subtitle == null ? null : DotLine([subtitle]),
                onTap: () => Navigator.pop(context, date),
              ),
            ListTile(
              leading: const Icon(Icons.edit_calendar),
              title: Text(l.whenPickDate),
              onTap: () async {
                final first = earliest.toDateTime();
                final last = today.toDateTime();
                // showDatePicker's dialog, shown the app's way (instantly
                // under Reduce Motion).
                final picked = await showAppDialog<DateTime>(
                  context: context,
                  builder: (_) => DatePickerDialog(
                    firstDate: first.isAfter(last) ? last : first,
                    lastDate: last,
                    initialDate: last,
                  ),
                );
                if (picked != null && context.mounted) Navigator.pop(context, LocalDate.fromDateTime(picked));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
