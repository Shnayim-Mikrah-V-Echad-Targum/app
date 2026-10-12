import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/calendar/jewish_holidays.dart';
import '../../core/calendar/local_date.dart';
import '../../l10n/app_localizations.dart';
import '../../services/feedback.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/lines.dart';
import '../../ui/widgets/read_date_sheet.dart';
import '../parsha/week_context.dart';
import '../progress/domain/progress_models.dart';
import '../progress/domain/streak_engine.dart';

/// The check-in's question about [previous], whose parsha is [name]: after
/// Shabbat, or after Shabbat and the Yom Tov straight after it, as the
/// reader keeps its days ([oneDayYomTov]), when the reading is logged; for
/// Vezot HaBerachah, after Simchat Torah.
String checkInQuestion(AppLocalizations l, WeekContext previous, String name, {required bool oneDayYomTov}) {
  final occasion = previous.week.occasion;
  if (previous.week.portion.isVezotHaberakhah) return l.checkInTitleVezot(name);
  return JewishHolidays.lastRestDay(occasion, israel: oneDayYomTov) != occasion
      ? l.checkInTitleShabbatYomTov(name)
      : l.checkInTitle(name);
}

/// When a late window closing on [deadline] ends, as of [today], for
/// [AppLocalizations.openWeekLate]: 'today' (by tonight), 'tomorrow' (by
/// tomorrow night), or 'other' (by the end of the day it names).
String lateDeadlineDay(LocalDate deadline, {required LocalDate today}) => deadline == today
    ? 'today'
    : deadline == today.addDays(1)
        ? 'tomorrow'
        : 'other';

/// Where aliyah [aliyah] of [ctx]'s portion is, and how long: "Genesis
/// 2:20–3:21 · 23 verses", each part kept whole on a line of its own where
/// the two don't fit on one ([DotLine]).
Widget aliyahReference(BuildContext context, WeekContext ctx, int aliyah) {
  final names = Names(context);
  final r = ctx.portion.aliyot[aliyah];
  return DotLine(
    [
      names.range(r.book, r.start.chapter, r.start.verse, r.end.chapter, r.end.verse),
      context.l10n.versesCount(ctx.aliyahVerses[aliyah]),
    ],
  );
}

/// Last week's parsha while it still needs attention (docs/DESIGN_SYSTEM.md
/// §9 Today, 2): the after-Shabbat check-in while it is asked
/// ([asksCheckIn]); otherwise, that the week is still open, and how it can
/// still count.
class PreviousWeekNotice extends ConsumerWidget {
  const PreviousWeekNotice({super.key, required this.previous, required this.current, required this.today});

  final WeekContext previous;
  final WeekContext current;
  final LocalDate today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final settings = ref.watch(settingsProvider);
    final name = names.portion(previous.portion, ashkenazi: settings.ashkenaziNames);
    if (asksCheckIn(previous, today: today, settings: settings)) return _checkIn(context, ref, name);

    final engine = ref.watch(streakEngineProvider);
    final overdue = previous.status == WeekStatus.overdue;
    final nextName = names.portion(current.portion, ashkenazi: settings.ashkenaziNames);
    final streak = ref.watch(streakSummaryProvider.select((s) => s.parshaStreak));
    final onlyHaftarah = previous.progress.isComplete;
    final deadline = engine.lateDeadlineOf(previous.week);
    return NoticeBanner(
      icon: Icons.schedule,
      title: l.openWeekTitle(name),
      text: [
        if (onlyHaftarah) l.openWeekHaftarahLeft,
        if (!overdue)
          l.openWeekLate(lateDeadlineDay(deadline, today: today), names.practiceDate(deadline))
        else if (streak > 0)
          l.openWeekRestore(name, nextName, streak)
        else
          l.openWeekRestoreZero(name, nextName),
      ].join(' '),
      actionBelow: true,
      action: TextButton(
        onPressed: () => context.push(onlyHaftarah ? '/today/haftarah/${previous.id}' : '/today/week/${previous.id}'),
        child: Text(onlyHaftarah ? l.readTheHaftarah : l.openWeekOpen(name)),
      ),
    );
  }

  /// Asks what was read on Shabbat (or on Yom Tov): put aside for this
  /// time, chosen aliyah by aliyah in a sheet, or the whole parsha.
  Widget _checkIn(BuildContext context, WidgetRef ref, String name) {
    final l = context.l10n;
    final oneDayYomTov = ref.watch(settingsProvider.select((s) => s.oneDayYomTov));
    final question = checkInQuestion(l, previous, name, oneDayYomTov: oneDayYomTov);
    return NoticeBanner(
      icon: Icons.import_contacts,
      // By name: the title page beneath is another week's parsha.
      title: question,
      text: l.checkInBody,
      actionBelow: true,
      action: Padding(
        padding: NoticeBanner.tonalActionInset,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: Space.sm,
          runSpacing: Space.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () => _answer(ref.read(settingsProvider.notifier)),
              child: Text(l.checkInNotThisTime),
            ),
            TextButton(onPressed: () => _choose(context, ref, name, question), child: Text(l.checkInPick)),
            // Tonal: the hero's is the page's one filled button.
            FilledButton.tonal(
              // Room around a label that large text wraps.
              style: AppButtons.tonal(context).merge(AppButtons.roomy(context, (24, 12, 6))),
              onPressed: () => _log(
                context,
                ref,
                name,
                (progress) {
                  progress.markWeek(previous.id, previous.week.occasion);
                  // Finishing it includes the haftarah, where that counts.
                  if (previous.haftarahDue) progress.markHaftarah(previous.id, previous.week.occasion);
                },
              ),
              // Logged for the day it was read in synagogue, Simchat Torah
              // for Vezot HaBerachah. As wide as its label, as a Text is,
              // and where a long name wraps it, balanced, leaving no word
              // alone ("Tov").
              child: IntrinsicWidth(
                child: BalancedText(
                  previous.week.portion.isVezotHaberakhah ? l.checkInFinishedYomTov(name) : l.checkInFinished(name),
                  style: null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _answer(SettingsController settings) => settings.update((s) => s.copyWith(checkInAnsweredFor: previous.id));

  /// Logs what the check-in sheet, titled with the notice's [question],
  /// says was read, all at once.
  Future<void> _choose(BuildContext context, WidgetRef ref, String name, String question) async {
    final settings = ref.read(settingsProvider);
    final log = await showAppSheet<CheckInLog>(
      context: context,
      isScrollControlled: true,
      builder: (context) => CheckInSheet(
        previous: previous,
        title: question,
        today: today,
        oneDayYomTov: settings.oneDayYomTov,
        offersHaftarah: (settings.haftarahEnabled || previous.haftarahRequired) && previous.progress.haftarah == null,
      ),
    );
    if (log == null || !context.mounted) return;
    _log(
      context,
      ref,
      name,
      (progress) => progress.markAliyot(previous.id, log.aliyot, log.date, haftarah: log.haftarah),
    );
  }

  /// Logs reading with [mark], answers the check-in, and says so, with a way
  /// back to the week and the question as they were.
  void _log(BuildContext context, WidgetRef ref, String name, void Function(ProgressController progress) mark) {
    final l = context.l10n;
    // The message outlives this notice, which logging may finish.
    final container = ProviderScope.containerOf(context, listen: false);
    final before = ref.read(progressProvider).week(previous.id);
    final answeredBefore = ref.read(settingsProvider).checkInAnsweredFor;
    final progress = ref.read(progressProvider.notifier);
    mark(progress);
    _answer(ref.read(settingsProvider.notifier));
    hapticSuccess(ref);
    final after = ref.read(progressProvider).week(previous.id);
    final finished = after.isComplete && (!previous.haftarahRequired || after.haftarah != null);
    showStatus(
      context,
      finished ? l.parshaComplete(name) : l.markedRead,
      action: SnackBarAction(
        label: l.actionUndo,
        onPressed: () {
          container.read(progressProvider.notifier).restoreWeek(previous.id, before);
          container.read(settingsProvider.notifier).update((s) => s.copyWith(checkInAnsweredFor: answeredBefore));
        },
      ),
    );
  }
}

/// What the check-in sheet logs: the aliyot checked, the haftarah if
/// checked, and the day they were read.
typedef CheckInLog = ({List<int> aliyot, bool haftarah, LocalDate date});

/// The after-Shabbat check-in, in one sheet, titled with the question that
/// names [previous]'s parsha ([title]): each aliyah of it not yet read,
/// checked to begin with, and its haftarah if [offersHaftarah]; the day they
/// were read, Shabbat (or Simchat Torah) unless changed; and one button that
/// logs them all. Returns a [CheckInLog].
class CheckInSheet extends StatefulWidget {
  const CheckInSheet({
    super.key,
    required this.previous,
    required this.title,
    required this.today,
    required this.oneDayYomTov,
    required this.offersHaftarah,
  });

  final WeekContext previous;

  /// The check-in's question ([checkInQuestion]), naming [previous]'s
  /// parsha.
  final String title;
  final LocalDate today;

  /// Whether the reader keeps one day of Yom Tov, which decides the days
  /// called Yom Tov.
  final bool oneDayYomTov;
  final bool offersHaftarah;

  @override
  State<CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<CheckInSheet> {
  late final List<int> _aliyot = [
    for (var a = 0; a < kAliyot; a++)
      if (!widget.previous.progress.isAliyahDone(a)) a,
  ];
  late final Set<int> _checked = {..._aliyot};
  late bool _haftarah = widget.offersHaftarah;
  late LocalDate _date = widget.previous.week.occasion;

  Future<void> _changeDate() async {
    final date = await pickReadDate(
      context,
      week: widget.previous.week,
      today: widget.today,
      oneDayYomTov: widget.oneDayYomTov,
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final padding = sheetPadding(context);
    final haftarah = widget.previous.haftarah;
    final occasion = widget.previous.week.occasion;
    // Shabbat, Yom Tov, or another day, by name.
    final readOn = _date == occasion && occasion.isShabbat
        ? l.checkInReadOnShabbat(names.practiceDayMonth(_date))
        : isNamedYomTov(_date, oneDayYomTov: widget.oneDayYomTov)
            ? l.checkInReadOnYomTov(names.practiceDayMonth(_date))
            : l.checkInReadOn(names.practiceDate(_date));
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(widget.title),
            for (final a in _aliyot)
              TileFocusRing(
                child: CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _checked.contains(a),
                  onChanged: (on) => setState(() => on! ? _checked.add(a) : _checked.remove(a)),
                  title: Text(names.aliyah(a)),
                  subtitle: aliyahReference(context, widget.previous, a),
                ),
              ),
            if (widget.offersHaftarah)
              TileFocusRing(
                child: CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _haftarah,
                  onChanged: (on) => setState(() => _haftarah = on!),
                  title: Text(l.haftarahLabel),
                  subtitle: DotLine(
                    [
                      for (final p in haftarah.parts)
                        names.range(p.book, p.start.chapter, p.start.verse, p.end.chapter, p.end.verse),
                    ],
                  ),
                ),
              ),
            Padding(
              // The button's own padding brings it to the column's edge.
              padding: EdgeInsetsDirectional.fromSTEB(padding, Space.sm, padding - Space.md, 0),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Broken, if it must be, after its comma: "Read on
                  // Shabbat, / October 10", never inside the date.
                  DotLine(
                    [readOn],
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  TextButton(onPressed: _changeDate, child: Text(l.changeDate)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(padding, Space.sm, padding, Space.lg),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  style: AppButtons.roomy(context, (24, 12, 6)),
                  onPressed: _checked.isEmpty && !_haftarah
                      ? null
                      : () => Navigator.pop<CheckInLog>(context, (
                            aliyot: _aliyot.where(_checked.contains).toList(),
                            haftarah: _haftarah,
                            date: _date,
                          )),
                  child: Text(l.logReading),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
