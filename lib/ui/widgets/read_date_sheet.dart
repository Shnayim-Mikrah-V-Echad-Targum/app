import 'package:flutter/material.dart';

import '../../core/calendar/local_date.dart';
import '../../core/calendar/parsha_schedule.dart';
import '../l10n.dart';

/// Asks when something was read — supporting the honor-system logging of
/// reading done from a printed Chumash (including on Shabbat itself).
Future<LocalDate?> pickReadDate(BuildContext context, {required ReadingWeek week, required LocalDate today}) {
  final l = context.l10n;
  final names = Names(context);
  final yesterday = today.addDays(-1);
  final earliest = week.start.addDays(-1); // Shabbat afternoon of the previous week
  final options = <(IconData, String, String?, LocalDate)>[
    (Icons.today, l.whenToday, names.dateLong(today), today),
    if (yesterday >= earliest && yesterday != week.occasion)
      (Icons.history, l.whenYesterday, names.dateLong(yesterday), yesterday),
    if (week.occasion < today && week.occasion.isShabbat)
      (Icons.wb_sunny_outlined, l.whenOnShabbat, names.dateLong(week.occasion), week.occasion),
  ];

  return showModalBottomSheet<LocalDate>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Semantics(
              header: true,
              headingLevel: 2,
              child: Text(l.whenDidYouRead, style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
          for (final (icon, title, subtitle, date) in options)
            ListTile(
              leading: Icon(icon),
              title: Text(title),
              subtitle: subtitle == null ? null : Text(subtitle),
              onTap: () => Navigator.pop(context, date),
            ),
          ListTile(
            leading: const Icon(Icons.edit_calendar),
            title: Text(l.whenPickDate),
            onTap: () async {
              final first = earliest.toDateTime();
              final last = today.toDateTime();
              final picked = await showDatePicker(
                context: context,
                firstDate: first.isAfter(last) ? last : first,
                lastDate: last,
                initialDate: last,
              );
              if (picked != null && context.mounted) Navigator.pop(context, LocalDate.fromDateTime(picked));
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
