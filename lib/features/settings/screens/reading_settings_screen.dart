import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/models/parsha.dart';
import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../progress/domain/reading_plan.dart';
import '../app_settings.dart';
import '../widgets/settings_widgets.dart';

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

    return SettingsPage(
      title: l.settingsReading,
      children: [
        ChoiceGroup<ReadingSchedule>(
          title: l.readingScheduleLabel,
          help: l.readingScheduleHelp,
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
          value: s.oneDayYomTov,
          choices: [Choice(true, l.yomTovDaysOne), Choice(false, l.yomTovDaysTwo)],
          onChanged: (v) => update((s) => s.copyWith(oneDayYomTov: v)),
        ),
        ChoiceGroup<ReadingPlanType>(
          title: l.planLabel,
          value: s.plan,
          choices: [
            Choice(ReadingPlanType.aliyahPerDay, l.planAliyahPerDay, subtitle: l.planAliyahPerDayDesc),
            Choice(ReadingPlanType.sheviiOnShabbat, l.planShevii, subtitle: l.planSheviiDesc),
            Choice(ReadingPlanType.erevShabbat, l.planErevShabbat, subtitle: l.planErevShabbatDesc),
          ],
          onChanged: (v) => update((s) => s.copyWith(plan: v)),
        ),
        ChoiceGroup<ReadingMethod>(
          title: l.methodLabel,
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
          value: s.secondReading,
          choices: [
            Choice(SecondReading.onkelos, l.secondOnkelos),
            Choice(SecondReading.rashi, l.secondRashi),
            Choice(SecondReading.onkelosAndRashi, l.secondBoth),
            Choice(SecondReading.rashiEnglish, l.secondRashiEnglish),
          ],
          onChanged: (v) => update((s) => s.copyWith(secondReading: v)),
        ),
        const Divider(height: 32),
        SwitchListTile(
          title: Text(l.repeatLastVerse),
          subtitle: Text(s.nusach == HaftarahNusach.chabad ? l.repeatLastVerseDescChabad : l.repeatLastVerseDesc),
          value: s.repeatLastVerse,
          onChanged: (v) => update((s) => s.withRepeatLastVerse(v)),
        ),
        SwitchListTile(
          title: Text(l.thirdReading),
          subtitle: Text(l.thirdReadingDesc),
          value: s.thirdReadingPrompts,
          onChanged: (v) => update((s) => s.copyWith(thirdReadingPrompts: v)),
        ),
        SwitchListTile(
          title: Text(l.haftarahEnabled),
          subtitle: Text(l.haftarahEnabledDesc),
          value: s.haftarahEnabled,
          onChanged: (v) => update((s) => s.copyWith(haftarahEnabled: v)),
        ),
        if (s.haftarahEnabled) ...[
          ChoiceGroup<HaftarahNusach>(
            title: l.nusachLabel,
            value: s.nusach,
            choices: [
              Choice(HaftarahNusach.ashkenazi, l.nusachAshkenazi),
              Choice(HaftarahNusach.sephardi, l.nusachSephardi),
              Choice(HaftarahNusach.chabad, l.nusachChabad),
            ],
            // Also the last verse's repeat, while it follows the custom.
            onChanged: (v) => update((s) => s.withNusach(v)),
          ),
          SwitchListTile(
            title: Text(l.haftarahRequired),
            value: s.haftarahRequired,
            onChanged: (v) => update((s) => s.copyWith(haftarahRequired: v)),
          ),
        ],
        ChoiceGroup<LateWindow>(
          title: l.lateWindowLabel,
          help: l.lateWindowDesc,
          value: s.lateWindow,
          choices: [
            Choice(LateWindow.tuesday, l.lateTuesday),
            Choice(LateWindow.wednesday, l.lateWednesday),
            Choice(LateWindow.none, l.lateNone),
          ],
          onChanged: (v) => update((s) => s.copyWith(lateWindow: v)),
        ),
        const Divider(height: 32),
        SwitchListTile(
          title: Text(l.tishaBavQuiet),
          value: s.tishaBavQuiet,
          onChanged: (v) => update((s) => s.copyWith(tishaBavQuiet: v)),
        ),
        SwitchListTile(
          title: Text(l.cholHamoedQuiet),
          value: s.cholHamoedQuiet,
          onChanged: (v) => update((s) => s.copyWith(cholHamoedQuiet: v)),
        ),
        ChoiceGroup<NameStyle>(
          title: l.nameStyleLabel,
          value: s.nameStyle,
          choices: [Choice(NameStyle.sephardi, l.nameSephardi), Choice(NameStyle.ashkenazi, l.nameAshkenazi)],
          onChanged: (v) => update((s) => s.copyWith(nameStyle: v)),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l.disclaimer, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
