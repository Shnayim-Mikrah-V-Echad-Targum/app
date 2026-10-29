import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/feedback.dart';
import '../../../services/hebrew_voice/hebrew_voice.dart';
import '../../../ui/l10n.dart';
import 'settings_widgets.dart';

/// Turns the app's own Hebrew voice on, which fetches it (64 MB, once), or
/// off, which takes it off the device (Settings, Accessibility, Speech). The
/// row says how far the fetch has come while it lasts, and why the voice is
/// off after one failed.
class HebrewVoiceRow extends ConsumerWidget {
  const HebrewVoiceRow({super.key});

  /// The voice's size, as the row tells it: in megabytes, rounded.
  static final sizeMb = (HebrewVoice.sizeBytes / 1000000).round();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final voice = ref.watch(hebrewVoiceProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([voice.state, voice.progress]),
      builder: (context, _) {
        final state = voice.state.value;
        final subtitle = switch (state) {
          HebrewVoiceState.absent => l.hebrewVoiceDesc(sizeMb),
          HebrewVoiceState.downloading => l.hebrewVoiceDownloading((voice.progress.value * 100).floor()),
          HebrewVoiceState.ready => l.hebrewVoiceReady(sizeMb),
          HebrewVoiceState.failed => l.hebrewVoiceFailed,
        };
        return SwitchRow(
          icon: Icons.record_voice_over_outlined,
          title: l.hebrewVoice,
          subtitle: subtitle,
          value: state == HebrewVoiceState.ready || state == HebrewVoiceState.downloading,
          onChanged: state == HebrewVoiceState.downloading
              ? null
              : (on) async {
                  if (!on) {
                    await voice.remove();
                    return;
                  }
                  try {
                    await voice.install();
                    if (context.mounted) showStatus(context, l.hebrewVoiceInstalled, outlivesPage: true);
                  } catch (_) {
                    if (context.mounted) showStatus(context, l.hebrewVoiceFailed, outlivesPage: true);
                  }
                },
        );
      },
    );
  }
}
