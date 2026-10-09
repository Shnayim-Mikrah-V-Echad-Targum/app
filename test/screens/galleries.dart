// Pages of shared widgets for the screenshot harness (capture_test.dart), so
// the design-system pieces can be reviewed in every mode before the screens
// that use them are rebuilt. Not part of the app.
import 'package:flutter/material.dart';
import 'package:shnayim_mikra/ui/l10n.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/ledger.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';

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
