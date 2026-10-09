import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../ui/l10n.dart';
import '../../ui/widgets/common.dart';
import '../parsha/week_context.dart';
import '../progress/domain/reading_plan.dart';
import '../settings/app_settings.dart';
import '../settings/widgets/settings_widgets.dart';

/// First run: at most three decisions, then straight to reading.
/// No account is needed.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _page = 0;
  static const _pages = 4;

  @override
  void initState() {
    super.initState();
    _guessLocation();
  }

  /// Pre-selects Israel, both its reading and one day of Yom Tov, for
  /// devices set to Israel time: right for those who live there. The help
  /// on the same page tells a visitor that the days of Yom Tov can be set
  /// apart in Settings.
  Future<void> _guessLocation() async {
    try {
      final tz = kIsWeb ? DateTime.now().timeZoneName : (await FlutterTimezone.getLocalTimezone()).identifier;
      final israel = tz == 'Asia/Jerusalem' || tz == 'Asia/Tel_Aviv' || tz == 'IST' || tz == 'IDT';
      if (israel && mounted) _update((s) => s.locatedIn(ReadingSchedule.israel));
    } catch (_) {
      // Keep the default.
    }
  }

  void _update(AppSettings Function(AppSettings) f) => ref.read(settingsProvider.notifier).update(f);

  void _finish() {
    final today = ref.read(todayProvider);
    _update((s) => s.copyWith(onboardingComplete: true, joinDate: s.joinDate ?? today));
    final ctx = ref.read(currentWeekContextProvider);
    final first = ctx.plan.dayFor(ctx.today)?.aliyot.first ?? ctx.nextAliyah ?? 0;
    context.go('/today');
    context.push('/read/${ctx.id}/$first');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    final Widget body = switch (_page) {
      0 => _Welcome(onStart: () => setState(() => _page = 1)),
      1 => ChoiceGroup<ReadingSchedule>(
          title: l.onbLocationTitle,
          help: l.locationHelp,
          value: s.readingSchedule,
          choices: [
            Choice(ReadingSchedule.diaspora, l.locationDiaspora),
            Choice(ReadingSchedule.israel, l.locationIsrael),
          ],
          // Both the reading and the days of Yom Tov; a visitor can set them
          // apart in Settings.
          onChanged: (v) => _update((s) => s.locatedIn(v)),
        ),
      2 => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChoiceGroup<ReadingMethod>(
              title: l.onbMethodTitle,
              value: s.method,
              choices: [
                Choice(ReadingMethod.verseByVerse, l.methodVerse, subtitle: l.methodVerseDesc),
                Choice(ReadingMethod.sectionBySection, l.methodSection, subtitle: l.methodSectionDesc),
              ],
              onChanged: (v) => _update((s) => s.copyWith(method: v)),
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
              onChanged: (v) => _update((s) => s.copyWith(secondReading: v)),
            ),
          ],
        ),
      _ => Column(
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
              onChanged: (v) => _update((s) => s.copyWith(plan: v)),
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
        ),
    };

    return Scaffold(
      appBar: _page == 0
          ? null
          : AppBar(
              leading: BackButton(onPressed: () => setState(() => _page--)),
              title: Text(l.onbStep(_page, _pages - 1)),
            ),
      body: SafeArea(
        child: PageBody(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            body,
            if (_page > 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l.onbChangeAnytime, style: theme.textTheme.bodySmall),
              ),
              const Gap(16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FilledButton(
                  onPressed: _page < _pages - 1 ? () => setState(() => _page++) : _finish,
                  child: Text(_page < _pages - 1 ? l.actionContinue : l.startReading),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Welcome extends ConsumerWidget {
  const _Welcome({required this.onStart});
  final VoidCallback onStart;

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
          FilledButton(onPressed: onStart, child: Text(l.onbStart)),
          const Gap(16),
          Text(l.disclaimer, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
