import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/text/hebrew_pronunciation.dart';
import '../../../services/feedback.dart';
import '../../../services/hebrew_voice/hebrew_voice.dart';
import '../../../services/hebrew_voice/voice_settings.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/paper_group.dart';
import '../widgets/hebrew_voice_row.dart';
import '../widgets/settings_widgets.dart';

/// Settings, Accessibility, Hebrew voice: which of the app's voices reads
/// the Torah, the Targum and the haftarah, how they say the vowels on which
/// the traditions differ and where they stress a word, how they sound, and
/// what they take up on the device (docs/DESIGN_SYSTEM.md §9). Every choice
/// starts at the best the app's tests found, and every one can be changed.
class HebrewVoiceScreen extends ConsumerWidget {
  const HebrewVoiceScreen({super.key});

  /// The Piper voices' own variation of sound and of timing (PiperSpec),
  /// which the sliders show until the reader moves them.
  static const piperVariation = 0.4;
  static const piperRhythm = 0.5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final voices = ref.watch(hebrewVoicesProvider);
    final s = ref.watch(settingsProvider.select((a) => a.voice));
    void update(VoiceSettings Function(VoiceSettings) f) => ref.read(settingsProvider.notifier).update((a) => a.copyWith(voice: f(a.voice)));
    final p = s.pronunciation;
    final preset = p.preset;
    // Examples are in Latin letters, read in their own voice.
    const latin = Locale('en');

    return ListenableBuilder(
      listenable: voices.changes,
      builder: (context, _) {
        final onDevice = voices.readyVoices;
        return SettingsPage(
          title: l.hebrewVoice,
          paper: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, Space.sm, 4, 0),
              child: Text(l.hebrewVoiceIntro, style: Theme.of(context).textTheme.bodyMedium),
            ),
            GroupHeader(l.voiceWhoReads),
            PaperGroup(
              children: [
                for (final role in SpeechRole.values)
                  PaperRow(
                    icon: switch (role) {
                      SpeechRole.mikrah => Icons.menu_book_outlined,
                      SpeechRole.targum => Icons.translate_outlined,
                      SpeechRole.haftarah => Icons.auto_stories_outlined,
                    },
                    title: roleTitle(l, role),
                    subtitle: voiceSummary(context, voices, s, role),
                    subtitleMaxLines: null,
                    onTap: () => context.push('/settings/accessibility/voice/${role.name}'),
                  ),
                PaperRow(
                  icon: Icons.play_circle_outline,
                  title: l.voicePlaySample,
                  subtitle: l.voicePlaySampleDesc,
                  onTap: () => playRoleSample(ref, SpeechRole.mikrah),
                ),
              ],
            ),
            ChoiceGroup<HebrewPronunciationPreset?>(
              title: l.pronunciationTitle,
              help: l.pronunciationHelp,
              value: preset,
              choices: [
                Choice(HebrewPronunciationPreset.israeli, l.pronIsraeli, subtitle: 'barukh, kohen, Torah, Shabbat'),
                Choice(HebrewPronunciationPreset.lithuanian, l.pronLithuanian, subtitle: 'borukh, keihein, Teiroh, Shabbos'),
                Choice(HebrewPronunciationPreset.polish, l.pronPolish, subtitle: 'burikh, koihain, Toiruh, Shabbus'),
                Choice(HebrewPronunciationPreset.hungarian, l.pronHungarian, subtitle: 'borukh, koihein, Toiroh, Shabbos'),
                Choice(HebrewPronunciationPreset.german, l.pronGerman, subtitle: 'borukh, kouhein, Touroh, Shabbos'),
                if (preset == null) Choice(null, l.pronCustom, subtitle: l.pronCustomDesc),
              ],
              onChanged: (v) {
                if (v != null) update((s) => s.copyWith(pronunciation: s.pronunciation.withPreset(v)));
              },
            ),
            SettingHeading(l.pronEachSound, level: 3),
            ChoiceGroup<QamatzSound>(
              title: l.pronQamatz,
              headingLevel: 3,
              segmented: true,
              value: p.qamatz,
              choices: [
                Choice(QamatzSound.a, 'a', semanticsLabel: 'a, barukh', locale: latin),
                Choice(QamatzSound.o, 'o', semanticsLabel: 'o, borukh', locale: latin),
                Choice(QamatzSound.u, 'u', semanticsLabel: 'u, burukh', locale: latin),
              ],
              onChanged: (v) => update((s) => s.copyWith(pronunciation: s.pronunciation.copyWith(qamatz: v))),
            ),
            ChoiceGroup<HolamSound>(
              title: l.pronHolam,
              headingLevel: 3,
              segmented: true,
              value: p.holam,
              choices: [
                for (final h in HolamSound.values) Choice(h, h.sound.replaceAll('j', 'y'), locale: latin),
              ],
              onChanged: (v) => update((s) => s.copyWith(pronunciation: s.pronunciation.copyWith(holam: v))),
            ),
            ChoiceGroup<TsereSound>(
              title: l.pronTsere,
              headingLevel: 3,
              segmented: true,
              value: p.tsere,
              choices: [
                for (final t in TsereSound.values) Choice(t, t.sound.replaceAll('j', 'y'), locale: latin),
              ],
              onChanged: (v) => update((s) => s.copyWith(pronunciation: s.pronunciation.copyWith(tsere: v))),
            ),
            ChoiceGroup<ShurukSound>(
              title: l.pronShuruk,
              headingLevel: 3,
              segmented: true,
              value: p.shuruk,
              choices: [for (final u in ShurukSound.values) Choice(u, u.sound, locale: latin)],
              onChanged: (v) => update((s) => s.copyWith(pronunciation: s.pronunciation.copyWith(shuruk: v))),
            ),
            ChoiceGroup<TavRafeSound>(
              title: l.pronTav,
              headingLevel: 3,
              segmented: true,
              value: p.tavRafe,
              choices: [
                Choice(TavRafeSound.t, 't', semanticsLabel: 't, Shabbat', locale: latin),
                Choice(TavRafeSound.s, 's', semanticsLabel: 's, Shabbos', locale: latin),
              ],
              onChanged: (v) => update((s) => s.copyWith(pronunciation: s.pronunciation.copyWith(tavRafe: v))),
            ),
            ChoiceGroup<StressRule>(
              title: l.stressTitle,
              value: p.stress,
              choices: [
                Choice(StressRule.accents, l.stressAccents, subtitle: l.stressAccentsDesc),
                Choice(StressRule.penultimate, l.stressPenultimate, subtitle: l.stressPenultimateDesc),
              ],
              onChanged: (v) => update((s) => s.copyWith(pronunciation: s.pronunciation.copyWith(stress: v))),
            ),
            GroupHeader(l.voiceSoundTitle),
            PaperGroup(
              children: [
                SwitchRow(
                  icon: Icons.more_horiz,
                  title: l.voicePauses,
                  subtitle: l.voicePausesDesc,
                  value: s.pauses,
                  onChanged: (v) => update((s) => s.copyWith(pauses: v)),
                ),
                SwitchRow(
                  icon: Icons.graphic_eq,
                  title: l.voiceEvenLoudness,
                  subtitle: l.voiceEvenLoudnessDesc,
                  value: s.evenLoudness,
                  onChanged: (v) => update((s) => s.copyWith(evenLoudness: v)),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: LabeledSlider(
                    title: l.voiceVariation,
                    group: [l.voiceVariation, l.voiceRhythm, l.voiceSteps, l.voiceGuidance],
                    value: s.variation ?? piperVariation,
                    min: 0,
                    max: 1,
                    step: 0.05,
                    format: (v) => s.variation == null ? l.voiceOwnValue : '${(v * 100).round()}%',
                    onChanged: (v) => update((s) => s.copyWith(variation: () => v)),
                  ),
                ),
                LabeledSlider(
                  title: l.voiceRhythm,
                  group: [l.voiceVariation, l.voiceRhythm, l.voiceSteps, l.voiceGuidance],
                  value: s.rhythm ?? piperRhythm,
                  min: 0,
                  max: 1.5,
                  step: 0.05,
                  format: (v) => s.rhythm == null ? l.voiceOwnValue : '${(v * 100).round()}%',
                  onChanged: (v) => update((s) => s.copyWith(rhythm: () => v)),
                ),
                LabeledSlider(
                  title: l.voiceSteps,
                  group: [l.voiceVariation, l.voiceRhythm, l.voiceSteps, l.voiceGuidance],
                  value: s.steps.toDouble(),
                  min: 2,
                  max: 32,
                  step: 1,
                  format: (v) => l.voiceStepsValue(v.round()),
                  onChanged: (v) => update((s) => s.copyWith(steps: v.round())),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.xs),
                  child: LabeledSlider(
                    title: l.voiceGuidance,
                    group: [l.voiceVariation, l.voiceRhythm, l.voiceSteps, l.voiceGuidance],
                    value: s.guidance,
                    min: 1,
                    max: 5,
                    step: 0.25,
                    format: (v) => v.toStringAsFixed(2),
                    onChanged: (v) => update((s) => s.copyWith(guidance: v)),
                  ),
                ),
                PaperRow(
                  icon: Icons.restart_alt,
                  title: l.voiceResetSound,
                  onTap: () => update(
                    (s) => s.copyWith(
                      pauses: true,
                      evenLoudness: true,
                      variation: () => null,
                      rhythm: () => null,
                      steps: VoiceSettings.defaultSteps,
                      guidance: VoiceSettings.defaultGuidance,
                    ),
                  ),
                ),
              ],
            ),
            GroupHeader(l.voiceStorageTitle),
            PaperGroup(
              children: [
                PaperRow(
                  icon: Icons.sd_storage_outlined,
                  title: l.voiceStorageSummary(onDevice.length, voiceSize(l, voices.bytesOnDevice)),
                  liveRegion: true,
                ),
                if (onDevice.isNotEmpty)
                  PaperRow(
                    title: l.voiceRemoveAll,
                    destructive: true,
                    onTap: () => _removeAll(context, voices),
                  ),
              ],
            ),
            const Gap(Space.lg),
          ],
        );
      },
    );
  }

  static Future<void> _removeAll(BuildContext context, HebrewVoices voices) async {
    final l = context.l10n;
    final sure = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.voiceRemoveAllConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l.voiceRemoveAll)),
        ],
      ),
    );
    if (sure != true) return;
    for (final v in voices.readyVoices) {
      await voices.remove(v.id);
    }
    if (context.mounted) showStatus(context, l.voiceRemoveAllDone);
  }
}
