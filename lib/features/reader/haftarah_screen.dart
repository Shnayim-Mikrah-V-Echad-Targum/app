import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/text/hebrew_text.dart';
import '../../data/text_repository.dart';
import '../../services/feedback.dart';
import '../../services/tts.dart';
import '../../ui/l10n.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fallbacks.dart';
import '../parsha/week_context.dart';
import 'display_sheet.dart';
import 'scripture_text.dart';

final haftarahTextProvider = FutureProvider.family<List<HaftarahVerse>, String>((ref, weekId) async {
  final ctx = ref.watch(weekContextProvider(weekId));
  if (ctx == null) return const [];
  return ref.watch(textRepositoryProvider).haftarah(ctx.haftarah.parts);
});

/// The week's haftarah, read once.
class HaftarahScreen extends ConsumerWidget {
  const HaftarahScreen({super.key, required this.weekId});

  final String weekId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final ctx = ref.watch(weekContextProvider(weekId));
    final settings = ref.watch(settingsProvider);
    final verses = ref.watch(haftarahTextProvider(weekId));
    // A link to a week that doesn't exist.
    if (ctx == null) return const NotFoundPage();
    final styles = ScriptureStyles(context, settings);
    final done = ctx.progress.haftarah != null;
    final tts = ref.watch(ttsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: homeLeading(context),
        title: Text('${l.haftarahTitle} · ${names.portion(ctx.portion, ashkenazi: settings.ashkenaziNames)}'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: tts.speaking,
            builder: (context, speaking, _) => IconButton(
              tooltip: speaking ? l.stopListening : l.listen,
              icon: Icon(speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
              onPressed: () async {
                if (speaking) return tts.stop();
                final list = verses.value ?? const [];
                final text = list.map((v) => HebrewSpeech.spoken(v.hebrew.readText, divineName: settings.divineName)).join(' ');
                try {
                  await tts.speak(text, language: 'he-IL', rate: settings.speechRate);
                } catch (_) {
                  if (context.mounted) showStatus(context, l.ttsUnavailable);
                }
              },
            ),
          ),
          IconButton(
            tooltip: l.displaySettings,
            icon: const Icon(Icons.text_format),
            onPressed: () => showDisplaySheet(context),
          ),
        ],
      ),
      body: verses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorGeneric)),
        data: (list) => PageBody(
          maxWidth: styles.maxLineWidth,
          children: [
            Text(
              ctx.haftarah.parts
                  .map((p) => names.range(p.book, p.start.chapter, p.start.verse, p.end.chapter, p.end.verse))
                  .join(' · '),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (ctx.haftarah.specialKey != null)
              Text(l.specialHaftarah(names.specialHaftarah(ctx.haftarah.specialKey!))),
            const Gap(12),
            for (var i = 0; i < list.length; i++) ...[
              if (i == 0 || list[i].book != list[i - 1].book)
                SectionHeader(names.book(list[i].book), level: 3),
              ScriptureVerse(verse: list[i].hebrew, kind: ScriptureKind.mikra, settings: settings),
              if (settings.showTranslation)
                TranslationVerse(text: list[i].english, number: list[i].hebrew.ref.verse, settings: settings),
              const Gap(10),
            ],
            const Gap(16),
            if (ctx.isOpen)
              done
                  ? OutlinedButton.icon(
                      icon: const Icon(Icons.check_circle),
                      label: Text(l.haftarahRead),
                      onPressed: () => ref.read(progressProvider.notifier).markHaftarah(ctx.id, null),
                    )
                  : FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: Text(l.markHaftarahRead),
                      onPressed: () {
                        ref.read(progressProvider.notifier).markHaftarah(ctx.id, ref.read(todayProvider));
                        hapticSuccess(ref);
                        showStatus(context, l.markedRead);
                      },
                    ),
          ],
        ),
      ),
    );
  }
}
