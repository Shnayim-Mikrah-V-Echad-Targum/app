import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/models/parsha.dart';
import '../../../ui/l10n.dart';
import '../../progress/domain/reading_plan.dart';
import '../../progress/domain/streak_engine.dart';
import '../app_settings.dart';
import '../widgets/settings_widgets.dart';

class ReadingSettingsScreen extends ConsumerWidget {
  const ReadingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    void update(AppSettings Function(AppSettings) f) => ref.read(settingsProvider.notifier).update(f);

    return SettingsPage(
      title: l.settingsReading,
      children: [
        ChoiceGroup<bool>(
          title: l.locationLabel,
          help: l.locationHelp,
          value: s.israel,
          choices: [Choice(false, l.locationDiaspora), Choice(true, l.locationIsrael)],
          onChanged: (v) => update((s) => s.copyWith(israel: v)),
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
            Choice(ReadingMethod.verseByVerse, l.methodVerse, subtitle: l.methodVerseDesc),
            Choice(ReadingMethod.sectionBySection, l.methodSection, subtitle: l.methodSectionDesc),
            Choice(ReadingMethod.aliyahByAliyah, l.methodAliyah, subtitle: l.methodAliyahDesc),
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
          subtitle: Text(l.repeatLastVerseDesc),
          value: s.repeatLastVerse,
          onChanged: (v) => update((s) => s.copyWith(repeatLastVerse: v)),
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
            onChanged: (v) => update((s) => s.copyWith(nusach: v)),
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
