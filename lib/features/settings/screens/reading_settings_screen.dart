import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/models/parsha.dart';
import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/paper_group.dart';
import '../../progress/domain/reading_plan.dart';
import '../app_settings.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/shabbat_times_setting.dart';

class ReadingSettingsScreen extends ConsumerWidget {
  const ReadingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    // Each method's description names the reading after the Torah's two.
    final second = Names(context).secondReading(s.secondReading);
    void update(AppSettings Function(AppSettings) f) {
      final before = ref.read(settingsProvider).planSettings;
      ref.read(settingsProvider.notifier).update(f);
      // Weeks already planned and judged keep the settings they had.
      if (!ref.read(settingsProvider).planSettings.sameSettingsAs(before)) showStatus(context, l.appliesFromThisWeek);
    }

    // A section of the page: its eyebrow, then its settings, 24 apart.
    List<Widget> section(String title, List<Widget> settings) => [
          GroupHeader(title),
          for (final (i, setting) in settings.indexed) ...[if (i > 0) const Gap(Space.xxl), setting],
        ];

    return SettingsPage(
      title: l.settingsReading,
      paper: true,
      children: [
        ...section(l.readingGroupWhere, [
          ChoiceGroup<ReadingSchedule>(
            title: l.readingScheduleLabel,
            help: l.readingScheduleHelp,
            headingLevel: 3,
            segmented: true,
            value: s.readingSchedule,
            choices: [
              Choice(ReadingSchedule.israel, l.locationIsrael),
              Choice(ReadingSchedule.diaspora, l.locationDiaspora),
            ],
            onChanged: (v) => update((s) => s.copyWith(readingSchedule: v)),
          ),
          ChoiceGroup<bool>(
            title: l.yomTovDaysLabel,
            help: l.yomTovDaysHelp,
            headingLevel: 3,
            segmented: true,
            value: s.oneDayYomTov,
            choices: [
              Choice(true, _glossed(l.yomTovDaysOne), semanticsLabel: l.yomTovDaysOne),
              Choice(false, _glossed(l.yomTovDaysTwo), semanticsLabel: l.yomTovDaysTwo),
            ],
            onChanged: (v) => update((s) => s.copyWith(oneDayYomTov: v)),
          ),
          const ShabbatTimesSetting(),
          ChoiceGroup<ReadingPlanType>(
            title: l.planLabel,
            headingLevel: 3,
            value: s.plan,
            choices: [
              Choice(ReadingPlanType.aliyahPerDay, l.planAliyahPerDay, subtitle: l.planAliyahPerDayDesc),
              Choice(ReadingPlanType.sheviiOnShabbat, l.planShevii, subtitle: l.planSheviiDesc),
              Choice(ReadingPlanType.erevShabbat, l.planErevShabbat, subtitle: l.planErevShabbatDesc),
            ],
            onChanged: (v) => update((s) => s.copyWith(plan: v)),
          ),
          ChoiceGroup<LateWindow>(
            title: l.lateWindowLabel,
            help: l.lateWindowDesc,
            helpIsSource: true,
            headingLevel: 3,
            value: s.lateWindow,
            choices: [
              Choice(LateWindow.tuesday, l.lateTuesday),
              Choice(LateWindow.wednesday, l.lateWednesday),
              Choice(LateWindow.none, l.lateNone),
            ],
            onChanged: (v) => update((s) => s.copyWith(lateWindow: v)),
          ),
        ]),
        ...section(l.readingGroupHow, [
          ChoiceGroup<ReadingMethod>(
            title: l.methodLabel,
            headingLevel: 3,
            value: s.method,
            choices: [
              Choice(ReadingMethod.verseByVerse, l.methodVerse, subtitle: l.methodVerseDesc(second)),
              Choice(ReadingMethod.sectionBySection, l.methodSection, subtitle: l.methodSectionDesc(second)),
              Choice(ReadingMethod.aliyahByAliyah, l.methodAliyah, subtitle: l.methodAliyahDesc(second)),
            ],
            onChanged: (v) => update((s) => s.copyWith(method: v)),
          ),
          ChoiceGroup<SecondReading>(
            title: l.secondLabel,
            help: l.secondHelp,
            helpIsSource: true,
            headingLevel: 3,
            value: s.secondReading,
            choices: [
              Choice(SecondReading.onkelos, l.secondOnkelos),
              Choice(SecondReading.rashi, l.secondRashi),
              Choice(SecondReading.onkelosAndRashi, l.secondBoth),
              Choice(SecondReading.rashiEnglish, l.secondRashiEnglish),
            ],
            onChanged: (v) => update((s) => s.copyWith(secondReading: v)),
          ),
          PaperGroup(
            children: [
              SwitchRow(
                title: l.repeatLastVerse,
                subtitle: s.nusach == HaftarahNusach.chabad ? l.repeatLastVerseDescChabad : l.repeatLastVerseDesc,
                value: s.repeatLastVerse,
                onChanged: (v) => update((s) => s.withRepeatLastVerse(v)),
              ),
              SwitchRow(
                title: l.thirdReading,
                subtitle: l.thirdReadingDesc,
                value: s.thirdReadingPrompts,
                onChanged: (v) => update((s) => s.copyWith(thirdReadingPrompts: v)),
              ),
            ],
          ),
        ]),
        GroupHeader(l.haftarahTitle),
        // The section names it, so the row says what the switch does.
        PaperGroup(
          children: [
            SwitchRow(
              title: l.haftarahEnabledDesc,
              value: s.haftarahEnabled,
              onChanged: (v) => update((s) => s.copyWith(haftarahEnabled: v)),
            ),
          ],
        ),
        if (s.haftarahEnabled) ...[
          const Gap(Rhythm.cardGap),
          // Settings of the haftarah read, set in under its switch.
          _Nested(
            children: [
              ChoiceGroup<HaftarahNusach>(
                title: l.nusachLabel,
                headingLevel: 3,
                segmented: true,
                value: s.nusach,
                choices: [
                  Choice(HaftarahNusach.ashkenazi, l.nusachAshkenazi),
                  Choice(HaftarahNusach.sephardi, l.nusachSephardi),
                  Choice(HaftarahNusach.chabad, l.nusachChabad),
                ],
                // Also the last verse's repeat, while it follows the custom:
                // a switch further up, perhaps out of sight, so it says so.
                onChanged: (v) {
                  final repeat = ref.read(settingsProvider).repeatLastVerse;
                  update((s) => s.withNusach(v));
                  final now = ref.read(settingsProvider).repeatLastVerse;
                  if (now != repeat) {
                    showStatus(context, now ? l.repeatLastVerseBackOn : l.repeatLastVerseFollowsChabad);
                  }
                },
              ),
              const Gap(Space.lg),
              PaperGroup(
                children: [
                  SwitchRow(
                    title: l.haftarahRequired,
                    value: s.haftarahRequired,
                    onChanged: (v) => update((s) => s.copyWith(haftarahRequired: v)),
                  ),
                ],
              ),
            ],
          ),
        ],
        ...section(l.readingGroupSpecialDays, [
          PaperGroup(
            children: [
              SwitchRow(
                title: l.tishaBavQuiet,
                value: s.tishaBavQuiet,
                onChanged: (v) => update((s) => s.copyWith(tishaBavQuiet: v)),
              ),
              SwitchRow(
                title: l.cholHamoedQuiet,
                value: s.cholHamoedQuiet,
                onChanged: (v) => update((s) => s.copyWith(cholHamoedQuiet: v)),
              ),
            ],
          ),
        ]),
        ChoiceGroup<NameStyle>(
          title: l.nameStyleLabel,
          segmented: true,
          value: s.nameStyle,
          choices: [
            Choice(NameStyle.sephardi, _glossed(l.nameSephardi), semanticsLabel: l.nameSephardi),
            Choice(NameStyle.ashkenazi, _glossed(l.nameAshkenazi), semanticsLabel: l.nameAshkenazi),
          ],
          onChanged: (v) => update((s) => s.copyWith(nameStyle: v)),
        ),
        const Gap(Rhythm.sectionGap),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
          child: Text(l.disclaimer, style: SeferType.of(context).marginalia),
        ),
      ],
    );
  }
}

/// [label] with its gloss, what follows its comma or opens its parenthesis
/// ("One, as in Israel"; "Sephardi (Bereshit)"), on a line of its own: so
/// that a segment's label breaks there or nowhere, the same whichever is
/// selected and bears the check.
String _glossed(String label) => label.replaceFirst(RegExp(r'(?<=,) | (?=\()'), '\n');

/// Settings that belong to the one above them, set in by 16 behind a 2 px
/// rule in outlineVariant at their start.
class _Nested extends StatelessWidget {
  const _Nested({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final sefer = SeferColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.only(start: Space.lg),
      decoration: BoxDecoration(
        // In high contrast every rule is the outline, as hairlines are.
        border: BorderDirectional(
          start: BorderSide(color: sefer.isHighContrast ? scheme.outline : scheme.outlineVariant, width: 2),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}
