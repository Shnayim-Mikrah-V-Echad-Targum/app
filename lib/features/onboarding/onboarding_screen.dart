import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/calendar/local_date.dart';
import '../../services/feedback.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/motion.dart';
import '../../ui/widgets/common.dart';
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
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _Welcome(
              onStart: _restoring ? null : () => context.push(OnboardingStep.location.path),
              onRestore: _restoring ? null : _restore,
              restoring: _restoring,
            ),
          ],
        ),
      ),
    );
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
    final theme = Theme.of(context);
    final next = step.next;
    return Scaffold(
      appBar: AppBar(title: Text(l.onbStep(step.number, OnboardingStep.values.length))),
      body: SafeArea(
        child: PageBody(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            switch (step) {
              OnboardingStep.location => const _LocationStep(),
              OnboardingStep.method => const _MethodStep(),
              OnboardingStep.plan => const _PlanStep(),
            },
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l.onbChangeAnytime, style: theme.textTheme.bodySmall),
            ),
            const Gap(16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                onPressed: next == null ? () => _finish(context, ref) : () => _continue(context, ref, next),
                child: Text(next == null ? l.startReading : l.actionContinue),
              ),
            ),
          ],
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceGroup<ReadingMethod>(
          title: l.onbMethodTitle,
          value: s.method,
          choices: [
            Choice(ReadingMethod.verseByVerse, l.methodVerse, subtitle: l.methodVerseDesc),
            Choice(ReadingMethod.sectionBySection, l.methodSection, subtitle: l.methodSectionDesc),
          ],
          onChanged: (v) => _update(ref, (s) => s.copyWith(method: v)),
        ),
        ChoiceGroup<SecondReading>(
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
    final theme = Theme.of(context);
    final s = ref.watch(settingsProvider);
    // The reader starts today, as onboarding ends (see _finish).
    final LocalDate start = s.joinDate ?? ref.watch(todayProvider);
    final catchUp = _catchUp(ref, start);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceGroup<ReadingPlanType>(
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
          padding: const EdgeInsets.all(16),
          child: InfoCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.handshake_outlined, color: theme.colorScheme.primary),
                const Gap(12),
                Expanded(child: Text(l.onbHonor)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Welcome extends ConsumerWidget {
  const _Welcome({required this.onStart, required this.onRestore, required this.restoring});
  final VoidCallback? onStart;

  /// For a reader who already uses the app (see [_RestoreSheet]).
  final VoidCallback? onRestore;

  /// Whether progress is being restored from the account's backup.
  final bool restoring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final language = ref.watch(settingsProvider.select((s) => s.language));
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: SegmentedButton<AppLanguage>(
              segments: [
                ButtonSegment(value: AppLanguage.english, label: Text(l.languageEnglish)),
                ButtonSegment(value: AppLanguage.hebrew, label: Text(l.languageHebrew)),
              ],
              emptySelectionAllowed: true,
              selected: {if (language != AppLanguage.system) language},
              onSelectionChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .update((s) => s.copyWith(language: v.isEmpty ? AppLanguage.system : v.first)),
            ),
          ),
          const Gap(48),
          ExcludeSemantics(
            child: Text(
              'שְׁנַיִם מִקְרָא\nוְאֶחָד תַּרְגּוּם',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'NotoSerifHebrew',
                fontSize: 40,
                height: 1.6,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const Gap(24),
          Semantics(
            header: true,
            headingLevel: 1,
            child: Text(l.appTitleFull, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          ),
          const Gap(12),
          Text(l.onbWelcomeBody, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
          const Gap(48),
          // Centred like the text around them, also when large text wraps them.
          FilledButton(onPressed: onStart, child: Text(l.onbStart, textAlign: TextAlign.center)),
          const Gap(8),
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
                    const Gap(12),
                    Flexible(
                      child: Text(
                        l.onbRestoring,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            TextButton(onPressed: onRestore, child: Text(l.onbRestore, textAlign: TextAlign.center)),
          const Gap(16),
          Text(l.disclaimer, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
