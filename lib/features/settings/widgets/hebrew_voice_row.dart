import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/text/hebrew_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/hebrew_voice/hebrew_voice.dart';
import '../../../services/hebrew_voice/voice_catalogue.dart';
import '../../../services/hebrew_voice/voice_settings.dart';
import '../../../services/tts.dart';
import '../../../ui/l10n.dart';
import '../../../ui/widgets/paper_group.dart';
import '../app_settings.dart';

/// Settings, Accessibility, Speech: the app's own Hebrew voices, which
/// opens their page (HebrewVoiceScreen), saying which reads the Torah.
class HebrewVoiceRow extends ConsumerWidget {
  const HebrewVoiceRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voices = ref.watch(hebrewVoicesProvider);
    final settings = ref.watch(settingsProvider.select((s) => s.voice));
    return ListenableBuilder(
      listenable: voices.changes,
      builder: (context, _) => PaperRow(
        icon: Icons.record_voice_over_outlined,
        title: context.l10n.hebrewVoice,
        subtitle: voiceSummary(context, voices, settings, SpeechRole.mikrah),
        subtitleMaxLines: null,
        onTap: () => context.push('/settings/accessibility/voice'),
      ),
    );
  }
}

/// [voice]'s name in the interface's language.
String voiceName(BuildContext context, HebrewVoiceOption voice) =>
    Localizations.localeOf(context).languageCode == 'he' ? voice.nameHe : voice.name;

/// [bytes] as megabytes, rounded, at least one.
String voiceSize(AppLocalizations l, int bytes) => l.voiceMegabytes((bytes / 1000000).round().clamp(1, 1 << 20));

/// The setting's own name for [role].
String roleTitle(AppLocalizations l, SpeechRole role) => switch (role) {
      SpeechRole.mikrah => l.voiceForTorah,
      SpeechRole.targum => l.voiceForTargum,
      SpeechRole.haftarah => l.voiceForHaftarah,
    };

/// Who reads [role], as Listen will: the voice chosen, on the device, or the
/// one that reads in its place meanwhile.
String voiceSummary(BuildContext context, HebrewVoices voices, VoiceSettings settings, SpeechRole role) {
  final l = context.l10n;
  if (role != SpeechRole.mikrah && (role == SpeechRole.targum ? settings.targum : settings.haftarah) == null) {
    return '${l.voiceSameAsTorah} · ${voiceSummary(context, voices, settings, SpeechRole.mikrah)}';
  }
  final id = settings.voiceFor(role);
  if (id == VoiceSettings.deviceVoice) return l.voiceDevice;
  final voice = hebrewVoiceById(id);
  if (voice == null) return l.voiceDevice;
  final name = voiceName(context, voice);
  if (voices.ready(id)) return l.voiceSummaryReady(name);
  final instead = voices.readyVoices.firstOrNull;
  return instead == null ? l.voiceSummaryDeviceMeanwhile(name) : l.voiceSummaryFallback(name, voiceName(context, instead));
}

/// The verse each role's sample reads: the first of the Torah, of Onkelos,
/// and of the haftarah of Nachamu.
String voiceSample(SpeechRole role, AppSettings settings) => switch (role) {
      SpeechRole.mikrah =>
        HebrewSpeech.spoken('בְּרֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים אֵ֥ת הַשָּׁמַ֖יִם וְאֵ֥ת הָאָֽרֶץ׃', keepTeamim: true, divineName: settings.divineName),
      SpeechRole.targum =>
        HebrewSpeech.spoken('בְּקַדְמִין בְּרָא יְיָ יָת שְׁמַיָּא וְיָת אַרְעָא׃', keepTeamim: true, divineName: settings.divineName, targum: true),
      SpeechRole.haftarah => HebrewSpeech.spoken('נַחֲמ֥וּ נַחֲמ֖וּ עַמִּ֑י יֹאמַ֖ר אֱלֹהֵיכֶֽם׃', keepTeamim: true, divineName: settings.divineName),
    };

/// Plays a voice's sample (in the voice list), one at a time: a new one
/// stops the last, as does leaving the page.
class VoiceSamplePlayer {
  AudioPlayer? _player;

  Future<void> play(Uint8List wav) async {
    final player = _player ??= AudioPlayer();
    await player.stop();
    await player.play(BytesSource(wav, mimeType: 'audio/wav'));
  }

  Future<void> stop() async => _player?.stop();

  void dispose() {
    unawaited(_player?.dispose());
    _player = null;
  }
}

/// Reads [role]'s sample as Listen would, through the speech service: in
/// the voice chosen for it, or the one reading in its place.
Future<void> playRoleSample(WidgetRef ref, SpeechRole role) async {
  final settings = ref.read(settingsProvider);
  await ref.read(ttsProvider).speak(voiceSample(role, settings), language: 'he-IL', rate: settings.speechRate, role: role);
}

/// The speed Listen reads at, relative to the voices' own pace.
double voiceSpeed(AppSettings settings) => (settings.speechRate / kDefaultSpeechRate).clamp(0.25, 4.0);
