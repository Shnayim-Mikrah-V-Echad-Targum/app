import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/calendar/local_date.dart';
import '../../core/text/hebrew_text.dart';
import '../../data/models/parsha.dart';
import '../../data/models/verse_ref.dart';
import '../../data/text_repository.dart';
import '../../services/feedback.dart';
import '../../services/tts.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fallbacks.dart';
import '../../ui/widgets/ornaments.dart';
import '../parsha/week_context.dart';
import '../settings/app_settings.dart';
import 'display_sheet.dart';
import 'listen_along.dart';
import 'listen_bar.dart';
import 'scripture_text.dart';
import 'verse_actions_sheet.dart';

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

/// The week's haftarah, read once, set as the reader sets the full text
/// (DESIGN_SYSTEM.md §9): its reference at the head of the page, the verses
/// with a chapter's head where a chapter begins, and at the end a divider
/// and the button that marks it read. In a week a special haftarah displaces
/// the portion's own, the regular one follows it, folded but for Chabad.
///
/// Listen reads its verses one by one, from the first in view, highlighting
/// each as it is read, with the player at the foot of the page.
class HaftarahScreen extends ConsumerStatefulWidget {
  const HaftarahScreen({super.key, required this.weekId});

  final String weekId;

  @override
  ConsumerState<HaftarahScreen> createState() => _HaftarahScreenState();
}

class _HaftarahScreenState extends ConsumerState<HaftarahScreen> {
  // Kept for dispose(), when ref can no longer be used.
  late final TtsService _tts;
  late final ListenController _listen;

  // One per verse of the haftarah, for the first in view, where Listen
  // starts.
  final _verseKeys = <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsProvider);
    _listen = ListenController(_tts)..addListener(_listenChanged);
  }

  @override
  void dispose() {
    _listen
      ..removeListener(_listenChanged)
      ..dispose();
    // The voice goes with the page, as the reader's does.
    _tts.stop();
    super.dispose();
  }

  void _listenChanged() {
    if (mounted) setState(() {});
  }

  GlobalKey _verseKey(int i) {
    while (_verseKeys.length <= i) {
      _verseKeys.add(GlobalKey());
    }
    return _verseKeys[i];
  }

  /// The first of the haftarah's [count] verses whose top is in view; the
  /// first verse, if the page is scrolled past them all.
  int _firstVerseInView(int count) {
    for (var i = 0; i < count && i < _verseKeys.length; i++) {
      final at = _verseKeys[i].currentContext;
      final box = at?.findRenderObject();
      if (at == null || box is! RenderBox) continue;
      final viewport = RenderAbstractViewport.maybeOf(box);
      final position = Scrollable.maybeOf(at)?.position;
      if (viewport == null || position == null) return 0;
      if (viewport.getOffsetToReveal(box, 0).offset >= position.pixels - 1) return i;
    }
    return 0;
  }

  /// Reads the haftarah's verses aloud, from the first in view, the Divine
  /// Name as the reader has chosen.
  Future<void> _startListening(List<HaftarahVerse> list) async {
    final l = context.l10n;
    final hasHebrew = await _tts.hasHebrewVoice();
    if (!mounted) return;
    if (hasHebrew == false) showStatus(context, l.ttsNoHebrewVoice);
    final settings = ref.read(settingsProvider);
    final queue = SpeechQueue(language: 'he-IL');
    for (final (i, v) in list.indexed) {
      queue.add(i, HebrewSpeech.spoken(v.hebrew.readText, divineName: settings.divineName));
    }
    if (queue.isEmpty) return;
    final end = await _listen.play(queue, rate: settings.speechRate, startVerse: _firstVerseInView(list.length));
    if (!mounted) return;
    switch (end) {
      case ListenEnd.failed:
        showStatus(context, l.ttsUnavailable);
      case ListenEnd.finished:
        _listen.end();
      case ListenEnd.stopped:
        break;
    }
  }

  void _setSpeechRate(double rate) {
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(speechRate: rate));
    _listen.setRate(rate);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final weekId = widget.weekId;
    final ctx = ref.watch(weekContextProvider(weekId));
    final settings = ref.watch(settingsProvider);
    final verses = ref.watch(haftarahTextProvider(weekId));
    // A link to a week that doesn't exist.
    if (ctx == null) return const NotFoundPage();
    final styles = ScriptureStyles(context, settings);
    final parsha = names.portion(ctx.portion, ashkenazi: settings.ashkenaziNames);
    // The text keeps the reader's measure, between the page's gutters.
    final width = styles.maxLineWidth + 2 * Gutter.of(context);
    final listening = _listen.active;

    return PageScaffold(
      leading: homeLeading(context),
      // The page names itself at its head, under the eyebrow.
      titleText: '${l.haftarahTitle} · $parsha',
      showTitle: false,
      contentMaxWidth: width,
      actions: [
        IconButton(
          tooltip: listening ? l.stopListening : l.listen,
          icon: Icon(listening ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
          onPressed: () => listening ? _listen.stop() : _startListening(verses.value ?? const []),
        ),
        IconButton(
          tooltip: l.displaySettings,
          icon: const Icon(Icons.text_format),
          onPressed: () => showDisplaySheet(context),
        ),
      ],
      // A verse's options open from the keyboard too, as well as from a long
      // press or a secondary click on it.
      body: VerseOptionsKeys(
        child: verses.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l.errorGeneric)),
          data: (list) => PageBody(
            maxWidth: width,
            children: [
              Eyebrow('${l.haftarahTitle} · $parsha'),
              const Gap(Space.xs),
              Semantics(
                header: true,
                headingLevel: 1,
                child: Text(haftarahRefs(names, ctx.haftarah.parts), style: theme.textTheme.headlineSmall),
              ),
              if (ctx.haftarah.specialKey case final key?) ...[
                const Gap(Space.xs),
                Text(names.specialHaftarah(key), style: SeferType.of(context).marginalia),
              ],
              // Chabad's own reading isn't listed for this week yet.
              if (ctx.haftarah.fallback) ...[
                const Gap(Space.lg),
                NoticeBanner(icon: Icons.info_outline, text: l.chabadFallbackNote),
              ],
              const Gap(Space.xxl),
              ..._verses(context, settings, list, keyOf: _verseKey, speaking: _listen.verse),
              if (ctx.haftarah.regular != null) ...[
                const Gap(Space.xxl),
                _RegularHaftarah(ctx: ctx),
              ],
              // The haftarah's end, as a book ends a section.
              const Gap(Space.xxl),
              const SeferDivider(),
              if (ctx.isOpen) ...[
                const Gap(Space.xl),
                _MarkRead(ctx: ctx),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: listening
          ? ListenBar(
              paused: _listen.paused,
              onPlayPause: _listen.paused ? _listen.resume : _listen.pause,
              onPrevious: _listen.hasPrevious ? _listen.previous : null,
              onNext: _listen.hasNext ? _listen.next : null,
              rate: settings.speechRate,
              onRate: _setSpeechRate,
              onStop: _listen.stop,
              maxWidth: styles.maxLineWidth,
            )
          : null,
    );
  }
}

/// A haftarah's verses, as the reader's full text sets them: 20 apart, with
/// a chapter's head where the chapter changes from one verse to the next.
/// Drawn from more than one book, each book's verses are headed by its name.
/// Its heads are headings of [level]: 2 beneath the page's heading, or 3
/// beneath the regular haftarah's own. A long press on a verse opens its
/// options, with its translation where that is shown. Each verse takes the
/// key [keyOf] gives it, and verse [speaking], which Listen reads, is
/// highlighted with its translation.
List<Widget> _verses(
  BuildContext context,
  AppSettings settings,
  List<HaftarahVerse> list, {
  int level = 2,
  GlobalKey Function(int)? keyOf,
  int? speaking,
}) {
  final names = Names(context);
  final books = {for (final v in list) v.book};
  void options(HaftarahVerse v) => showVerseActions(
        context,
        ChosenVerse(
          at: BookVerse(v.book, v.hebrew.ref),
          hebrew: v.hebrew,
          english: settings.showTranslation ? v.english : null,
        ),
      );
  return [
    for (var i = 0; i < list.length; i++) ...[
      if (i > 0) const Gap(_verseGap),
      if (books.length > 1 && (i == 0 || list[i].book != list[i - 1].book))
        ChapterHeading.book(
          hebrewName: list[i].bookHe,
          name: names.book(list[i].book),
          settings: settings,
          headingLevel: level,
        )
      else if (i > 0 && list[i].hebrew.ref.chapter != list[i - 1].hebrew.ref.chapter)
        ChapterHeading(chapter: list[i].hebrew.ref.chapter, settings: settings, headingLevel: level),
      SpeakingVerseMark(
        key: keyOf?.call(i),
        active: speaking == i,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScriptureVerse(
              verse: list[i].hebrew,
              kind: ScriptureKind.mikra,
              settings: settings,
              onLongPress: () => options(list[i]),
            ),
            if (settings.showTranslation) ...[
              const Gap(6),
              TranslationVerse(text: list[i].english, number: list[i].hebrew.ref.verse, settings: settings),
            ],
          ],
        ),
      ),
    ],
  ];
}

/// Between one verse and the next.
const _verseGap = 20.0;

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
      // A heading over its chapters' heads, for screen readers moving by
      // heading.
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
            padding: EdgeInsets.all(Space.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(context.l10n.errorGeneric),
          data: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Gap(Space.md),
              ..._verses(context, settings, list, level: 3),
            ],
          ),
        );
  }
}

/// The end of the haftarah: a button that marks it read or, once it is,
/// the day it was read and a way to say it wasn't, which can be undone. The
/// focus stays with the one shown, as one replaces the other.
class _MarkRead extends ConsumerStatefulWidget {
  const _MarkRead({required this.ctx});

  final WeekContext ctx;

  @override
  ConsumerState<_MarkRead> createState() => _MarkReadState();
}

class _MarkReadState extends ConsumerState<_MarkRead> {
  final _markFocus = FocusNode();
  final _unmarkFocus = FocusNode();

  @override
  void dispose() {
    _markFocus.dispose();
    _unmarkFocus.dispose();
    super.dispose();
  }

  /// Records the haftarah as read on [day] (or not read), and moves the
  /// focus from [from] to [to], which takes its place, if [from] had it.
  void _set(LocalDate? day, {required FocusNode from, required FocusNode to}) {
    final hadFocus = from.hasFocus;
    ref.read(progressProvider.notifier).markHaftarah(widget.ctx.id, day);
    if (hadFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && to.context != null) to.requestFocus();
      });
    }
  }

  void _mark() {
    _set(ref.read(todayProvider), from: _markFocus, to: _unmarkFocus);
    hapticSuccess(ref);
    showStatus(context, context.l10n.markedRead);
  }

  void _unmark(LocalDate was) {
    final l = context.l10n;
    final weekId = widget.ctx.id;
    final progress = ref.read(progressProvider.notifier);
    _set(null, from: _unmarkFocus, to: _markFocus);
    showStatus(
      context,
      l.markedUnread,
      action: SnackBarAction(label: l.actionUndo, onPressed: () => progress.markHaftarah(weekId, was)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final read = widget.ctx.progress.haftarah;
    final Widget content;
    if (read == null) {
      content = FilledButton.tonalIcon(
        focusNode: _markFocus,
        style: AppButtons.tonal(context),
        onPressed: _mark,
        icon: const Icon(Icons.check),
        label: Text(l.markHaftarahRead, textAlign: TextAlign.center),
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The check rides with the first word, so the line wraps as one.
          Text.rich(
            TextSpan(children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: Space.sm),
                  child: Icon(
                    Icons.check_circle,
                    size: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3).scale(20),
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              TextSpan(text: l.haftarahReadOn(Names(context).dateLong(read))),
            ]),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
          ),
          const Gap(Space.xs),
          TextButton(focusNode: _unmarkFocus, onPressed: () => _unmark(read), child: Text(l.actionMarkUnread)),
        ],
      );
    }
    return Center(
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: content),
    );
  }
}
