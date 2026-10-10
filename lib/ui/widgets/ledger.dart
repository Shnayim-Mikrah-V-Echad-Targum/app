import 'package:flutter/material.dart';

import '../l10n.dart';
import '../theme/sefer_colors.dart';
import '../theme/typography.dart';
import 'common.dart';

/// The two streaks side by side on one card, like a ledger's columns
/// (docs/DESIGN_SYSTEM.md §6.12): the parsha streak, a hairline, and the days
/// on track.
///
/// A streak of 0 is never shown as a stark "0": its column says where the
/// streak begins instead. The whole card is one tap target and one item for
/// screen readers.
class LedgerCard extends StatelessWidget {
  const LedgerCard({
    super.key,
    required this.parshaStreak,
    required this.daysOnTrack,
    required this.beginsWith,
    this.longestParshaStreak,
    this.longestDaysOnTrack,
    this.onTap,
  });

  final int parshaStreak;
  final int daysOnTrack;

  /// The parsha a parsha streak of 0 begins with (the current one), named in
  /// the UI language.
  final String beginsWith;

  /// The longest runs, on Progress. Each shows under its column only when it
  /// is longer than the current run, so it always says something new.
  final int? longestParshaStreak;
  final int? longestDaysOnTrack;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sefer = SeferColors.of(context);
    String? longer(int? longest, int current, String Function(int) format) =>
        longest != null && longest > current ? l.longest(format(longest)) : null;
    final columns = [
      _Entry(
        label: l.streakParsha,
        count: parshaStreak,
        zero: l.streakBeginsWith(beginsWith),
        longest: longer(longestParshaStreak, parshaStreak, l.weeksCount),
      ),
      _Entry(
        label: l.streakDays,
        count: daysOnTrack,
        zero: l.daysBeginToday,
        longest: longer(longestDaysOnTrack, daysOnTrack, l.daysCount),
      ),
    ];
    final theme = Theme.of(context);
    final numeral = SeferType.of(context).ledgerNumeral;
    final meta = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final hasLongest = columns.any((c) => c.longest != null);
    // Each column is padded 16. Laid out as rows across both columns, so the
    // labels line up even when a sentence in place of a count wraps.
    TableRow row(Widget Function(_Entry) cell, {bool first = false, bool last = false}) => TableRow(children: [
          for (final c in columns)
            TableCell(
              // A count and a sentence in its place are centred on each other.
              verticalAlignment: first ? TableCellVerticalAlignment.middle : TableCellVerticalAlignment.top,
              child: Padding(padding: EdgeInsets.fromLTRB(16, first ? 16 : 0, 16, last ? 16 : 0), child: cell(c)),
            ),
        ]);
    return InfoCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Semantics(
        // "Parsha streak: begins with Bereshit. Days on track: 2"
        label: columns.map((c) => c.semanticsLabel).join('. '),
        button: onTap != null,
        excludeSemantics: true,
        child: Table(
          border: TableBorder(verticalInside: BorderSide(color: sefer.hairline, width: sefer.hairlineWidth)),
          children: [
            row(first: true, (c) => c.count == 0
                ? Text(c.zero, style: theme.textTheme.titleMedium)
                : Text('${c.count}', style: numeral)),
            row(last: !hasLongest, (c) => Text(c.label, style: meta)),
            if (hasLongest) row(last: true, (c) => Text(c.longest ?? '', style: meta)),
          ],
        ),
      ),
    );
  }
}

/// One column of the ledger.
class _Entry {
  const _Entry({required this.label, required this.count, required this.zero, this.longest});

  final String label;
  final int count;

  /// What shows in place of a count of 0.
  final String zero;
  final String? longest;

  /// "Days on track: 2". The sentence that replaces a 0 continues the label,
  /// so it starts in lower case ("Parsha streak: begins with Bereshit");
  /// Hebrew has no case, so this leaves it as it is.
  String get semanticsLabel => [
        '$label: ${count == 0 ? zero.replaceRange(0, 1, zero[0].toLowerCase()) : count}',
        ?longest,
      ].join('. ');
}
