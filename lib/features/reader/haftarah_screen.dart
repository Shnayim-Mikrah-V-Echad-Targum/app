import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/text/hebrew_text.dart';
import '../../data/models/parsha.dart';
import '../../data/text_repository.dart';
import '../../services/feedback.dart';
import '../../services/tts.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/motion.dart';
import '../../ui/theme/sefer_colors.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fallbacks.dart';
import '../parsha/week_context.dart';
import '../settings/app_settings.dart';
import 'display_sheet.dart';
import 'scripture_text.dart';

final haftarahTextProvider = FutureProvider.family<List<HaftarahVerse>, String>((ref, weekId) async {
  final ctx = ref.watch(weekContextProvider(weekId));
  if (ctx == null) return const [];
  return ref.watch(textRepositoryProvider).haftarah(ctx.haftarah.parts);
});

/// The portion's own haftarah, in a week a special one displaces it.
final regularHaftarahTextProvider = FutureProvider.family<List<HaftarahVerse>, String>((ref, weekId) async {
  final regular = ref.watch(weekContextProvider(weekId))?.haftarah.regular;
  if (regular == null) return const [];
  return ref.watch(textRepositoryProvider).haftarah(regular);
});

/// The references of [haftarah]'s passages, e.g. "Isaiah 42:5–43:10".
String haftarahRefs(Names names, Haftarah haftarah) => haftarah
    .map((p) => names.range(p.book, p.start.chapter, p.start.verse, p.end.chapter, p.end.verse))
    .join(' · ');

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
            Text(haftarahRefs(names, ctx.haftarah.parts), style: Theme.of(context).textTheme.titleMedium),
            if (ctx.haftarah.specialKey != null)
              Text(l.specialHaftarah(names.specialHaftarah(ctx.haftarah.specialKey!))),
            if (ctx.haftarah.fallback) ...[
              const Gap(12),
              NoticeBanner(icon: Icons.info_outline, text: l.chabadFallbackNote),
            ],
            const Gap(12),
            ..._verses(names, settings, list),
            if (ctx.haftarah.regular != null) ...[
              const Gap(8),
              _RegularHaftarah(ctx: ctx),
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

/// A haftarah's verses, under the name of each book they come from.
List<Widget> _verses(Names names, AppSettings settings, List<HaftarahVerse> list) => [
      for (var i = 0; i < list.length; i++) ...[
        if (i == 0 || list[i].book != list[i - 1].book) SectionHeader(names.book(list[i].book), level: 3),
        ScriptureVerse(verse: list[i].hebrew, kind: ScriptureKind.mikra, settings: settings),
        if (settings.showTranslation)
          TranslationVerse(text: list[i].english, number: list[i].hebrew.ref.verse, settings: settings),
        const Gap(10),
      ],
    ];

/// The portion's own haftarah, in a week a special one displaces it, for
/// those who read it too. Chabad's custom is to, so it opens for them;
/// otherwise it starts folded.
class _RegularHaftarah extends ConsumerWidget {
  const _RegularHaftarah({required this.ctx});

  final WeekContext ctx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final sefer = SeferColors.of(context);
    // A hairline above, open or folded, rather than lines that come and go.
    final rule = Border(top: BorderSide(color: sefer.hairline, width: sefer.hairlineWidth));
    return ExpansionTile(
      initiallyExpanded: settings.nusach == HaftarahNusach.chabad,
      expansionAnimationStyle: Motion.of(context).style,
      // In line with the text above and below it.
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      shape: rule,
      collapsedShape: rule,
      // A heading over its book headings, for screen readers moving by heading.
      title: Semantics(
        header: true,
        headingLevel: 2,
        child: Text(
          l.regularHaftarahOf(names.portion(ctx.portion, ashkenazi: settings.ashkenaziNames)),
          style: theme.textTheme.titleMedium,
        ),
      ),
      subtitle: Text(haftarahRefs(names, ctx.haftarah.regular!)),
      children: [_RegularVerses(weekId: ctx.id)],
    );
  }
}

/// The regular haftarah's text, loaded once it is opened.
class _RegularVerses extends ConsumerWidget {
  const _RegularVerses({required this.weekId});

  final String weekId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return ref.watch(regularHaftarahTextProvider(weekId)).when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(context.l10n.errorGeneric),
          data: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _verses(Names(context), settings, list),
          ),
        );
  }
}
