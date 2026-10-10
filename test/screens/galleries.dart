// Pages of shared widgets for the screenshot harness (capture_test.dart), so
// the design-system pieces can be reviewed in every mode before the screens
// that use them are rebuilt. Not part of the app.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/parsha/week_context.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/streak_engine.dart';
import 'package:shnayim_mikra/ui/l10n.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/ledger.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';
import 'package:shnayim_mikra/ui/widgets/year_bar.dart';

/// The ornaments of docs/DESIGN_SYSTEM.md §7, the candles and an empty state.
class OrnamentsGallery extends StatelessWidget {
  const OrnamentsGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final he = context.isHebrewUi;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    const done = PipState.done;
    const pending = PipState.pending;
    return Scaffold(
      appBar: AppBar(title: const Text('Ornaments')),
      body: PageBody(
        children: [
          TitlePageFrame(
            child: Column(
              children: [
                Eyebrow(he ? 'פרשת השבוע' : 'Parshat HaShavua'),
                const Gap(8),
                Text(
                  'בְּרֵאשִׁית',
                  style: SeferType.of(context).hebrewDisplay.copyWith(fontSize: 46, height: 60 / 46),
                ),
                if (!he) Text('Bereshit', style: theme.textTheme.headlineLarge),
                const Gap(4),
                Text(
                  he ? 'בראשית א, א–ו, ח · נקראת בשבת' : 'Genesis 1:1–6:8 · Read Shabbat, 10 October',
                  style: muted,
                  textAlign: TextAlign.center,
                ),
                const Gap(16),
                const SeferDivider(),
                const Gap(16),
                FilledButton(onPressed: () {}, child: Text(he ? 'המשך · רביעי' : 'Continue · Revi’i')),
              ],
            ),
          ),
          const Gap(12),
          TitlePageFrame(
            drawProgress: 0.6,
            child: Center(child: Text('drawProgress 0.6', style: muted)),
          ),
          const Gap(12),
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionBreakMark(SectionBreak.petuchah, verseSize: 26),
                const Gap(12),
                const SectionBreakMark(SectionBreak.setumah, verseSize: 26),
                const Gap(12),
                // At four times the reading size, where any misalignment shows.
                const SectionBreakMark(SectionBreak.petuchah, verseSize: 104),
                const Gap(16),
                const SeferDivider(progress: 0.5),
                const Gap(20),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    PassPips(states: [done, done, pending], current: 2),
                    PassPips(states: [done, pending, pending]),
                    PassPips(states: [done, done, done]),
                    PassPips(states: [done, pending, pending], size: PassPips.mini),
                  ],
                ),
                const Gap(20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const Lozenge(),
                    const Lozenge(size: Lozenge.large),
                    const Lozenge(size: Lozenge.large, outlined: true),
                    const ShabbatCandlesIcon(),
                    const ShabbatCandlesIcon(size: 40),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: SeferColors.of(context).restWash,
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                      ),
                      child: const ShabbatCandlesIcon(size: 22),
                    ),
                  ],
                ),
              ],
            ),
          ),
          EmptyState(message: context.l10n.noThreads, actionLabel: context.l10n.newThread, onAction: () {}),
        ],
      ),
    );
  }
}

/// The ledger card and paper groups.
class RowsGallery extends StatelessWidget {
  const RowsGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final he = context.isHebrewUi;
    return Scaffold(
      appBar: AppBar(title: const Text('Rows')),
      body: PageBody(
        children: [
          LedgerCard(parshaStreak: 0, daysOnTrack: 2, beginsWith: he ? 'בראשית' : 'Bereshit', onTap: () {}),
          const Gap(12),
          LedgerCard(
            parshaStreak: 3,
            daysOnTrack: 0,
            beginsWith: he ? 'נח' : 'Noach',
            longestParshaStreak: 5,
            longestDaysOnTrack: 9,
          ),
          GroupHeader(l.settingsTitle),
          PaperGroup(
            children: [
              PaperRow(
                icon: Icons.menu_book_outlined,
                title: l.settingsReading,
                subtitle: l.settingsReadingDesc,
                onTap: () {},
              ),
              PaperRow(icon: Icons.notifications_outlined, title: l.settingsReminders, onTap: () {}),
              PaperRow(
                icon: Icons.translate_outlined,
                title: l.settingsLanguage,
                value: l.languageSystem,
                onTap: () {},
              ),
              PaperRow(
                icon: Icons.visibility_outlined,
                title: l.showStreaks,
                trailing: Switch(value: true, onChanged: (_) {}),
                mergeTrailing: true,
              ),
            ],
          ),
          GroupHeader(l.aboutTitle),
          PaperGroup(
            children: [
              PaperRow(title: l.guideTitle, onTap: () {}),
              PaperRow(title: l.settingsData, subtitle: l.settingsDataDesc, onTap: () {}),
            ],
          ),
        ],
      ),
    );
  }
}

/// The parsha rings with their legend, compact rings, and the year bar.
class ProgressGallery extends StatelessWidget {
  const ProgressGallery({super.key});

  /// Bereshit's aliyot, in verses.
  static const _weights = [34, 31, 26, 25, 22, 22, 6];

  /// [aliyot] read in full, then [passes] readings of the next.
  static WeekProgress _week(int aliyot, {int passes = 0}) {
    final day = LocalDate(2026, 10, 5);
    var w = WeekProgress(weekId: 'gallery:$aliyot:$passes');
    for (var a = 0; a < aliyot; a++) {
      w = w.withAliyah(a, day);
    }
    for (var p = 0; p < passes; p++) {
      w = w.withUnit(aliyot, ReadingPass.values[p], day);
    }
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final he = context.isHebrewUi;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    const s = YearSegment.values;
    final year = [
      ...List.filled(5, s[0]),
      s[1],
      s[0],
      s[2],
      s[4],
      s[0],
      s[3],
      ...List.filled(43, s[4]),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: PageBody(
        children: [
          InfoCard(child: RingsWithLegend(progress: _week(2, passes: 2), aliyahWeights: _weights)),
          const Gap(12),
          InfoCard(
            child: RingsWithLegend(
              progress: _week(5, passes: 1),
              aliyahWeights: _weights,
              size: ParshaRings.header,
              thirdLabel: l.passRashi,
            ),
          ),
          const Gap(12),
          // The narrowest card on a 360 dp phone: the legend goes under.
          Center(
            child: SizedBox(
              width: 280,
              child: InfoCard(child: RingsWithLegend(progress: _week(0, passes: 1), aliyahWeights: _weights)),
            ),
          ),
          const Gap(12),
          InfoCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final w in [_week(0), _week(1, passes: 2), _week(4), _week(7)])
                  ParshaRings(progress: w, aliyahWeights: _weights, size: ParshaRings.compact),
              ],
            ),
          ),
          const Gap(12),
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                YearBar(segments: year, currentName: he ? 'שמות' : 'Shemot'),
                const Gap(16),
                Text('280 dp', style: muted),
                const Gap(4),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SizedBox(width: 280, child: YearBar(segments: year)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The week strip in every day state, and on a 320 dp phone, where it takes
/// two rows. The plan is the harness's week of Bereshit: Sunday is Simchat
/// Torah in the Diaspora, and Monday to Friday have reading.
class WeekGallery extends ConsumerWidget {
  const WeekGallery({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(currentWeekContextProvider).plan;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final mon = LocalDate(2026, 10, 5);
    Widget strip(LocalDate today, List<DayStatus> statuses, {LocalDate? joinDate}) => WeekStrip(
          plan: plan,
          today: today,
          statuses: {for (var i = 0; i < statuses.length; i++) mon.addDays(i): statuses[i]},
          israel: false,
          joinDate: joinDate,
          onDayTap: (_) {},
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Week strip'), actions: const [WeekStripLegendButton()]),
      body: PageBody(
        children: [
          // Yom Tov, kept, ahead, caught up, grace, today, Shabbat.
          InfoCard(
            padding: WeekStrip.cardPadding,
            child: strip(mon.addDays(4), [DayStatus.kept, DayStatus.ahead, DayStatus.caughtUp, DayStatus.grace]),
          ),
          const Gap(12),
          // Before joining, missed, paused, not yet read, and today kept.
          InfoCard(
            padding: WeekStrip.cardPadding,
            child: strip(
              mon.addDays(4),
              [DayStatus.missed, DayStatus.missed, DayStatus.paused, DayStatus.open, DayStatus.kept],
              joinDate: mon.addDays(1),
            ),
          ),
          const Gap(12),
          Text('320 dp', style: muted),
          const Gap(4),
          // A 320 dp phone's card: today on Tuesday, the rest to come.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: 288,
              child: InfoCard(padding: WeekStrip.cardPadding, child: strip(mon.addDays(1), [DayStatus.kept])),
            ),
          ),
        ],
      ),
    );
  }
}
