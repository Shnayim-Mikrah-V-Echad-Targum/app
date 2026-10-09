import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/providers.dart';
import '../../core/text/hebrew_text.dart';
import '../../data/models/scripture.dart';
import '../../data/models/verse_ref.dart';
import '../../data/text_repository.dart';
import '../../services/feedback.dart';
import '../../services/tts.dart';
import '../../ui/l10n.dart';
import '../../ui/widgets/common.dart';
import '../parsha/week_context.dart';
import '../progress/domain/progress_models.dart';
import '../settings/app_settings.dart';
import 'display_sheet.dart';
import 'notification_prompt.dart';
import 'reader_flow.dart';
import 'scripture_text.dart';

final bookTextProvider = FutureProvider.family<BookText, (TextLayer, String)>(
  (ref, args) => ref.watch(textRepositoryProvider).book(args.$1, args.$2),
);

final commentaryProvider = FutureProvider.family<CommentaryText, (CommentaryLayer, String)>(
  (ref, args) => ref.watch(textRepositoryProvider).commentary(args.$1, args.$2),
);

/// The texts the reader needs for one book, loaded together.
class ReaderTexts {
  const ReaderTexts({required this.mikra, this.onkelos, this.english, this.rashi});
  final BookText mikra;
  final BookText? onkelos;
  final BookText? english;
  final CommentaryText? rashi;
}

final readerTextsProvider = FutureProvider.family<ReaderTexts, (String, bool, bool, CommentaryLayer?)>((ref, args) async {
  final (book, onkelos, english, rashi) = args;
  final results = await Future.wait<Object?>([
    ref.watch(bookTextProvider((TextLayer.mikra, book)).future),
    if (onkelos) ref.watch(bookTextProvider((TextLayer.onkelos, book)).future) else Future.value(null),
    if (english) ref.watch(bookTextProvider((TextLayer.english, book)).future) else Future.value(null),
    if (rashi != null) ref.watch(commentaryProvider((rashi, book)).future) else Future.value(null),
  ]);
  return ReaderTexts(
    mikra: results[0]! as BookText,
    onkelos: results[1] as BookText?,
    english: results[2] as BookText?,
    rashi: results[3] as CommentaryText?,
  );
});

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.weekId, required this.aliyah, this.fullText = false});

  final String weekId;
  final int aliyah;
  final bool fullText;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late int _aliyah = widget.aliyah.clamp(0, kAliyot - 1);
  late bool _fullText = widget.fullText;
  int _chunk = 0;
  int _step = 0;
  bool _finished = false;
  bool _positioned = false;
  int? _focusedVerse;
  final _scroll = ScrollController();

  // Kept for dispose(), when ref can no longer be used.
  late final TtsService _tts;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsProvider);
    if (ref.read(settingsProvider).keepScreenOn) {
      WakelockPlus.enable().catchError((_) {});
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable().catchError((_) {});
    _tts.stop();
    _scroll.dispose();
    super.dispose();
  }

  CommentaryLayer? _rashiLayer(AppSettings s) {
    if (s.secondReading == SecondReading.rashiEnglish) return CommentaryLayer.rashiEnglish;
    if (s.usesRashi || s.showRashi) return CommentaryLayer.rashi;
    return null;
  }

  ReaderFlow _flowFor(WeekContext ctx, ReaderTexts texts, AppSettings s) {
    final repo = ref.read(parshaRepositoryProvider);
    final verses = repo.aliyahVerses(ctx.portion, _aliyah);
    return ReaderFlow(
      book: ctx.portion.book,
      verses: verses,
      method: s.method,
      second: s.secondReading,
      hasRashi: [for (final v in verses) texts.rashi?.on(v).isNotEmpty ?? false],
      breaks: texts.mikra.breaks,
      thirdReadingPrompts: s.thirdReadingPrompts,
      repeatLastVerse: s.repeatLastVerse && _aliyah == kAliyot - 1,
    );
  }

  void _goToAliyah(int a) {
    ref.read(ttsProvider).stop();
    setState(() {
      _aliyah = a;
      _positioned = false;
      _finished = false;
      _focusedVerse = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  // --- Recording progress ---------------------------------------------------

  void _record(WeekContext ctx, ReaderFlow flow, int chunk, int step) {
    if (!ctx.isOpen) return; // Preview of a future portion: no credit yet.
    final progress = ref.read(progressProvider.notifier);
    final current = ref.read(progressProvider).week(ctx.id);
    final positions = flow.positionsAfter(chunk, step, current.positions[_aliyah] ?? const [0, 0, 0]);
    progress.savePosition(ctx.id, _aliyah, positions);
    final today = ref.read(todayProvider);
    for (final pass in ReadingPass.values) {
      if (positions[pass.index] >= flow.verses.length && !current.isUnitDone(_aliyah, pass)) {
        progress.markUnit(ctx.id, _aliyah, pass, today);
      }
    }
  }

  void _next(WeekContext ctx, ReaderFlow flow) {
    if (_finished) return;
    ref.read(ttsProvider).stop();
    final steps = flow.stepsFor(_chunk);
    final hadCompletedBefore = ref.read(progressProvider).weeks.values.any((w) => w.completedAliyot > 0);
    _record(ctx, flow, _chunk, _step);
    hapticTap(ref);
    setState(() {
      if (_step + 1 < steps.length) {
        _step++;
      } else if (_chunk + 1 < flow.chunks.length) {
        _chunk++;
        _step = 0;
      } else {
        _finished = true;
      }
    });
    if (_finished) {
      _onFinished(ctx, firstEver: !hadCompletedBefore);
    } else {
      _announceStep(flow);
    }
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _back(ReaderFlow flow) {
    ref.read(ttsProvider).stop();
    setState(() {
      if (_finished) {
        _finished = false;
      } else if (_step > 0) {
        _step--;
      } else if (_chunk > 0) {
        _chunk--;
        _step = flow.stepsFor(_chunk).length - 1;
      }
    });
    _announceStep(flow);
  }

  void _announceStep(ReaderFlow flow) {
    if (!mounted) return;
    final l = context.l10n;
    final kind = flow.stepsFor(_chunk)[_step];
    final c = flow.chunks[_chunk];
    final where = flow.method == ReadingMethod.verseByVerse
        ? l.verseOf(c.start + 1, flow.verses.length)
        : l.sectionOf(_chunk + 1, flow.chunks.length);
    final message = '${_stepTitle(kind)}. $where';
    if (MediaQuery.supportsAnnounceOf(context)) {
      SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
    }
  }

  Future<void> _onFinished(WeekContext ctx, {required bool firstEver}) async {
    final l = context.l10n;
    final names = Names(context);
    hapticSuccess(ref);
    final week = ref.read(progressProvider).week(ctx.id);
    final settings = ref.read(settingsProvider);
    final parshaName = names.portion(ctx.portion, ashkenazi: settings.ashkenaziNames);
    final message = week.isComplete ? l.parshaComplete(parshaName) : l.aliyahComplete(names.aliyah(_aliyah));
    if (MediaQuery.supportsAnnounceOf(context)) {
      SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
    }
    if (firstEver && ctx.isOpen && !settings.notificationPromptShown) {
      final verses = ref.read(parshaRepositoryProvider).aliyahVerseCount(ctx.portion, _aliyah);
      await maybeOfferReminders(context, ref, celebration: l.firstAliyahDone(l.versesCount(verses)));
    }
  }

  String _stepTitle(StepKind kind) {
    final l = context.l10n;
    return switch (kind) {
      StepKind.mikra1 => l.stepMikra1,
      StepKind.mikra2 => l.stepMikra2,
      StepKind.targum => l.stepTargum,
      StepKind.rashi => l.stepRashi,
      StepKind.thirdHebrew => l.stepThirdHebrew,
      StepKind.repeatLast => l.stepRepeatLast,
    };
  }

  // --- Speech -----------------------------------------------------------------

  Future<void> _toggleSpeech(ReaderTexts texts, ReaderFlow flow) async {
    final tts = ref.read(ttsProvider);
    if (tts.speaking.value) {
      await tts.stop();
      return;
    }
    final s = ref.read(settingsProvider);
    final l = context.l10n;
    final hasHebrew = await tts.hasHebrewVoice();
    if (!mounted) return;
    final english = _currentKind(flow) == StepKind.rashi && s.secondReading == SecondReading.rashiEnglish;
    if (hasHebrew == false && !english) showStatus(context, l.ttsNoHebrewVoice);
    final text = _speechText(texts, flow, s);
    try {
      await tts.speak(text, language: english ? 'en-US' : 'he-IL', rate: s.speechRate);
    } catch (_) {
      if (mounted) showStatus(context, l.ttsUnavailable);
    }
  }

  StepKind _currentKind(ReaderFlow flow) => _fullText || _finished ? StepKind.mikra1 : flow.stepsFor(_chunk)[_step];

  String _speechText(ReaderTexts texts, ReaderFlow flow, AppSettings s) {
    final refs = _fullText || _finished
        ? flow.verses
        : flow.verses.sublist(flow.chunks[_chunk].start, flow.chunks[_chunk].end);
    final kind = _currentKind(flow);
    String hebrew(Verse v) => HebrewSpeech.spoken(v.readText, divineName: s.divineName);
    return switch (kind) {
      StepKind.targum => refs.map((r) => hebrew(texts.onkelos!.verse(r))).join(' '),
      StepKind.rashi => refs
          .expand((r) => texts.rashi!.on(r))
          .map((c) => s.secondReading == SecondReading.rashiEnglish
              ? '${c.heading ?? ''} ${c.text}'
              : HebrewSpeech.spoken('${c.heading ?? ''} ${c.text}', divineName: s.divineName))
          .join(' '),
      StepKind.repeatLast => hebrew(texts.mikra.verse(flow.verses.last)),
      _ => refs.map((r) => hebrew(texts.mikra.verse(r))).join(' '),
    };
  }

  // --- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ctx = ref.watch(weekContextProvider(widget.weekId));
    if (ctx == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(l.errorGeneric)));
    }
    final s = ref.watch(settingsProvider);
    final names = Names(context);
    final textsAsync = ref.watch(readerTextsProvider((
      ctx.portion.book,
      s.usesOnkelos,
      s.showTranslation,
      _rashiLayer(s),
    )));

    final title = '${names.portion(ctx.portion, ashkenazi: s.ashkenaziNames)} · ${names.aliyah(_aliyah)}';

    return textsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Semantics(label: l.loading, child: const CircularProgressIndicator())),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.errorGeneric),
              const Gap(12),
              FilledButton(
                onPressed: () => ref.invalidate(readerTextsProvider),
                child: Text(l.actionRetry),
              ),
            ],
          ),
        ),
      ),
      data: (texts) {
        final flow = _flowFor(ctx, texts, s);
        if (!_positioned) {
          final saved = ctx.progress.isAliyahDone(_aliyah) ? null : ctx.progress.positions[_aliyah];
          final (c, st) = flow.resumeFrom(saved);
          _chunk = c.clamp(0, flow.chunks.length - 1);
          _step = st.clamp(0, flow.stepsFor(_chunk).length - 1);
          _positioned = true;
        }
        // Settings changes can reshape the flow; keep indices in range.
        if (_chunk >= flow.chunks.length) _chunk = flow.chunks.length - 1;
        if (_step >= flow.stepsFor(_chunk).length) _step = flow.stepsFor(_chunk).length - 1;
        return _buildReader(context, ctx, texts, flow, s, title);
      },
    );
  }

  Widget _buildReader(BuildContext context, WeekContext ctx, ReaderTexts texts, ReaderFlow flow, AppSettings s, String title) {
    final l = context.l10n;
    final isMac = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
    final tts = ref.watch(ttsProvider);
    void toggle(AppSettings Function(AppSettings) f) => ref.read(settingsProvider.notifier).update(f);
    void next() {
      if (!_fullText) _next(ctx, flow);
    }

    void back() {
      if (!_fullText) _back(flow);
    }

    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.pageDown): () => next(),
      const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): () => next(),
      const SingleActivator(LogicalKeyboardKey.pageUp): () => back(),
      const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): () => back(),
      SingleActivator(LogicalKeyboardKey.equal, control: !isMac, meta: isMac): () => changeReadingScale(ref, 0.1),
      SingleActivator(LogicalKeyboardKey.minus, control: !isMac, meta: isMac): () => changeReadingScale(ref, -0.1),
      SingleActivator(LogicalKeyboardKey.keyT, control: !isMac, meta: isMac, shift: true): () =>
          toggle((s) => s.copyWith(showTeamim: !s.showTeamim)),
      SingleActivator(LogicalKeyboardKey.keyN, control: !isMac, meta: isMac, shift: true): () =>
          toggle((s) => s.copyWith(showNikud: !s.showNikud)),
      SingleActivator(LogicalKeyboardKey.keyL, control: !isMac, meta: isMac, shift: true): () => _toggleSpeech(texts, flow),
      const SingleActivator(LogicalKeyboardKey.f1): () => _showShortcuts(context, isMac),
      SingleActivator(LogicalKeyboardKey.slash, control: !isMac, meta: isMac): () => _showShortcuts(context, isMac),
    };

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(title, overflow: TextOverflow.ellipsis),
            actions: [
              ValueListenableBuilder<bool>(
                valueListenable: tts.speaking,
                builder: (context, speaking, _) => IconButton(
                  tooltip: speaking ? l.stopListening : l.listen,
                  icon: Icon(speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
                  onPressed: () => _toggleSpeech(texts, flow),
                ),
              ),
              IconButton(
                tooltip: l.displaySettings,
                icon: const Icon(Icons.text_format),
                onPressed: () => showDisplaySheet(context),
              ),
              PopupMenuButton<String>(
                tooltip: l.actionMore,
                onSelected: (v) {
                  switch (v) {
                    case 'mode':
                      setState(() => _fullText = !_fullText);
                    case 'mark':
                      _markAliyahRead(ctx);
                    case 'week':
                      context.push('/week/${ctx.id}');
                    case 'keys':
                      _showShortcuts(context, isMac);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'mode', child: Text(_fullText ? l.guidedMode : l.fullTextMode)),
                  if (ctx.isOpen && !ctx.progress.isAliyahDone(_aliyah))
                    PopupMenuItem(value: 'mark', child: Text(l.markAliyahRead)),
                  PopupMenuItem(value: 'week', child: Text(l.backToWeek)),
                  PopupMenuItem(value: 'keys', child: Text(l.keyboardShortcuts)),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                _AliyahSelector(
                  ctx: ctx,
                  selected: _aliyah,
                  onSelected: _goToAliyah,
                ),
                if (!ctx.isOpen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: NoticeBanner(
                      icon: Icons.visibility_outlined,
                      text: l.previewNotOpen(Names(context).dateLong(ctx.week.start)),
                    ),
                  ),
                Expanded(
                  child: _fullText
                      ? _FullText(
                          flow: flow,
                          texts: texts,
                          settings: s,
                          scroll: _scroll,
                          focusedVerse: _focusedVerse,
                          onVerseTap: (i) => setState(() => _focusedVerse = _focusedVerse == i ? null : i),
                          footer: ctx.isOpen && !ctx.progress.isAliyahDone(_aliyah)
                              ? FilledButton.icon(
                                  icon: const Icon(Icons.check),
                                  label: Text(l.markAliyahRead),
                                  onPressed: () => _markAliyahRead(ctx),
                                )
                              : null,
                        )
                      : _finished
                          ? _FinishedPanel(
                              ctx: ctx,
                              aliyah: _aliyah,
                              onNext: _aliyah < kAliyot - 1 ? () => _goToAliyah(_aliyah + 1) : null,
                            )
                          : _GuidedStep(
                              flow: flow,
                              texts: texts,
                              settings: s,
                              chunk: _chunk,
                              step: _step,
                              scroll: _scroll,
                              stepTitle: _stepTitle(flow.stepsFor(_chunk)[_step]),
                            ),
                ),
                if (!_fullText && !_finished)
                  _BottomBar(
                    flow: flow,
                    chunk: _chunk,
                    step: _step,
                    onBack: _chunk == 0 && _step == 0 ? null : () => _back(flow),
                    onNext: () => _next(ctx, flow),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _markAliyahRead(WeekContext ctx) {
    final today = ref.read(todayProvider);
    ref.read(progressProvider.notifier).markAliyah(ctx.id, _aliyah, today);
    ref.read(progressProvider.notifier).savePosition(ctx.id, _aliyah, const [9999, 9999, 9999]);
    hapticSuccess(ref);
    showStatus(context, context.l10n.markedRead);
    setState(() => _finished = true);
  }

  void _showShortcuts(BuildContext context, bool isMac) {
    final l = context.l10n;
    final mod = isMac ? '⌘' : 'Ctrl';
    final rows = [
      ('Page Down · Alt+↓', l.shortcutNext),
      ('Page Up · Alt+↑', l.shortcutBack),
      ('$mod + =', l.shortcutLarger),
      ('$mod + −', l.shortcutSmaller),
      ('$mod + Shift + T', l.shortcutTeamim),
      ('$mod + Shift + N', l.shortcutNikud),
      ('$mod + Shift + L', l.shortcutListen),
      ('F1 · $mod + /', l.shortcutHelp),
    ];
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.keyboardShortcuts),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (keys, action) in rows)
                ListTile(
                  dense: true,
                  title: Text(action),
                  trailing: Directionality(textDirection: TextDirection.ltr, child: Text(keys)),
                ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionClose))],
      ),
    );
  }
}

/// Chips to switch between the seven aliyot.
class _AliyahSelector extends StatelessWidget {
  const _AliyahSelector({required this.ctx, required this.selected, required this.onSelected});

  final WeekContext ctx;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final names = Names(context);
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (var a = 0; a < kAliyot; a++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                avatar: ctx.progress.isAliyahDone(a) ? const Icon(Icons.check, size: 18) : null,
                label: Text(names.aliyah(a)),
                selected: selected == a,
                onSelected: (_) => onSelected(a),
              ),
            ),
        ],
      ),
    );
  }
}

/// The current step of guided reading: one verse, section or aliyah, in the
/// layer to be read now.
class _GuidedStep extends StatelessWidget {
  const _GuidedStep({
    required this.flow,
    required this.texts,
    required this.settings,
    required this.chunk,
    required this.step,
    required this.scroll,
    required this.stepTitle,
  });

  final ReaderFlow flow;
  final ReaderTexts texts;
  final AppSettings settings;
  final int chunk;
  final int step;
  final ScrollController scroll;
  final String stepTitle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final steps = flow.stepsFor(chunk);
    final kind = steps[step];
    final c = flow.chunks[chunk];
    final refs = kind == StepKind.repeatLast ? [flow.verses.last] : flow.verses.sublist(c.start, c.end);
    final styles = ScriptureStyles(context, settings);
    final englishRashi = settings.secondReading == SecondReading.rashiEnglish;

    Widget layerFor(VerseRef r) {
      switch (kind) {
        case StepKind.mikra1:
        case StepKind.mikra2:
        case StepKind.thirdHebrew:
        case StepKind.repeatLast:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScriptureVerse(verse: texts.mikra.verse(r), kind: ScriptureKind.mikra, settings: settings),
              if (settings.showTranslation && texts.english != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: TranslationVerse(text: texts.english!.verse(r).readText, number: r.verse, settings: settings),
                ),
              if (kind == StepKind.thirdHebrew)
                _Note(text: settings.usesOnkelos ? l.noTargumNote : l.noRashiNote),
            ],
          );
        case StepKind.targum:
          return ScriptureVerse(verse: texts.onkelos!.verse(r), kind: ScriptureKind.targum, settings: settings);
        case StepKind.rashi:
          final comments = texts.rashi?.on(r) ?? const [];
          if (comments.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScriptureVerse(verse: texts.mikra.verse(r), kind: ScriptureKind.mikra, settings: settings),
                _Note(text: l.noRashiNote),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScriptureVerse(
                verse: texts.mikra.verse(r),
                kind: ScriptureKind.mikra,
                settings: settings,
                secondary: true,
              ),
              RashiComments(comments: comments, settings: settings, english: englishRashi),
            ],
          );
      }
    }

    final layerName = switch (kind) {
      StepKind.targum => l.targumLabel,
      StepKind.rashi => l.rashiLabel,
      _ => l.mikraLabel,
    };

    return Scrollbar(
      controller: scroll,
      child: SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: styles.maxLineWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepHeader(
                  title: stepTitle,
                  stepNumber: step + 1,
                  totalSteps: steps.length,
                  kind: kind,
                ),
                const Gap(8),
                LayerLabel(layerName, icon: kind == StepKind.targum || kind == StepKind.rashi ? Icons.translate : Icons.menu_book),
                for (final r in refs) ...[
                  if (r.verse == 1 || r == refs.first)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Text(
                        l.chapterLabel(context.isHebrewUi ? HebrewText.gematria(r.chapter, punctuate: false) : '${r.chapter}'),
                        style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  layerFor(r),
                  if (settings.showRashi && kind != StepKind.rashi && texts.rashi != null && texts.rashi!.on(r).isNotEmpty) ...[
                    LayerLabel(l.rashiLabel),
                    RashiComments(comments: texts.rashi!.on(r), settings: settings, english: englishRashi),
                  ],
                  const Gap(8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, required this.stepNumber, required this.totalSteps, required this.kind});

  final String title;
  final int stepNumber;
  final int totalSteps;
  final StepKind kind;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 1; i <= totalSteps; i++)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: Icon(
                        i < stepNumber ? Icons.check_circle : (i == stepNumber ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                        size: 18,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                ],
              ),
            ),
            const Gap(8),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        )),
                    Text(l.stepOf(stepNumber, totalSteps),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: scheme.onSecondaryContainer, size: 20),
          const Gap(8),
          Expanded(child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer))),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.flow, required this.chunk, required this.step, required this.onBack, required this.onNext});

  final ReaderFlow flow;
  final int chunk;
  final int step;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = flow.chunks[chunk];
    final position = flow.method == ReadingMethod.verseByVerse
        ? l.verseOf(c.start + 1, flow.verses.length)
        : l.sectionOf(chunk + 1, flow.chunks.length);
    // Progress through the whole aliyah, for the visual bar.
    var done = 0;
    for (var i = 0; i < chunk; i++) {
      done += flow.stepsFor(i).length;
    }
    done += step;
    final fraction = done / flow.totalSteps;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: position,
              value: '${(fraction * 100).round()}%',
              child: LinearProgressIndicator(value: fraction, minHeight: 6, borderRadius: BorderRadius.circular(3)),
            ),
            const Gap(8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const BackButtonIcon(),
                  label: Text(l.actionBack),
                ),
                Expanded(
                  child: Text(
                    position,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.check),
                  label: Text(l.actionNext),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishedPanel extends ConsumerWidget {
  const _FinishedPanel({required this.ctx, required this.aliyah, required this.onNext});

  final WeekContext ctx;
  final int aliyah;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final week = ref.watch(progressProvider).week(ctx.id);
    final complete = week.isComplete;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(complete ? Icons.celebration : Icons.check_circle, size: 72, color: theme.colorScheme.primary),
              const Gap(16),
              Semantics(
                header: true,
                headingLevel: 1,
                child: Text(
                  complete
                      ? l.parshaComplete(names.portion(ctx.portion, ashkenazi: settings.ashkenaziNames))
                      : l.aliyahComplete(names.aliyah(aliyah)),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const Gap(24),
              if (onNext != null && !complete)
                FilledButton.icon(onPressed: onNext, icon: const Icon(Icons.arrow_forward), label: Text(l.nextAliyah)),
              if (complete && settings.haftarahEnabled && week.haftarah == null)
                FilledButton.icon(
                  onPressed: () => context.pushReplacement('/haftarah/${ctx.id}'),
                  icon: const Icon(Icons.auto_stories),
                  label: Text(l.haftarahTitle),
                ),
              const Gap(8),
              OutlinedButton(
                onPressed: () => context.canPop() ? context.pop() : context.go('/today'),
                child: Text(l.actionDone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The whole aliyah, verse by verse with each layer interleaved.
class _FullText extends StatelessWidget {
  const _FullText({
    required this.flow,
    required this.texts,
    required this.settings,
    required this.scroll,
    required this.focusedVerse,
    required this.onVerseTap,
    this.footer,
  });

  final ReaderFlow flow;
  final ReaderTexts texts;
  final AppSettings settings;
  final ScrollController scroll;
  final int? focusedVerse;
  final ValueChanged<int> onVerseTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final styles = ScriptureStyles(context, settings);
    final englishRashi = settings.secondReading == SecondReading.rashiEnglish;
    return Scrollbar(
      controller: scroll,
      child: ListView.builder(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: flow.verses.length + 1,
        itemBuilder: (context, i) {
          if (i == flow.verses.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(child: footer ?? const SizedBox.shrink()),
            );
          }
          final r = flow.verses[i];
          final dimmed = settings.focusMode && focusedVerse != null && focusedVerse != i;
          final highlighted = settings.focusMode && focusedVerse == i;
          final brk = texts.mikra.breaks[r];
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: styles.maxLineWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (r.verse == 1 || i == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Semantics(
                        header: true,
                        headingLevel: 3,
                        child: Text(
                          l.chapterLabel(context.isHebrewUi ? HebrewText.gematria(r.chapter, punctuate: false) : '${r.chapter}'),
                          style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ),
                    ),
                  InkWell(
                    onTap: settings.focusMode ? () => onVerseTap(i) : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ScriptureVerse(
                          verse: texts.mikra.verse(r),
                          kind: ScriptureKind.mikra,
                          settings: settings,
                          dimmed: dimmed,
                          highlighted: highlighted,
                        ),
                        if (texts.onkelos != null)
                          ScriptureVerse(
                            verse: texts.onkelos!.verse(r),
                            kind: ScriptureKind.targum,
                            settings: settings,
                            dimmed: dimmed,
                            secondary: true,
                          ),
                        if (settings.showTranslation && texts.english != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: TranslationVerse(
                              text: texts.english!.verse(r).readText,
                              number: r.verse,
                              settings: settings,
                              dimmed: dimmed,
                            ),
                          ),
                        if ((settings.showRashi || settings.usesRashi) && texts.rashi != null && texts.rashi!.on(r).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: RashiComments(comments: texts.rashi!.on(r), settings: settings, english: englishRashi),
                          ),
                      ],
                    ),
                  ),
                  if (brk != null)
                    ExcludeSemantics(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: brk == SectionBreak.open ? 16 : 8),
                        child: Text(
                          brk == SectionBreak.open ? 'פ' : 'ס',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ),
                    )
                  else
                    const Gap(10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
