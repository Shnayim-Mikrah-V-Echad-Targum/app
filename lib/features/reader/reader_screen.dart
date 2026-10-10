import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../core/text/hebrew_text.dart';
import '../../data/models/scripture.dart';
import '../../data/models/verse_ref.dart';
import '../../data/text_repository.dart';
import '../../services/feedback.dart';
import '../../services/tts.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fallbacks.dart';
import '../../ui/widgets/ornaments.dart' show Eyebrow;
import '../parsha/week_context.dart';
import '../progress/domain/progress_models.dart';
import '../settings/app_settings.dart';
import 'aliyah_ribbon.dart';
import 'display_sheet.dart';
import 'notification_prompt.dart';
import 'pass_track.dart';
import 'reader_bottom_bar.dart';
import 'reader_flow.dart';
import 'scripture_text.dart';
import 'verse_anchor.dart';

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
  const ReaderScreen({
    super.key,
    required this.weekId,
    required this.aliyah,
    this.fullText = false,
    this.fromWeek = false,
    this.targetVerse,
  });

  final String weekId;
  final int aliyah;
  final bool fullText;

  /// Opened from the week's own page, which "Back to the week" returns to.
  final bool fromWeek;

  /// A verse of the aliyah to open at, from a search result, Go to verse or
  /// a link: the full text opens scrolled to it, and marks it until the next
  /// tap.
  final VerseRef? targetVerse;

  /// Whether the display shortcuts are single keys (T, N, L, + and −), as on
  /// the web, where Chrome and Edge keep Ctrl+Shift+T, Ctrl+Shift+N and
  /// Ctrl+= for themselves. Elsewhere they are Ctrl (⌘) chords. Settable,
  /// for tests.
  static bool singleKeyPlatform = kIsWeb;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late int _aliyah = widget.aliyah.clamp(0, kAliyot - 1);
  late bool _fullText = widget.fullText || widget.targetVerse != null;
  int _chunk = 0;
  int _step = 0;
  bool _finished = false;
  bool _positioned = false;

  // Another aliyah was chosen: once the step it resumes at is known, it is
  // announced, as Next and Back announce theirs.
  bool _announceWhenPositioned = false;
  int? _focusedVerse;
  final _scroll = ScrollController();

  // Controls that take the keyboard focus when the one that had it goes:
  // Next, when Back is disabled or the finished panel closes; the panel's
  // first button, when the last step is read.
  final _nextFocus = FocusNode();
  final _backFocus = FocusNode();
  final _finishFocus = FocusNode();
  // Has the focus while any of the finished panel's buttons does.
  final _panelFocus = FocusNode(canRequestFocus: false, skipTraversal: true);
  // The reader's own, which takes the focus when the control that had it
  // goes with nothing in its place: its keys keep working, and Tab goes on
  // from the top.
  final _readerFocus = FocusNode(skipTraversal: true);

  // The verse the reader was opened at, marked until the next tap or another
  // aliyah. It is not focus mode's verse: it shows with focus mode off too.
  late VerseRef? _targetVerse = widget.targetVerse;

  // In focus mode, the verse focused for the one opened at, whose highlight
  // is held off until focus moves, so that nothing moves when the mark goes.
  int? _quietFocus;

  // One per verse of the full text, for scrolling a verse into view.
  final _verseKeys = <GlobalKey>[];

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
    for (final node in [_nextFocus, _backFocus, _finishFocus, _panelFocus, _readerFocus]) {
      node.dispose();
    }
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
    // Continued from the finished panel, the focus goes on to Next.
    if (_panelFocus.hasFocus) _focusAfterFrame(_nextFocus);
    setState(() {
      _aliyah = a;
      _positioned = false;
      _announceWhenPositioned = true;
      _finished = false;
      _focusedVerse = null;
      _quietFocus = null;
      _targetVerse = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Gives [node] the keyboard focus once the frame being built, which
  /// builds its control in place of the one that had the focus, is done.
  /// Asking autofocus would not do: the route remembers the reader's own
  /// focus.
  void _focusAfterFrame(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && node.context != null) node.requestFocus();
    });
  }

  // --- The verse opened at ---------------------------------------------------

  /// Scrolls verse [i] of the full text, the one the reader was opened at, a
  /// fifth of the way down the screen once this frame has laid it out, and
  /// then says which verse it is where the platform takes announcements.
  void _revealTarget(int i, String book, VerseRef verse) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final target = i < _verseKeys.length ? _verseKeys[i].currentContext : null;
      if (!mounted || target == null) return;
      await Scrollable.ensureVisible(
        target,
        alignment: 0.2,
        duration: Motion.of(context).d(const Duration(milliseconds: 300)),
        curve: Motion.standard,
      );
      if (!mounted || !MediaQuery.supportsAnnounceOf(context)) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        Names(context).reference(book, verse.chapter, verse.verse),
        Directionality.of(context),
      );
    });
  }

  // --- Recording progress ---------------------------------------------------

  /// The saved verse counts of each reading of this aliyah, stale ones read
  /// as 0 (see [WeekProgress.savedPositions]).
  List<int> _savedPositions(WeekProgress week, ReaderFlow flow) => week.savedPositions(_aliyah, flow.verses.length);

  void _record(WeekContext ctx, ReaderFlow flow, int chunk, int step) {
    if (!ctx.isOpen) return; // Preview of a future portion: no credit yet.
    final progress = ref.read(progressProvider.notifier);
    final current = ref.read(progressProvider).week(ctx.id);
    final positions = flow.positionsAfter(chunk, step, _savedPositions(current, flow));
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
      // Next goes with the bottom bar: the panel's first button takes over,
      // once the reminders offered after a first aliyah, which take the
      // focus while they are open, are answered.
      final offer = _offersReminders(ctx, firstEver: !hadCompletedBefore);
      if (!offer) _focusAfterFrame(_finishFocus);
      _onFinished(ctx, offerReminders: offer);
    } else {
      _announceStep(flow);
    }
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _back(ReaderFlow flow) {
    // Page Up or Alt+↑ at the first step: nothing to go back to, or to say.
    if (!_finished && _chunk == 0 && _step == 0) return;
    ref.read(ttsProvider).stop();
    final fromPanel = _finished && _panelFocus.hasFocus;
    final fromBack = _backFocus.hasFocus;
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
    // Back from the finished panel, or to the first step, where Back is
    // disabled: the control with the focus goes, and Next takes it.
    if (fromPanel || (fromBack && _chunk == 0 && _step == 0)) _focusAfterFrame(_nextFocus);
    _announceStep(flow);
    // Each step opens at its top, as Next opens it.
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Page Down and Page Up: the text scrolls by most of a screen, and once
  /// at its end, the reader goes on to the next step (or back to the one
  /// before).
  void _pageOrStep(int direction, WeekContext ctx, ReaderFlow flow) {
    if (_scroll.hasClients) {
      final p = _scroll.position;
      if ((direction > 0 ? p.extentAfter : p.extentBefore) > 1) {
        final to = (p.pixels + direction * 0.8 * p.viewportDimension).clamp(p.minScrollExtent, p.maxScrollExtent);
        final motion = Motion.of(context);
        if (motion.reduced) {
          _scroll.jumpTo(to);
        } else {
          _scroll.animateTo(to, duration: motion.d(Motion.short), curve: Motion.standard);
        }
        return;
      }
    }
    if (_fullText) return;
    if (direction > 0) {
      _next(ctx, flow);
    } else {
      _back(flow);
    }
  }

  // --- Focus mode -------------------------------------------------------------

  GlobalKey _verseKey(int i) {
    while (_verseKeys.length <= i) {
      _verseKeys.add(GlobalKey());
    }
    return _verseKeys[i];
  }

  /// ↓ and ↑ in focus mode: the next or previous verse is the one read, and
  /// comes into view at the same height on the screen. With none yet, the
  /// first in view is. Like a tap, it clears the mark of the verse opened at
  /// and gives focus mode its own highlight back.
  void _moveFocusedVerse(int direction, int count) {
    final current = _focusedVerse;
    final verse = current == null ? _firstVerseInView(count) : (current + direction).clamp(0, count - 1);
    setState(() {
      _focusedVerse = verse;
      _quietFocus = null;
      _targetVerse = null;
    });
    _revealVerse(verse, animate: true);
  }

  /// The first verse of the full text whose top is in view.
  int _firstVerseInView(int count) {
    if (!_scroll.hasClients) return 0;
    final top = _scroll.position.pixels;
    for (var i = 0; i < count && i < _verseKeys.length; i++) {
      final box = _verseKeys[i].currentContext?.findRenderObject();
      final viewport = box == null ? null : RenderAbstractViewport.maybeOf(box);
      if (box != null && viewport != null && viewport.getOffsetToReveal(box, 0).offset >= top - 1) return i;
    }
    return count - 1;
  }

  /// Scrolls verse [i] of the full text into view, nearer the top than the
  /// bottom, once this frame has laid it out.
  void _revealVerse(int i, {required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final verse = i < _verseKeys.length ? _verseKeys[i].currentContext : null;
      if (!mounted || verse == null) return;
      Scrollable.ensureVisible(
        verse,
        alignment: 0.3,
        duration: animate ? Motion.of(context).d(Motion.medium) : Duration.zero,
        curve: Motion.standard,
      );
    });
  }

  /// Announces the new step, in one message, where the platform takes
  /// announcements: what to read, which reading it is, where it is in the
  /// aliyah, and the verses it shows ("Genesis 3:22"). Elsewhere the step's
  /// instruction is a live region instead.
  void _announceStep(ReaderFlow flow) {
    if (!mounted || !MediaQuery.supportsAnnounceOf(context)) return;
    final l = context.l10n;
    final names = Names(context);
    final steps = flow.stepsFor(_chunk);
    final c = flow.chunks[_chunk];
    final where = flow.method == ReadingMethod.verseByVerse
        ? l.verseOf(c.start + 1, flow.verses.length)
        : l.sectionOf(_chunk + 1, flow.chunks.length);
    final shown = flow.stepVerses(_chunk, steps[_step]);
    final (first, last) = (shown.first, shown.last);
    final verses = first == last
        ? names.reference(flow.book, first.chapter, first.verse)
        : names.range(flow.book, first.chapter, first.verse, last.chapter, last.verse);
    final message = '${_stepTitle(steps[_step])}. ${l.stepOf(_step + 1, steps.length)}. $where. $verses';
    SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
  }

  /// Whether finishing an aliyah now offers reminders: after the first
  /// aliyah ever, of a portion open for reading, if they were never offered.
  bool _offersReminders(WeekContext ctx, {required bool firstEver}) =>
      firstEver && ctx.isOpen && !ref.read(settingsProvider).notificationPromptShown;

  Future<void> _onFinished(WeekContext ctx, {required bool offerReminders}) async {
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
    if (offerReminders) {
      final verses = ref.read(parshaRepositoryProvider).aliyahVerseCount(ctx.portion, _aliyah);
      await maybeOfferReminders(context, ref, celebration: l.firstAliyahDone(l.versesCount(verses)));
      if (mounted && _finished && !_fullText) _focusAfterFrame(_finishFocus);
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
    final (text, :english) = _speechText(texts, flow, s);
    if (hasHebrew == false && !english) showStatus(context, l.ttsNoHebrewVoice);
    try {
      await tts.speak(text, language: english ? 'en-US' : 'he-IL', rate: s.speechRate);
    } catch (_) {
      if (mounted) showStatus(context, l.ttsUnavailable);
    }
  }

  StepKind _currentKind(ReaderFlow flow) => _fullText || _finished ? StepKind.mikra1 : flow.stepsFor(_chunk)[_step];

  /// What Listen reads of the step shown, and whether it is English (Rashi
  /// in English) rather than Hebrew.
  (String, {bool english}) _speechText(ReaderTexts texts, ReaderFlow flow, AppSettings s) {
    final kind = _currentKind(flow);
    final refs = _fullText || _finished ? flow.verses : flow.stepVerses(_chunk, kind);
    String hebrew(Verse v, {bool targum = false}) =>
        HebrewSpeech.spoken(v.readText, divineName: s.divineName, targum: targum);
    switch (kind) {
      case StepKind.targum:
        // With the Hebrew of a verse read a third time among the Targum.
        final text = refs
            .expand((r) => [
                  hebrew(texts.onkelos!.verse(r), targum: true),
                  if (flow.thirdHebrewInTargum(_chunk, r)) hebrew(texts.mikra.verse(r)),
                ])
            .join(' ');
        return (text, english: false);
      case StepKind.rashi:
        final english = s.secondReading == SecondReading.rashiEnglish;
        final comments = [for (final r in refs) texts.rashi!.on(r)];
        if (english) {
          // One voice reads it all: the comments in English, or, where Rashi
          // is silent on the whole step, its verses in Hebrew.
          final text = comments.expand((c) => c).map((c) => spokenRashiEnglish(c, s, speech: true).string).join(' ');
          if (text.trim().isNotEmpty) return (text, english: true);
          return (refs.map((r) => hebrew(texts.mikra.verse(r))).join(' '), english: false);
        }
        // A verse Rashi is silent on is read in Hebrew, as the step shows it.
        final text = [
          for (final (i, r) in refs.indexed)
            if (comments[i].isEmpty)
              hebrew(texts.mikra.verse(r))
            else
              for (final c in comments[i])
                HebrewSpeech.spoken('${c.heading ?? ''} ${c.text}', divineName: s.divineName, rashi: true),
        ].join(' ');
        return (text, english: false);
      case StepKind.mikra1 || StepKind.mikra2 || StepKind.thirdHebrew || StepKind.repeatLast:
        return (refs.map((r) => hebrew(texts.mikra.verse(r))).join(' '), english: false);
    }
  }

  // --- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ctx = ref.watch(weekContextProvider(widget.weekId));
    // A link to a week that doesn't exist.
    if (ctx == null) return const NotFoundPage();
    final s = ref.watch(settingsProvider);
    final names = Names(context);
    final textsAsync = ref.watch(readerTextsProvider((
      ctx.portion.book,
      s.usesOnkelos,
      s.showTranslation,
      _rashiLayer(s),
    )));

    final title = '${names.portion(ctx.portion, ashkenazi: s.ashkenaziNames)} · ${names.aliyah(_aliyah)}';

    // An app bar of its own, but the tab named as every page names it.
    return DocumentTitle(
      title: title,
      child: textsAsync.when(
        loading: () => Scaffold(
          appBar: _appBar(context, ctx, s),
          body: Center(child: Semantics(label: l.loading, child: const CircularProgressIndicator())),
        ),
        error: (e, _) => Scaffold(
          appBar: _appBar(context, ctx, s),
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
            final saved = ctx.progress.isAliyahDone(_aliyah) ? null : _savedPositions(ctx.progress, flow);
            final (c, st) = flow.resumeFrom(saved);
            _chunk = c.clamp(0, flow.chunks.length - 1);
            _step = st.clamp(0, flow.stepsFor(_chunk).length - 1);
            _positioned = true;
            if (_announceWhenPositioned && !_fullText) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _announceStep(flow));
            }
            _announceWhenPositioned = false;
            if (_targetVerse case final target?) {
              final i = flow.verses.indexOf(target);
              if (i < 0) {
                // Not in this aliyah (an old link, say): it opens as usual.
                _targetVerse = null;
              } else {
                // Focus mode reads around it, rather than around nothing.
                if (s.focusMode) _focusedVerse = _quietFocus = i;
                _revealTarget(i, flow.book, target);
              }
            }
            // Focus mode opens on the reader's place, the first verse of the
            // step the guided reader resumes at, as switching to the full text
            // does: not on nothing. The verse opened at is revealed instead.
            if (s.focusMode && _focusedVerse == null) {
              final verse = flow.chunks[_chunk].start;
              _focusedVerse = verse;
              if (_fullText && _targetVerse == null) _revealVerse(verse, animate: false);
            }
          }
          // Settings changes can reshape the flow; keep indices in range.
          if (_chunk >= flow.chunks.length) _chunk = flow.chunks.length - 1;
          if (_step >= flow.stepsFor(_chunk).length) _step = flow.stepsFor(_chunk).length - 1;
          return _buildReader(context, ctx, texts, flow, s);
        },
      ),
    );
  }

  /// The side padding of the reading column.
  static const _columnPadding = 20.0;

  /// The reader's app bar (DESIGN_SYSTEM.md §6.2), in two lines: the parsha
  /// as an eyebrow over the aliyah, which the English UI names in Hebrew too
  /// ("Revi'i · רביעי"). Its title starts where the text does, and its
  /// actions end where the text does, however wide the window. Screen
  /// readers hear the title as the page names itself ("Bereshit · Revi'i").
  ///
  /// [scrolledUnder] is false while the aliyah ribbon, with its own rule, is
  /// what the text scrolls under.
  PreferredSizeWidget _appBar(
    BuildContext context,
    WeekContext ctx,
    AppSettings s, {
    List<Widget>? actions,
    bool scrolledUnder = true,
  }) {
    final names = Names(context);
    final theme = Theme.of(context);
    final eyebrow = SeferType.of(context).eyebrow;
    final titleStyle = theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge!;
    final parsha = names.portion(ctx.portion, ashkenazi: s.ashkenaziNames);
    final aliyah = names.aliyah(_aliyah);
    // The app bar sets its title at most 1.34 times its normal size, as
    // Flutter's AppBar does, and grows to hold both lines at that size.
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.34);
    double line(TextStyle style) => scaler.scale(style.fontSize!) * (style.height ?? 1.2);
    final height = max(64.0, line(eyebrow) + line(titleStyle) + 12);
    // Where the text starts: at the column's padding, or with the column
    // centred.
    final width = MediaQuery.sizeOf(context).width;
    final start = max(_columnPadding, (width - ScriptureStyles(context, s).maxLineWidth) / 2);
    final leading = homeLeading(context);
    final hasLeading = leading != null || (ModalRoute.canPopOf(context) ?? false);
    return AppBar(
      leading: leading,
      toolbarHeight: height,
      titleSpacing: hasLeading ? max(NavigationToolbar.kMiddleSpacing, start - kToolbarHeight) : start,
      actionsPadding: EdgeInsetsDirectional.only(end: start - _columnPadding),
      notificationPredicate: scrolledUnder ? defaultScrollNotificationPredicate : (_) => false,
      title: Semantics(
        label: '$parsha · $aliyah',
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(parsha),
              Text(context.isHebrewUi ? aliyah : '$aliyah · ${Names.aliyahHebrew(_aliyah)}'),
            ],
          ),
        ),
      ),
      actions: actions,
    );
  }

  Widget _buildReader(BuildContext context, WeekContext ctx, ReaderTexts texts, ReaderFlow flow, AppSettings s) {
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

    void larger() => changeReadingScale(ref, 0.1);
    void smaller() => changeReadingScale(ref, -0.1);
    void teamim() => toggle((s) => s.copyWith(showTeamim: !s.showTeamim));
    void nikud() => toggle((s) => s.copyWith(showNikud: !s.showNikud));
    void listen() => _toggleSpeech(texts, flow);
    void help() => _showShortcuts(context, isMac, s);

    final singleKeys = ReaderScreen.singleKeyPlatform;
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.pageDown): () => _pageOrStep(1, ctx, flow),
      const SingleActivator(LogicalKeyboardKey.pageUp): () => _pageOrStep(-1, ctx, flow),
      const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): next,
      const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): back,
      if (_fullText && s.focusMode) ...{
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _moveFocusedVerse(1, flow.verses.length),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _moveFocusedVerse(-1, flow.verses.length),
      },
      if (!singleKeys) ...{
        SingleActivator(LogicalKeyboardKey.equal, control: !isMac, meta: isMac): larger,
        SingleActivator(LogicalKeyboardKey.minus, control: !isMac, meta: isMac): smaller,
        SingleActivator(LogicalKeyboardKey.keyT, control: !isMac, meta: isMac, shift: true, includeRepeats: false): teamim,
        SingleActivator(LogicalKeyboardKey.keyN, control: !isMac, meta: isMac, shift: true, includeRepeats: false): nikud,
        SingleActivator(LogicalKeyboardKey.keyL, control: !isMac, meta: isMac, shift: true, includeRepeats: false): listen,
      } else if (s.singleKeyShortcuts) ...{
        const SingleActivator(LogicalKeyboardKey.keyT, includeRepeats: false): teamim,
        const SingleActivator(LogicalKeyboardKey.keyN, includeRepeats: false): nikud,
        const SingleActivator(LogicalKeyboardKey.keyL, includeRepeats: false): listen,
        // "+" however it is typed (Shift+=, a key of its own, or the
        // numpad), and "=" on its own. The browser gives the numpad's key the
        // character "+" too, so a key binding for it as well would apply
        // each press twice.
        const SingleActivator(LogicalKeyboardKey.equal): larger,
        const CharacterActivator('+'): larger,
        const SingleActivator(LogicalKeyboardKey.minus): smaller,
        const SingleActivator(LogicalKeyboardKey.numpadSubtract): smaller,
        const CharacterActivator('?'): help,
      },
      const SingleActivator(LogicalKeyboardKey.f1): help,
      SingleActivator(LogicalKeyboardKey.slash, control: !isMac, meta: isMac): help,
    };

    final columnWidth = ScriptureStyles(context, s).maxLineWidth;
    // Focus mode reads the full text alone: the overflow menu still switches
    // modes and marks the aliyah read.
    final showRibbon = !(_fullText && s.focusMode);

    // The text scrolls by keyboard as well: with ↑, ↓, Page Up, Page Down
    // and Space on the web, and Ctrl (⌘) with ↑ or ↓ elsewhere, the keys
    // that scroll whatever has no focus of its own.
    return PrimaryScrollController(
      controller: _scroll,
      automaticallyInheritForPlatforms: const {},
      child: CallbackShortcuts(
        bindings: shortcuts,
        child: Focus(
          focusNode: _readerFocus,
          autofocus: true,
          child: Scaffold(
            appBar: _appBar(
              context,
              ctx,
              s,
              scrolledUnder: !showRibbon,
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
                  popUpAnimationStyle: Motion.of(context).style,
                  onSelected: (v) {
                    switch (v) {
                      case 'mode':
                        setState(() {
                          _fullText = !_fullText;
                          // The mark of the verse opened at goes with a
                          // change of mode.
                          _targetVerse = null;
                          _quietFocus = null;
                          // Focus mode picks up the full text at the verse
                          // being read.
                          if (_fullText && s.focusMode && !_finished) _focusedVerse = flow.chunks[_chunk].start;
                        });
                        if (_fullText && _focusedVerse != null) _revealVerse(_focusedVerse!, animate: false);
                      case 'mark':
                        _markAliyahRead(ctx);
                      case 'week':
                        // The week's page beneath, or in place of the reader:
                        // never a second copy of it.
                        if (widget.fromWeek && context.canPop()) {
                          context.pop();
                        } else {
                          replaceWithWeekPage(context, 'week/${ctx.id}');
                        }
                      case 'keys':
                        help();
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
            // The bottom bar runs under the gesture bar itself; above it, the
            // page keeps clear of the notch and the screen's rounded sides.
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  if (showRibbon)
                    AliyahRibbon(
                      week: ctx.progress,
                      aliyahVerses: ctx.aliyahVerses,
                      selected: _aliyah,
                      onSelected: _goToAliyah,
                      maxWidth: columnWidth,
                    ),
                  if (!ctx.isOpen)
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: columnWidth + 2 * _columnPadding),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(_columnPadding, 12, _columnPadding, 0),
                          child: NoticeBanner(
                            icon: Icons.visibility_outlined,
                            text: l.previewNotOpen(Names(context).dateLong(ctx.week.start)),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: _fullText
                        ? _FullText(
                            flow: flow,
                            texts: texts,
                            settings: s,
                            scroll: _scroll,
                            verseKey: _verseKey,
                            focusedVerse: _focusedVerse,
                            quietFocus: _quietFocus,
                            targetVerse: _targetVerse,
                            onTap: _targetVerse == null ? null : () => setState(() => _targetVerse = null),
                            onVerseTap: (i) => setState(() {
                              _focusedVerse = _focusedVerse == i ? null : i;
                              _quietFocus = null;
                            }),
                            footer: ctx.isOpen && !ctx.progress.isAliyahDone(_aliyah)
                                ? FilledButton.icon(
                                    icon: const Icon(Icons.check),
                                    label: Text(l.markAliyahRead),
                                    onPressed: () => _markAliyahRead(ctx),
                                  )
                                : null,
                          )
                        : _finished
                            ? Focus(
                                focusNode: _panelFocus,
                                // With no bottom bar beneath it, the panel
                                // keeps clear of the gesture bar itself.
                                child: SafeArea(
                                  top: false,
                                  child: _FinishedPanel(
                                    ctx: ctx,
                                    aliyah: _aliyah,
                                    firstFocus: _finishFocus,
                                    onGoToAliyah: _goToAliyah,
                                  ),
                                ),
                              )
                            : _GuidedStep(
                                flow: flow,
                                texts: texts,
                                settings: s,
                                aliyah: _aliyah,
                                chunk: _chunk,
                                step: _step,
                                scroll: _scroll,
                                stepTitle: _stepTitle(flow.stepsFor(_chunk)[_step]),
                              ),
                  ),
                ],
              ),
            ),
            // In the scaffold's own slot, so that status messages rise above
            // it rather than cover it.
            bottomNavigationBar: !_fullText && !_finished
                ? ReaderBottomBar(
                    flow: flow,
                    chunk: _chunk,
                    step: _step,
                    onBack: _chunk == 0 && _step == 0 ? null : () => _back(flow),
                    onNext: () => _next(ctx, flow),
                    backFocus: _backFocus,
                    nextFocus: _nextFocus,
                    maxWidth: columnWidth,
                  )
                : null,
          ),
        ),
      ),
    );
  }

  void _markAliyahRead(WeekContext ctx) {
    final today = ref.read(todayProvider);
    ref.read(progressProvider.notifier).markAliyah(ctx.id, _aliyah, today);
    final verses = ref.read(parshaRepositoryProvider).aliyahVerseCount(ctx.portion, _aliyah);
    ref.read(progressProvider.notifier).savePosition(ctx.id, _aliyah, [verses, verses, verses]);
    hapticSuccess(ref);
    showStatus(context, context.l10n.markedRead);
    setState(() => _finished = true);
    // The guided reader shows the finished panel in place of the step. The
    // full text stays, without the button that was pressed.
    _focusAfterFrame(_fullText ? _readerFocus : _finishFocus);
  }

  /// The reader's keys, as this platform binds them.
  void _showShortcuts(BuildContext context, bool isMac, AppSettings settings) {
    final l = context.l10n;
    // Key names are those printed on the keys, but for the arrows and the
    // space bar. The interface fonts have no arrows, ⌘ or ⌥: icons draw them.
    final up = _Key(l.keyUp, Icons.arrow_upward);
    final down = _Key(l.keyDown, Icons.arrow_downward);
    final mod = isMac ? const _Key('Command', Icons.keyboard_command_key) : const _Key('Ctrl');
    final alt = isMac ? const _Key('Option', Icons.keyboard_option_key) : const _Key('Alt');
    const shift = _Key('Shift');
    final web = ReaderScreen.singleKeyPlatform;
    final singleKeys = web && settings.singleKeyShortcuts;
    final rows = <(List<List<_Key>>, String)>[
      (
        web ? [[up], [down], [_Key(l.keySpace)]] : [[mod, up], [mod, down]],
        l.shortcutScroll,
      ),
      (const [[_Key('Page Down')]], l.shortcutPageDown),
      (const [[_Key('Page Up')]], l.shortcutPageUp),
      ([[alt, down]], l.shortcutNext),
      ([[alt, up]], l.shortcutBack),
      if (settings.focusMode) ([[up], [down]], l.shortcutFocusVerse),
      if (!web) ...[
        ([[mod, const _Key('=')]], l.shortcutLarger),
        ([[mod, const _Key('−')]], l.shortcutSmaller),
        ([[mod, shift, const _Key('T')]], l.shortcutTeamim),
        ([[mod, shift, const _Key('N')]], l.shortcutNikud),
        ([[mod, shift, const _Key('L')]], l.shortcutListen),
      ] else if (singleKeys) ...[
        (const [[_Key('+')]], l.shortcutLarger),
        (const [[_Key('−')]], l.shortcutSmaller),
        (const [[_Key('T')]], l.shortcutTeamim),
        (const [[_Key('N')]], l.shortcutNikud),
        (const [[_Key('L')]], l.shortcutListen),
      ],
      (
        [
          if (singleKeys) const [_Key('?')],
          const [_Key('F1')],
          [mod, const _Key('/')],
        ],
        l.shortcutHelp,
      ),
    ];
    showAppDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        // The keys take as much of the width as they need, up to a little
        // over half.
        final width = min(560.0, MediaQuery.sizeOf(context).width - 80) - 48;
        return AlertDialog(
          title: Text(l.keyboardShortcuts),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (combos, action) in rows)
                  MergeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(action, style: theme.textTheme.bodyMedium)),
                          const Gap(16),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: max(120, width * 0.55)),
                            child: _KeyCombos(combos),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionClose))],
        );
      },
    );
  }
}

/// A key as the shortcuts dialog names it, and draws it when [icon] is set.
class _Key {
  const _Key(this.label, [this.icon]);
  final String label;
  final IconData? icon;
}

/// Ways to press a shortcut, each a combination of keys drawn as keycaps.
/// The combinations stand apart; the keys of one are joined by "+".
class _KeyCombos extends StatelessWidget {
  const _KeyCombos(this.combos);
  final List<List<_Key>> combos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = theme.textTheme.labelMedium?.copyWith(color: scheme.onSurface);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final alignment = rtl ? WrapAlignment.start : WrapAlignment.end;
    Widget cap(_Key key) => Container(
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: key.icon != null
                // Drawn keys grow with the text, like the named ones.
                ? Icon(key.icon, size: MediaQuery.textScalerOf(context).scale(16), color: scheme.onSurface)
                : Text(key.label, style: label),
          ),
        );
    return Semantics(
      label: combos.map((keys) => keys.map((k) => k.label).join(' + ')).join(', '),
      child: ExcludeSemantics(
        // Keys read left to right in either language, on the dialog's outer
        // side.
        child: Directionality(
          textDirection: TextDirection.ltr,
          // Wraps rather than overflows at a large text size.
          child: Wrap(
            alignment: alignment,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final keys in combos)
                Wrap(
                  alignment: alignment,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 6,
                  children: [
                    for (final (i, key) in keys.indexed) ...[
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Text('+', style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                        ),
                      cap(key),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The current step of guided reading: one verse, section or aliyah, in the
/// layer to be read now (DESIGN_SYSTEM.md §6.17). The pass track, one line
/// saying what to read, and then the verses: nothing else comes before them.
class _GuidedStep extends StatelessWidget {
  const _GuidedStep({
    required this.flow,
    required this.texts,
    required this.settings,
    required this.aliyah,
    required this.chunk,
    required this.step,
    required this.scroll,
    required this.stepTitle,
  });

  final ReaderFlow flow;
  final ReaderTexts texts;
  final AppSettings settings;
  final int aliyah;
  final int chunk;
  final int step;
  final ScrollController scroll;
  final String stepTitle;

  /// How long one step takes to fade into the next (§8): opacity alone, with
  /// no slide.
  static const _fade = Duration(milliseconds: 180);

  /// The steps cross-fading in place from the top, where the default would
  /// centre a short step halfway down a long one.
  static Widget _fromTop(Widget? current, List<Widget> previous) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previous, ?current],
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final steps = flow.stepsFor(chunk);
    final kind = steps[step];
    final refs = flow.stepVerses(chunk, kind);
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
          final targum = ScriptureVerse(verse: texts.onkelos!.verse(r), kind: ScriptureKind.targum, settings: settings);
          if (!flow.thirdHebrewInTargum(chunk, r)) return targum;
          // Read with others, the verse has no step of its own for its third
          // reading: the Hebrew follows its Onkelos here instead, set apart
          // in a block of its own so that it can't be taken for Targum, nor
          // the Targum after it for Torah, which is labelled again.
          final scheme = theme.colorScheme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              targum,
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                padding: const EdgeInsetsDirectional.only(start: 12),
                decoration: BoxDecoration(
                  border: BorderDirectional(start: BorderSide(color: scheme.outline, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayerLabel(l.mikraLabel),
                    ScriptureVerse(verse: texts.mikra.verse(r), kind: ScriptureKind.mikra, settings: settings),
                    if (settings.showTranslation && texts.english != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TranslationVerse(text: texts.english!.verse(r).readText, number: r.verse, settings: settings),
                      ),
                    _Note(text: l.noTargumNote),
                  ],
                ),
              ),
              if (r != refs.last) LayerLabel(l.targumLabel),
            ],
          );
        case StepKind.rashi:
          final comments = texts.rashi?.on(r) ?? const [];
          if (comments.isEmpty) {
            // A third reading stands in only for Rashi read in place of the
            // Targum.
            final suggestThird = settings.thirdReadingPrompts && !settings.usesOnkelos;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScriptureVerse(verse: texts.mikra.verse(r), kind: ScriptureKind.mikra, settings: settings),
                _Note(text: suggestThird ? l.noRashiNote : l.noRashiComment),
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

    return Scrollbar(
      controller: scroll,
      child: SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: styles.maxLineWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // It stays as the step changes, and its bars fill as it does.
                PassTrack(steps: steps, step: step),
                const Gap(8),
                AnimatedSwitcher(
                  duration: Motion.of(context).d(_fade),
                  layoutBuilder: _fromTop,
                  child: KeyedSubtree(
                    key: ValueKey((aliyah, chunk, step)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          container: true,
                          // Spoken by the reader's announcement where there
                          // is one, and elsewhere as it appears.
                          liveRegion: !MediaQuery.supportsAnnounceOf(context),
                          label: '$stepTitle\n${l.stepOf(step + 1, steps.length)}',
                          child: ExcludeSemantics(child: Text(stepTitle, style: theme.textTheme.bodyLarge)),
                        ),
                        const Gap(12),
                        for (final r in refs) ...[
                          layerFor(r),
                          if (settings.showRashi &&
                              kind != StepKind.rashi &&
                              texts.rashi != null &&
                              texts.rashi!.on(r).isNotEmpty) ...[
                            LayerLabel(l.rashiLabel),
                            RashiComments(comments: texts.rashi!.on(r), settings: settings, english: englishRashi),
                          ],
                          const Gap(8),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A note under a verse: why it is read a third time, or that Rashi is
/// silent on it.
class _Note extends StatelessWidget {
  const _Note({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: NoticeBanner(icon: Icons.info_outline, text: text),
      );
}

class _FinishedPanel extends ConsumerWidget {
  const _FinishedPanel({required this.ctx, required this.aliyah, required this.firstFocus, required this.onGoToAliyah});

  final WeekContext ctx;
  final int aliyah;

  /// For the first of its buttons, which the reader gives the focus.
  final FocusNode firstFocus;
  final ValueChanged<int> onGoToAliyah;

  /// The aliyah to continue with: the first after this one not yet read,
  /// then the first before it; null once the parsha is read. A preview
  /// records no reading, so it simply moves on to the next aliyah.
  int? _nextTarget(WeekProgress week) {
    if (!ctx.isOpen) return aliyah < kAliyot - 1 ? aliyah + 1 : null;
    for (final a in [for (var a = aliyah + 1; a < kAliyot; a++) a, for (var a = 0; a < aliyah; a++) a]) {
      if (!week.isAliyahDone(a)) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final week = ref.watch(progressProvider).week(ctx.id);
    final complete = week.isComplete;
    final next = _nextTarget(week);
    final haftarah = complete && (settings.haftarahEnabled || ctx.haftarahRequired) && week.haftarah == null;
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
                // Spoken by the reader's announcement where there is one,
                // and elsewhere (on Android) as it appears.
                liveRegion: !MediaQuery.supportsAnnounceOf(context),
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
              if (next != null)
                FilledButton.icon(
                  focusNode: firstFocus,
                  onPressed: () => onGoToAliyah(next),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(l.continueWithAliyah(names.aliyah(next))),
                ),
              if (haftarah)
                FilledButton.icon(
                  focusNode: next == null ? firstFocus : null,
                  onPressed: () => replaceWithWeekPage(context, 'haftarah/${ctx.id}'),
                  icon: const Icon(Icons.auto_stories),
                  label: Text(l.haftarahTitle),
                ),
              const Gap(8),
              OutlinedButton(
                focusNode: next == null && !haftarah ? firstFocus : null,
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
    required this.verseKey,
    required this.focusedVerse,
    this.quietFocus,
    required this.targetVerse,
    required this.onTap,
    required this.onVerseTap,
    this.footer,
  });

  final ReaderFlow flow;
  final ReaderTexts texts;
  final AppSettings settings;
  final ScrollController scroll;

  /// The key of each verse's block, by index, for scrolling it into view.
  final GlobalKey Function(int) verseKey;
  final int? focusedVerse;

  /// The focused verse that shows no highlight: the one opened at, until
  /// focus moves.
  final int? quietFocus;

  /// The verse the reader was opened at, which is marked.
  final VerseRef? targetVerse;

  /// Called on any tap on the text, wherever it lands.
  final VoidCallback? onTap;
  final ValueChanged<int> onVerseTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final styles = ScriptureStyles(context, settings);
    final englishRashi = settings.secondReading == SecondReading.rashiEnglish;

    Widget verse(int i) {
      final r = flow.verses[i];
      final targeted = r == targetVerse;
      final dimmed = settings.focusMode && focusedVerse != null && focusedVerse != i;
      // The mark of the verse opened at stands in for focus mode's own, which
      // stays off after the mark goes, until focus moves.
      final highlighted = settings.focusMode && focusedVerse == i && !targeted && quietFocus != i;
      final brk = texts.mikra.breaks[r];
      return Center(
        key: verseKey(i),
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
                    headingLevel: 2,
                    child: Text(
                      l.chapterLabel(context.isHebrewUi ? HebrewText.gematria(r.chapter, punctuate: false) : '${r.chapter}'),
                      style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
              TargetVerseMark(
                active: targeted,
                child: InkWell(
                  onTap: settings.focusMode ? () => onVerseTap(i) : null,
                  // ↑ and ↓ move from verse to verse: a Tab stop on each
                  // would put up to 72 before the button at the end.
                  canRequestFocus: false,
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
              ),
              if (brk != null)
                ExcludeSemantics(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: brk == SectionBreak.open ? 16 : 8),
                    // A rubric, like the marks inside a verse
                    // (DESIGN_SYSTEM.md §3.1).
                    child: Text(
                      brk == SectionBreak.open ? 'פ' : 'ס',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.secondary),
                    ),
                  ),
                )
              else
                const Gap(10),
            ],
          ),
        ),
      );
    }

    return TapObserver(
      onTap: onTap,
      child: Scrollbar(
        controller: scroll,
        // Every verse is built (an aliyah has 72 at most), so that any of them
        // can be scrolled to, and Tab reaches the button at the end.
        child: SingleChildScrollView(
          controller: scroll,
          // With no bottom bar beneath it, its end clears the gesture bar.
          padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < flow.verses.length; i++) verse(i),
              if (footer case final footer?) Padding(padding: const EdgeInsets.only(top: 16), child: Center(child: footer)),
            ],
          ),
        ),
      ),
    );
  }
}
