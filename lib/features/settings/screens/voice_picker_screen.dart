import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../services/feedback.dart';
import '../../../services/hebrew_voice/hebrew_voice.dart';
import '../../../services/hebrew_voice/voice_catalogue.dart';
import '../../../services/hebrew_voice/voice_settings.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/paper_group.dart';
import '../widgets/hebrew_voice_row.dart';
import '../widgets/settings_widgets.dart';

/// The voice that reads [role] (Settings, Accessibility, Hebrew voice):
/// for the Targum and the haftarah, the Torah's by default; the device's
/// own; or one of the app's, every one there is, the clearest first in each
/// group. A voice not on the device is fetched as it is chosen, and reads
/// once it has come; each one on the device can be heard, and taken off.
class VoicePickerScreen extends ConsumerStatefulWidget {
  const VoicePickerScreen({super.key, required this.role});

  final SpeechRole role;

  @override
  ConsumerState<VoicePickerScreen> createState() => _VoicePickerScreenState();
}

class _VoicePickerScreenState extends ConsumerState<VoicePickerScreen> {
  final _sample = VoiceSamplePlayer();

  @override
  void dispose() {
    _sample.dispose();
    super.dispose();
  }

  /// The voice chosen for the role: null for the Torah's (the Targum and the
  /// haftarah only).
  String? get _chosen {
    final s = ref.read(settingsProvider).voice;
    return switch (widget.role) {
      SpeechRole.mikrah => s.torah,
      SpeechRole.targum => s.targum,
      SpeechRole.haftarah => s.haftarah,
    };
  }

  void _choose(String? id) =>
      ref.read(settingsProvider.notifier).update((a) => a.copyWith(voice: a.voice.withVoice(widget.role, id)));

  Future<void> _pick(HebrewVoiceOption voice) async {
    final voices = ref.read(hebrewVoicesProvider);
    final l = context.l10n;
    final name = voiceName(context, voice);
    _choose(voice.id);
    if (voices.ready(voice.id) || voices.status(voice.id).value.state == HebrewVoiceState.downloading) return;
    try {
      await voices.install(voice.id);
      if (mounted) showStatus(context, l.voiceReadyStatus(name), outlivesPage: true);
    } catch (_) {
      if (mounted) showStatus(context, l.voiceFailedStatus(name), outlivesPage: true);
    }
  }

  Future<void> _hear(HebrewVoiceOption voice) async {
    final settings = ref.read(settingsProvider);
    final wav = await ref
        .read(hebrewVoicesProvider)
        .speak(voiceSample(widget.role, settings), id: voice.id, settings: settings.voice, speed: voiceSpeed(settings));
    if (mounted) await _sample.play(wav);
  }

  Future<void> _remove(HebrewVoiceOption voice) async {
    final l = context.l10n;
    final name = voiceName(context, voice);
    await _sample.stop();
    await ref.read(hebrewVoicesProvider).remove(voice.id);
    if (mounted) showStatus(context, l.voiceRemovedStatus(name));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final voices = ref.watch(hebrewVoicesProvider);
    // Rebuilt as the choice changes.
    ref.watch(settingsProvider.select((a) => a.voice));
    final chosen = _chosen;
    final settings = ref.read(settingsProvider).voice;
    Widget radio(bool on) => Icon(
          on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: on ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return ListenableBuilder(
      listenable: voices.changes,
      builder: (context, _) => SettingsPage(
        title: switch (widget.role) {
          SpeechRole.mikrah => l.voiceChooseTorah,
          SpeechRole.targum => l.voiceChooseTargum,
          SpeechRole.haftarah => l.voiceChooseHaftarah,
        },
        paper: true,
        children: [
          const Gap(Space.sm),
          PaperGroup(
            children: [
              if (widget.role != SpeechRole.mikrah)
                PaperRow(
                  leading: radio(chosen == null),
                  title: l.voiceSameAsTorah,
                  subtitle: voiceSummary(context, voices, settings, SpeechRole.mikrah),
                  subtitleMaxLines: null,
                  selected: chosen == null,
                  chevron: false,
                  onTap: () => _choose(null),
                ),
              PaperRow(
                leading: radio(chosen == VoiceSettings.deviceVoice),
                title: l.voiceDevice,
                subtitle: l.voiceDeviceDesc,
                subtitleMaxLines: null,
                selected: chosen == VoiceSettings.deviceVoice,
                chevron: false,
                onTap: () => _choose(VoiceSettings.deviceVoice),
              ),
            ],
          ),
          for (final group in VoiceGroup.values) ...[
            SettingHeading(
              switch (group) {
                VoiceGroup.recommended => l.voiceGroupRecommended,
                VoiceGroup.more => l.voiceGroupMore,
                VoiceGroup.experimental => l.voiceGroupExperimental,
              },
              help: switch (group) {
                VoiceGroup.recommended => l.voiceClarityHelp,
                VoiceGroup.more => null,
                VoiceGroup.experimental => l.voiceGroupExperimentalDesc,
              },
            ),
            PaperGroup(
              children: [
                for (final voice in voices.voices.where((v) => v.group == group))
                  _VoiceRow(
                    voice: voice,
                    status: voices.status(voice.id).value,
                    chosen: chosen == voice.id,
                    radio: radio(chosen == voice.id),
                    toFetch: voices.bytesToFetch(voice.id),
                    onPick: () => _pick(voice),
                    onHear: () => _hear(voice),
                    onRemove: () => _remove(voice),
                  ),
              ],
            ),
          ],
          const Gap(Space.lg),
        ],
      ),
    );
  }
}

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.voice,
    required this.status,
    required this.chosen,
    required this.radio,
    required this.toFetch,
    required this.onPick,
    required this.onHear,
    required this.onRemove,
  });

  final HebrewVoiceOption voice;
  final HebrewVoiceStatus status;
  final bool chosen;
  final Widget radio;
  final int toFetch;
  final VoidCallback onPick;
  final VoidCallback onHear;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final name = voiceName(context, voice);
    final state = switch (status.state) {
      HebrewVoiceState.ready => l.voiceOnDevice,
      HebrewVoiceState.downloading => l.voiceDownloading((status.progress * 100).floor()),
      HebrewVoiceState.failed => l.voiceFailed,
      HebrewVoiceState.absent => l.voiceToDownload(voiceSize(l, toFetch)),
    };
    return PaperRow(
      leading: radio,
      title: name,
      subtitleParts: [
        voice.gender == VoiceGender.male ? l.voiceMale : l.voiceFemale,
        ?voice.model,
        l.voiceClarity((voice.clarity * 100).round()),
        switch (voice.speed) {
          VoiceSpeed.quick => l.voiceQuick,
          VoiceSpeed.moderate => l.voiceModerate,
          VoiceSpeed.slow => l.voiceSlow,
        },
        state,
      ],
      selected: chosen,
      liveRegion: status.state == HebrewVoiceState.downloading,
      chevron: false,
      onTap: onPick,
      trailing: switch (status.state) {
        HebrewVoiceState.ready => PopupMenuButton<VoidCallback>(
            tooltip: l.voiceMore(name),
            icon: const Icon(Icons.more_vert),
            popUpAnimationStyle: Motion.of(context).style,
            onSelected: (action) => action(),
            itemBuilder: (context) => [
              PopupMenuItem(value: onHear, child: Text(l.voiceHear)),
              PopupMenuItem(value: onRemove, child: Text(l.voiceRemove)),
            ],
          ),
        HebrewVoiceState.downloading => Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(value: status.progress, strokeWidth: 3)),
          ),
        HebrewVoiceState.absent || HebrewVoiceState.failed => const ExcludeSemantics(
            child: Padding(padding: EdgeInsets.all(12), child: Icon(Icons.download_outlined)),
          ),
      },
    );
  }
}
