import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/calendar/local_date.dart';
import '../../services/feedback.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/lang.dart';
import '../../ui/widgets/lines.dart';
import '../../ui/widgets/ornaments.dart';
import '../community/data/backend.dart';
import '../community/data/community_providers.dart';
import '../parsha/week_context.dart';
import '../progress/domain/progress_models.dart';
import '../progress/domain/reading_plan.dart';
import '../settings/app_settings.dart';
import '../settings/screens/data_settings_screen.dart';
import '../settings/widgets/settings_widgets.dart';

/// The decisions that follow the welcome, each a page of its own under
/// /welcome: Back, the app bar's or the system's, returns a step rather than
/// leaving the app, and each step is announced and focused as a new screen.
/// Every choice is a setting as soon as it is made, so going back loses
/// nothing.
enum OnboardingStep {
  location,
  method,
  plan;

  String get path => '/welcome/$name';

  /// The step's number, counted from 1, as its app bar shows it.
  int get number => index + 1;

  OnboardingStep? get next => index + 1 < values.length ? values[index + 1] : null;
}

/// Whether the reader has chosen where they will be this Shabbat, or gone
/// on past the question. It is kept across launches, as the choice itself
/// is: the time-zone guess, which can arrive late, or come again when the
/// app is opened again before onboarding ends, never overrides it.
final _locationChosenProvider = NotifierProvider<_LocationChosen, bool>(_LocationChosen.new);

class _LocationChosen extends Notifier<bool> {
  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(OnboardingScreen.locationChosenKey) ?? false;

  void choose() {
    if (state) return;
    state = true;
    ref.read(sharedPreferencesProvider).setBool(OnboardingScreen.locationChosenKey, true);
  }
}

void _update(WidgetRef ref, AppSettings Function(AppSettings) f) => ref.read(settingsProvider.notifier).update(f);

/// First run: a welcome, at most three decisions, then straight to reading.
/// No account is needed.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  /// Where it is stored that the reader has chosen their location (see
  /// [_locationChosenProvider]).
  static const locationChosenKey = 'onboarding.locationChosen';

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// Where a reader who already uses the app restores their progress from.
enum _RestoreFrom { account, file, pasted }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  /// Whether progress is being restored from the account's backup.
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _guessLocation();
  }

  /// Pre-selects Israel, both its reading and one day of Yom Tov, for
  /// devices set to Israel time: right for those who live there. "Why we
  /// ask", on the location step, tells a visitor that the days of Yom Tov can
  /// be set apart in Settings. The welcome stays beneath the steps, so the
  /// guess is made once, while the reader is still on it.
  Future<void> _guessLocation() async {
    // After the first frame: the settings never change while it builds.
    await Future<void>.delayed(Duration.zero);
    try {
      // An IANA name on every platform; on the web, the browser's own
      // (Intl.DateTimeFormat().resolvedOptions().timeZone). DateTime's
      // timeZoneName is no use there: it is a localized long name such as
      // "Israel Daylight Time".
      final tz = (await FlutterTimezone.getLocalTimezone()).identifier;
      if (!mounted || ref.read(_locationChosenProvider)) return;
      if (tz == 'Asia/Jerusalem' || tz == 'Asia/Tel_Aviv') _update(ref, (s) => s.locatedIn(ReadingSchedule.israel));
    } catch (_) {
      // Keep the default.
    }
  }

  /// For a reader who already uses the app, on a new device say: restores
  /// their progress, from their account's backup or a backup file, and with
  /// it their streaks, and opens Today.
  Future<void> _restore() async {
    // The demo community keeps nothing from one run to the next, so it has
    // no backup to sign in to.
    final cloud = !ref.read(forumRepositoryProvider).isDemo;
    final from = await showAppSheet<_RestoreFrom>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RestoreSheet(cloud: cloud),
    );
    if (!mounted) return;
    switch (from) {
      case _RestoreFrom.account:
        await _restoreFromAccount();
      case _RestoreFrom.file:
        await _restoreFromBackup(askToImportBackup);
      case _RestoreFrom.pasted:
        await _restoreFromBackup(askToPasteBackup);
      case null:
        break;
    }
  }

  /// Signs in, unless already signed in, then turns backup on and syncs.
  /// With progress restored, or only the day the reader joined (an account
  /// reset everywhere, say, with nothing read since), onboarding is done:
  /// that day comes back with every sync, so starting afresh from today
  /// isn't possible. An account with no backup goes on to the first step,
  /// keeping backup on for what is read from now.
  Future<void> _restoreFromAccount() async {
    final l = context.l10n;
    final repo = ref.read(forumRepositoryProvider);
    if (repo.currentUser == null) {
      await context.push('/welcome/account');
      if (!mounted || repo.currentUser == null) return;
    }
    setState(() => _restoring = true);
    _update(ref, (s) => s.copyWith(cloudSync: true));
    final synced = await ref.read(progressSyncProvider.notifier).syncNow();
    if (!mounted) return;
    setState(() => _restoring = false);
    final progress = ref.read(progressProvider);
    if (!synced) {
      showStatus(context, ref.read(syncBlockedByNewerFormatProvider) ? l.syncNeedsUpdate : l.syncFailed);
    } else if (progress.weeks.isNotEmpty || progress.pauses.isNotEmpty || ref.read(settingsProvider).joinDate != null) {
      showStatus(context, l.onbRestoreDone);
      _finishRestoring();
    } else {
      showStatus(context, l.onbRestoreNone);
      context.push(OnboardingStep.location.path);
    }
  }

  /// Restores a backup, from a file or pasted, as [ask] asks for it.
  Future<void> _restoreFromBackup(Future<BackupImport?> Function(BuildContext, WidgetRef) ask) async {
    final l = context.l10n;
    final result = await ask(context, ref);
    if (result == null || !mounted) return;
    showBackupImportStatus(context, result, restored: l.onbRestoreDone, remindersOff: l.onbRestoreDoneRemindersOff);
    if (result != BackupImport.unreadable) _finishRestoring();
  }

  /// Ends onboarding, keeping the join date that came with the progress, and
  /// so opens Today (see the router's redirect).
  void _finishRestoring() {
    final today = ref.read(todayProvider);
    _update(ref, (s) => s.copyWith(onboardingComplete: true, joinDate: s.joinDate ?? today));
  }

  @override
  Widget build(BuildContext context) {
    final page = Scaffold(
      body: SafeArea(
        child: _Welcome(
          onStart: _restoring ? null : () => context.push(OnboardingStep.location.path),
          onRestore: _restoring ? null : _restore,
          restoring: _restoring,
        ),
      ),
    );
    // Welcome is the app's name alone; each step names itself (PageScaffold).
    return DocumentTitle(title: '', child: page);
  }
}

/// The ways back in for a reader who already uses the app.
class _RestoreSheet extends StatelessWidget {
  const _RestoreSheet({required this.cloud});

  /// Whether there is an account's backup to sign in to.
  final bool cloud;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(l.onbRestoreTitle),
            if (cloud)
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: Text(l.onbRestoreSignIn),
                subtitle: Text(l.onbRestoreSignInDesc),
                onTap: () => Navigator.pop(context, _RestoreFrom.account),
              ),
            ListTile(
              leading: const Icon(Icons.restore_page_outlined),
              title: Text(l.onbRestoreFile),
              subtitle: Text(l.onbRestoreFileDesc),
              onTap: () => Navigator.pop(context, _RestoreFrom.file),
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: Text(l.importPaste),
              subtitle: Text(l.importPasteDesc),
              onTap: () => Navigator.pop(context, _RestoreFrom.pasted),
            ),
          ],
        ),
      ),
    );
  }
}

/// One step of onboarding after the welcome.
class OnboardingStepScreen extends ConsumerWidget {
  const OnboardingStepScreen({super.key, required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final next = step.next;
    return PageScaffold(
      titleText: l.onbStep(step.number, OnboardingStep.values.length),
      body: SafeArea(
        child: PageBody(
          // As on a Settings page of list tiles: the text of the page's
          // questions starts on the gutter, under the title, and their paper
          // stands 16 out from it.
          padding: PageBody.tilePadding(context),
          children: [
            _StepMarks(step: step),
            const Gap(Space.xxl),
            switch (step) {
              OnboardingStep.location => const _LocationStep(),
              OnboardingStep.method => const _MethodStep(),
              OnboardingStep.plan => const _PlanStep(),
            },
          ],
        ),
      ),
      // Docked, so that going on is always in view, however large the text.
      bottomNavigationBar: _StepBar(
        note: l.onbChangeAnytime,
        label: next == null ? l.startReading : l.actionContinue,
        onPressed: next == null ? () => _finish(context, ref) : () => _continue(context, ref, next),
      ),
    );
  }

  /// Goes on to [next]. Going on past the location step keeps what it
  /// shows, guessed or not, as the reader's choice.
  void _continue(BuildContext context, WidgetRef ref, OnboardingStep next) {
    if (step == OnboardingStep.location) ref.read(_locationChosenProvider.notifier).choose();
    context.push(next.path);
  }

  /// Ends onboarding on the reader. Reading the whole parsha this week, it
  /// opens on the first aliyah not yet read: Rishon, for a new reader.
  /// Starting with today's reading, it opens on that.
  void _finish(BuildContext context, WidgetRef ref) {
    final today = ref.read(todayProvider);
    _update(ref, (s) => s.copyWith(onboardingComplete: true, joinDate: s.joinDate ?? today));
    final ctx = ref.read(currentWeekContextProvider);
    final first = ref.read(settingsProvider).starterCatchUp
        ? ctx.nextAliyah ?? 0
        : _firstFrom(ctx.plan, ctx.today) ?? ctx.nextAliyah ?? 0;
    context.go('/today');
    context.push('/read/${ctx.id}/$first');
  }

  /// The first aliyah planned for [day], or else for the next day with
  /// reading.
  static int? _firstFrom(WeekPlan plan, LocalDate day) {
    for (final d in plan.days) {
      if (d.date >= day && d.aliyot.isNotEmpty) return d.aliyot.first;
    }
    return null;
  }
}

/// Where a step stands among the pages of onboarding, the welcome and the
/// three steps: a 12 px lozenge for each, filled up to this one and
/// outlined after it. The app bar's title says the same in words ("Step 1 of
/// 3"), so screen readers hear that alone.
class _StepMarks extends StatelessWidget {
  const _StepMarks({required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // In the colour of indicators, or onSurface in high contrast, as every
    // ornament there (§7).
    final ink = SeferColors.of(context).isHighContrast ? scheme.onSurface : scheme.primary;
    // The welcome is the first page.
    final pages = OnboardingStep.values.length + 1;
    final current = step.number + 1;
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var page = 1; page <= pages; page++) ...[
            if (page > 1) const Gap(Space.md),
            Lozenge(size: Lozenge.large, color: ink, outlined: page > current),
          ],
        ],
      ),
    );
  }
}

/// A step's way on, docked below its page on surface, under a hairline: a
/// reminder that every choice can be changed later, and the Filled button,
/// 52 high and at most 480 wide.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.note, required this.label, required this.onPressed});

  final String note;
  final String label;
  final VoidCallback onPressed;

  static const _maxWidth = 480.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sefer = SeferColors.of(context);
    final g = Gutter.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: sefer.hairline, width: sefer.hairlineWidth)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          // On the gutters, as the page's paper is.
          padding: EdgeInsets.fromLTRB(g, Space.md, g, Space.lg),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    note,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const Gap(Space.sm),
                  FilledButton(
                    style: AppButtons.roomy(context, (24, 12, 6))
                        .copyWith(minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52))),
                    onPressed: onPressed,
                    child: Text(label, textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationStep extends ConsumerStatefulWidget {
  const _LocationStep();

  @override
  ConsumerState<_LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends ConsumerState<_LocationStep> {
  bool _whyOpen = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final motion = Motion.of(context);
    final schedule = ref.watch(settingsProvider.select((s) => s.readingSchedule));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceGroup<ReadingSchedule>(
          // On a page of list tiles: in to the gutters, as they are.
          margin: const EdgeInsets.symmetric(horizontal: 16),
          prominent: true,
          title: l.onbLocationTitle,
          value: schedule,
          choices: [
            Choice(ReadingSchedule.diaspora, l.locationDiaspora),
            Choice(ReadingSchedule.israel, l.locationIsrael),
          ],
          // Both the reading and the days of Yom Tov; a visitor can set them
          // apart in Settings.
          onChanged: (v) {
            ref.read(_locationChosenProvider.notifier).choose();
            _update(ref, (s) => s.locatedIn(v));
          },
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            // The label lines up with the question and the options above.
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: MergeSemantics(
              child: Semantics(
                expanded: _whyOpen,
                child: TextButton.icon(
                  onPressed: () => setState(() => _whyOpen = !_whyOpen),
                  iconAlignment: IconAlignment.end,
                  icon: AnimatedRotation(
                    turns: _whyOpen ? 0.5 : 0,
                    duration: motion.d(Motion.short),
                    child: const Icon(Icons.expand_more),
                  ),
                  label: Text(l.onbWhyAsk),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: motion.d(Motion.medium),
          curve: Motion.standard,
          alignment: AlignmentDirectional.topStart,
          child: _whyOpen
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    l.locationHelp,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _MethodStep extends ConsumerWidget {
  const _MethodStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    // Each method's description names the reading chosen below.
    final second = Names(context).secondReading(s.secondReading);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceGroup<ReadingMethod>(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          prominent: true,
          title: l.onbMethodTitle,
          value: s.method,
          choices: [
            Choice(ReadingMethod.verseByVerse, l.methodVerse, subtitle: l.methodVerseDesc(second)),
            Choice(ReadingMethod.sectionBySection, l.methodSection, subtitle: l.methodSectionDesc(second)),
          ],
          onChanged: (v) => _update(ref, (s) => s.copyWith(method: v)),
        ),
        ChoiceGroup<SecondReading>(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          title: l.secondLabel,
          help: l.secondHelp,
          value: s.secondReading,
          choices: [
            Choice(SecondReading.onkelos, l.secondOnkelos),
            Choice(SecondReading.rashi, l.secondRashi),
            Choice(SecondReading.onkelosAndRashi, l.secondBoth),
          ],
          onChanged: (v) => _update(ref, (s) => s.copyWith(secondReading: v)),
        ),
      ],
    );
  }
}

/// What reading the whole parsha in the week of joining asks of a reader
/// who starts on [start]: its verses, about how many minutes they take, the
/// days with reading, and when they are a single day, that day. Null when
/// that week is planned the same either way: they start on its first day
/// of reading, or after its last.
({int verses, int minutes, int days, LocalDate? only})? _catchUp(WidgetRef ref, LocalDate start) {
  final ctx = ref.watch(currentWeekContextProvider);
  final planner = ref.watch(plannerProvider);
  final usual = planner.startingFrom(null).planFor(ctx.week);
  if (usual.days.isEmpty || start <= usual.days.first.date) return null;
  final catchUp = planner.startingFrom(start).planFor(ctx.week);
  // With no day of reading left, the planner keeps the usual days.
  if (catchUp.days.isEmpty || catchUp.days.first.date < start) return null;
  // Shevi'i on Shabbat morning is a day of reading too.
  final days = catchUp.days.length + (catchUp.shabbatAliyot.isEmpty ? 0 : 1);
  return (
    verses: ctx.aliyahVerses.fold(0, (n, v) => n + v),
    minutes: ctx.remainingMinutes([for (var a = 0; a < kAliyot; a++) a]),
    days: days,
    // Not necessarily the day they start: joining on Tisha B'Av, a quiet
    // day, leaves only Friday.
    only: days == 1 ? catchUp.days.single.date : null,
  );
}

class _PlanStep extends ConsumerWidget {
  const _PlanStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    // The reader starts today, as onboarding ends (see _finish).
    final LocalDate start = s.joinDate ?? ref.watch(todayProvider);
    final catchUp = _catchUp(ref, start);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceGroup<ReadingPlanType>(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          prominent: true,
          title: l.onbPlanTitle,
          value: s.plan,
          choices: [
            Choice(ReadingPlanType.aliyahPerDay, l.planAliyahPerDay, subtitle: l.planAliyahPerDayDesc),
            Choice(ReadingPlanType.sheviiOnShabbat, l.planShevii, subtitle: l.planSheviiDesc),
            Choice(ReadingPlanType.erevShabbat, l.planErevShabbat, subtitle: l.planErevShabbatDesc),
          ],
          onChanged: (v) => _update(ref, (s) => s.copyWith(plan: v)),
        ),
        // Joining after the week's first day of reading: the whole parsha
        // over the days left, or only what the usual plan has from today on.
        if (catchUp != null)
          ChoiceGroup<bool>(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            title: l.onbStarterTitle,
            value: s.starterCatchUp,
            choices: [
              Choice(
                true,
                l.onbStarterCatchUp,
                subtitle: switch (catchUp.only) {
                  final day? when day != start =>
                    l.onbStarterCatchUpOn(catchUp.verses, catchUp.minutes, Names(context).weekday(day)),
                  _ => l.onbStarterCatchUpDesc(catchUp.verses, catchUp.minutes, catchUp.days),
                },
              ),
              Choice(false, l.onbStarterToday, subtitle: l.onbStarterTodayDesc),
            ],
            onChanged: (v) => _update(ref, (s) => s.copyWith(starterCatchUp: v)),
          ),
        Padding(
          // A section's gap below the choices.
          padding: const EdgeInsets.fromLTRB(16, Rhythm.sectionGap, 16, 0),
          child: NoticeBanner(icon: Icons.handshake_outlined, text: l.onbHonor, marginalia: true),
        ),
      ],
    );
  }
}

/// The welcome, a title page (§9 Onboarding): the language at the top end,
/// and in the middle of the page the app's name in a title-page frame, the
/// way into this week's parsha and the way back in for a reader who already
/// uses the app.
class _Welcome extends StatelessWidget {
  const _Welcome({required this.onStart, required this.onRestore, required this.restoring});
  final VoidCallback? onStart;

  /// For a reader who already uses the app (see [_RestoreSheet]).
  final VoidCallback? onRestore;

  /// Whether progress is being restored from the account's backup.
  final bool restoring;

  /// The width of the title block and what follows it, and of its buttons.
  static const _maxWidth = 520.0;
  static const _buttonMaxWidth = 400.0;

  /// Below the block, about as much as the language takes above it, less
  /// the page's greater padding below: so the block sits in the middle of
  /// the whole height, where there is room.
  static const _languageBalance = Space.s40;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Centred, like the text above them, also when large text wraps them.
    Widget button(Widget child) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _buttonMaxWidth),
            child: SizedBox(width: double.infinity, child: child),
          ),
        );
    final block = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TitleBlock(),
        const Gap(Space.xxl),
        button(
          FilledButton(
            // The page's one call to action, 52 high, with room around a label
            // that large text wraps.
            style: AppButtons.roomy(context, (24, 12, 6))
                .copyWith(minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52))),
            onPressed: onStart,
            child: Text(l.onbStart, textAlign: TextAlign.center),
          ),
        ),
        const Gap(Space.sm),
        if (restoring)
          // In the button's place, as tall, until the backup is in.
          Semantics(
            liveRegion: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  const Gap(Space.md),
                  Flexible(
                    child: Text(
                      l.onbRestoring,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          button(
            TextButton(
              style: AppButtons.roomy(context, (12, 8, 4), vertical: 8),
              onPressed: onRestore,
              child: Text(l.onbRestore, textAlign: TextAlign.center),
            ),
          ),
        const Gap(Space.lg),
        BalancedText(l.disclaimer, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
    return LayoutBuilder(builder: (context, constraints) {
      final side = math.max(Gutter.of(context), (constraints.maxWidth - _maxWidth) / 2);
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(side, Space.lg, side, Space.xxl),
            child: Column(
              // The language at the top, the block in the middle.
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(alignment: AlignmentDirectional.centerEnd, child: _LanguageChoice()),
                Padding(padding: const EdgeInsets.symmetric(vertical: Space.xxl), child: block),
                const SizedBox(height: _languageBalance),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// English or עברית: the language the app is shown in, which is the device's
/// own until one is chosen here or in Settings. The language shown is always
/// the one chosen, the device's too.
class _LanguageChoice extends ConsumerWidget {
  const _LanguageChoice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final shown = Localizations.localeOf(context).languageCode == 'he' ? AppLanguage.hebrew : AppLanguage.english;
    return SegmentedButton<AppLanguage>(
      segments: [
        // Each read in its own language's voice.
        ButtonSegment(value: AppLanguage.english, label: Lang(const Locale('en'), child: Text(l.languageEnglish))),
        ButtonSegment(value: AppLanguage.hebrew, label: Lang(const Locale('he'), child: Text(l.languageHebrew))),
      ],
      selected: {shown},
      // Choosing the language already shown changes nothing: an app that
      // follows the device goes on following it.
      emptySelectionAllowed: false,
      onSelectionChanged: (v) => _update(ref, (s) => s.copyWith(language: v.single)),
    );
  }
}

/// The welcome's title page: a lozenge; the name of the practice in pointed
/// Hebrew, the page's heading; a divider; the name again in English, in the
/// English UI; and what the practice is.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock();

  static const _title = 'שְׁנַיִם מִקְרָא\nוְאֶחָד תַּרְגּוּם';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sefer = SeferColors.of(context);
    final hebrewUi = Localizations.localeOf(context).languageCode == 'he';
    final narrow = MediaQuery.sizeOf(context).width < Breakpoints.narrow;
    // EB Garamond's Medium Italic: upright in high contrast, as marginalia
    // is, and in an accessibility font, which has no italic.
    final latin = theme.textTheme.headlineSmall!;
    final italic = latin.fontFamily == 'EBGaramond' && !sefer.isHighContrast;
    return TitlePageFrame(
      padding: EdgeInsets.all(narrow ? Space.xxl : Space.s32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: Lozenge()),
          const Gap(Space.md),
          Semantics(
            header: true,
            headingLevel: 1,
            label: l.appTitleFull,
            excludeSemantics: true,
            child: WholeWords(
              _title,
              style: SeferType.of(context).hebrewDisplay.copyWith(fontSize: 40, height: 60 / 40),
              textDirection: TextDirection.rtl,
              locale: const Locale('he'),
            ),
          ),
          const Gap(Space.md),
          const SeferDivider(),
          // The Hebrew UI's heading is its own name already.
          if (!hebrewUi) ...[
            const Gap(Space.md),
            ExcludeSemantics(
              child: BalancedText(
                l.appTitleFull,
                style: latin.copyWith(
                  color: scheme.onSurface,
                  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ],
          const Gap(Space.lg),
          BalancedText(
            l.onbWelcomeBody,
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
