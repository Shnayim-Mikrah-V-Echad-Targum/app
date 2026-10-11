import 'dart:async';
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
import '../../core/calendar/hebrew_date.dart';
import '../../core/calendar/jewish_holidays.dart';
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
import '../../ui/widgets/ornaments.dart' show Eyebrow, SeferDivider;
import '../../ui/widgets/progress_widgets.dart' show WeekStatusBadge;
import '../parsha/week_context.dart';
import '../progress/domain/progress_models.dart';
import '../progress/domain/streak_engine.dart';
import '../settings/app_settings.dart';
import 'aliyah_ribbon.dart';
import 'display_sheet.dart';
import 'listen_along.dart';
import 'listen_bar.dart';
import 'notification_prompt.dart';
import 'pass_track.dart';
import 'reader_bottom_bar.dart';
import 'reader_flow.dart';
import 'scripture_text.dart';
import 'verse_actions_sheet.dart';
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

  /// Whether finishing completed the parsha just now, rather than stepping
  /// once more through a parsha read already: only then does the finished
  /// panel tell of the streak and a grace day earned.
  bool _justCompleted = false;

  /// Whether a step of this visit to the aliyah completed the parsha: the
  /// last Targum, say, with the last verse's repeat still to come, which
  /// then finishes the aliyah.
  bool _completedOnVisit = false;
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

  // Listen, from its start until it ends or is stopped (DESIGN.md §3): the
  // verse being read, which is highlighted, and the player beneath the text.
  late final ListenController _listen;

  // Listen along's breath between one reading of the guided reader and the
  // next, and whether it is paused there.
  Timer? _listenOn;
  bool _listenHeld = false;

  // The step was reached by Listen along, whose voice reads it: it is not
  // announced as well, which would speak over it.
  bool _quietStep = false;

  // What the reader last showed, for Listen along to go on with once its
  // breath is over.
  (WeekContext, ReaderTexts, ReaderFlow)? _shown;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsProvider);
    _listen = ListenController(_tts)..addListener(_listenChanged);
    if (ref.read(settingsProvider).keepScreenOn) {
      WakelockPlus.enable().catchError((_) {});
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable().catchError((_) {});
    _listenOn?.cancel();
    _listen
      ..removeListener(_listenChanged)
      ..dispose();
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
    _stopListening();
    // Continued from the finished panel, the focus goes on to Next.
    if (_panelFocus.hasFocus) _focusAfterFrame(_nextFocus);
    setState(() {
      _aliyah = a;
      _positioned = false;
      _announceWhenPositioned = true;
      _finished = false;
      _completedOnVisit = false;
      _focusedVerse = null;
      _quietFocus = null;
      _targetVerse = null;
      _quietStep = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Gives [node] the keyboard focus once the frame being built, which
  /// builds its control in place of the one that had the focus, is done.
  /// Asking autofocus would not do: the route remembers the reader's own
  /// focus. Not while a page is over the reader (the one celebrating a
  /// finished book, say), whose focus it would take.
  void _focusAfterFrame(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Asked of the control's own context, so that only it, and not the
      // whole reader, depends on what is over the page.
      final at = node.context;
      if (mounted && at != null && (ModalRoute.isCurrentOf(at) ?? true)) node.requestFocus();
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

  /// Next: records the step read, and shows the next one, or the finished
  /// panel. Pressed, it stops Listen; [listening] is Listen along going on
  /// to the next reading, which it reads.
  void _next(WeekContext ctx, ReaderFlow flow, {bool listening = false}) {
    if (_finished) return;
    if (!listening) _stopListening();
    final steps = flow.stepsFor(_chunk);
    final hadCompletedBefore = ref.read(progressProvider).weeks.values.any((w) => w.completedAliyot > 0);
    final wasComplete = ref.read(progressProvider).week(ctx.id).isComplete;
    _record(ctx, flow, _chunk, _step);
    if (!wasComplete && ref.read(progressProvider).week(ctx.id).isComplete) _completedOnVisit = true;
    if (!listening) hapticTap(ref);
    setState(() {
      _quietStep = listening;
      if (_step + 1 < steps.length) {
        _step++;
      } else if (_chunk + 1 < flow.chunks.length) {
        _chunk++;
        _step = 0;
      } else {
        _finished = true;
        _justCompleted = _completedOnVisit;
      }
    });
    if (_finished) {
      // Next goes with the bottom bar: the panel's first button takes over,
      // once the reminders offered after a first aliyah, which take the
      // focus while they are open, are answered.
      final offer = _offersReminders(ctx, firstEver: !hadCompletedBefore);
      if (!offer) _focusAfterFrame(_finishFocus);
      _onFinished(ctx, offerReminders: offer);
    } else if (!listening) {
      _announceStep(flow);
    }
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _back(ReaderFlow flow) {
    // Page Up or Alt+↑ at the first step: nothing to go back to, or to say.
    if (!_finished && _chunk == 0 && _step == 0) return;
    _stopListening();
    final fromPanel = _finished && _panelFocus.hasFocus;
    final fromBack = _backFocus.hasFocus;
    setState(() {
      _quietStep = false;
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
      final second = names.secondReading(settings.secondReading);
      await maybeOfferReminders(context, ref, celebration: l.firstAliyahDone(l.versesCount(verses), second));
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

  // --- A verse's options -----------------------------------------------------

  /// Opens what can be done with verse [r] (copy, share, ask): its Hebrew,
  /// with its Targum and translation where the reader shows them.
  void _openVerseOptions(ReaderTexts texts, String book, VerseRef r) => showVerseActions(
        context,
        ChosenVerse(
          at: BookVerse(book, r),
          hebrew: texts.mikra.verse(r),
          targum: texts.onkelos?.verse(r),
          english: texts.english?.verse(r).readText,
        ),
      );

  /// Shift+F10 or the menu key: the options of the verse focus mode is on,
  /// or else of the first verse in view.
  void _verseOptionsByKey(ReaderTexts texts, ReaderFlow flow) {
    final focused = _fullText && ref.read(settingsProvider).focusMode ? _focusedVerse : null;
    if (focused != null) {
      _openVerseOptions(texts, flow.book, flow.verses[focused]);
    } else {
      openVerseOptionsInView(context);
    }
  }

  // --- Listening ----------------------------------------------------------------

  /// How long Listen along waits after one reading before it goes on to the
  /// next.
  static const _listenAlongPause = Duration(milliseconds: 600);

  /// The verse Listen reads has moved on, or it has paused, gone on or
  /// ended. Focus mode reads around the verse being read, so that it is never
  /// one of those dimmed.
  void _listenChanged() {
    if (!mounted) return;
    final verse = _listen.verse;
    setState(() {
      if (verse != null && _fullText && ref.read(settingsProvider).focusMode) {
        _focusedVerse = verse;
        _quietFocus = null;
      }
    });
  }

  /// Starts Listen on what the reader shows, from [startVerse] (an index into
  /// the aliyah's verses), or else from where the reader is: in the full
  /// text, the verse opened at, the verse focus mode is on, or the first in
  /// view; in the guided reader, the step's first verse. Until the voice is
  /// stopped, the verse it reads is highlighted and the player shows.
  Future<void> _startListening(ReaderTexts texts, ReaderFlow flow, {bool checkVoice = true, int? startVerse}) async {
    final l = context.l10n;
    final hasHebrew = checkVoice ? await _tts.hasHebrewVoice() : null;
    if (!mounted) return;
    final s = ref.read(settingsProvider);
    final queue = _speechQueue(texts, flow, s);
    if (queue.isEmpty) return;
    if (hasHebrew == false && queue.language == 'he-IL') showStatus(context, l.ttsNoHebrewVoice);
    final start = startVerse ?? (_fullText ? _listenStartVerse(flow) : queue.verses.first);
    _listenOn?.cancel();
    _listenOn = null;
    _listenHeld = false;
    // The voice's highlight takes over from the mark of the verse opened at.
    if (_targetVerse != null) {
      setState(() {
        _targetVerse = null;
        _quietFocus = null;
      });
    }
    final end = await _listen.play(queue, rate: s.speechRate, startVerse: start);
    if (!mounted) return;
    switch (end) {
      case ListenEnd.failed:
        showStatus(context, l.ttsUnavailable);
      case ListenEnd.stopped:
        break;
      case ListenEnd.finished:
        // Listen along goes on to the next reading, after a breath; at the
        // aliyah's end, or without it, Listen is over.
        if (_listensOn()) {
          setState(() => _listenOn = Timer(_listenAlongPause, _listenOnNow));
        } else {
          _listen.end();
        }
    }
  }

  /// Whether Listen along goes on from the step shown to the next one: in
  /// the guided reader, up to the aliyah's last step, where the reader
  /// finishes the aliyah themselves.
  bool _listensOn() {
    final flow = _shown?.$3;
    if (flow == null || _fullText || _finished || !ref.read(settingsProvider).listenAlong) return false;
    return _chunk < flow.chunks.length - 1 || _step < flow.stepsFor(_chunk).length - 1;
  }

  /// Listen along's breath is over: on to the next reading, which it reads.
  /// The step read is recorded as Next records it.
  void _listenOnNow() {
    _listenOn?.cancel();
    _listenOn = null;
    _listenHeld = false;
    final shown = _shown;
    if (!mounted || shown == null || !_listen.active) return;
    if (!_listensOn()) return _stopListening();
    final (ctx, texts, flow) = shown;
    _next(ctx, flow, listening: true);
    _startListening(texts, flow, checkVoice: false);
  }

  /// Play or pause, from the player and the keyboard: Listen starts, or
  /// pauses at the verse it reads, or goes on from it.
  void _playPause(ReaderTexts texts, ReaderFlow flow) {
    if (!_listen.active) {
      _startListening(texts, flow);
    } else if (_listenOn != null) {
      // Paused in the breath between one reading and the next.
      _listenOn!.cancel();
      setState(() {
        _listenOn = null;
        _listenHeld = true;
      });
    } else if (_listenHeld) {
      _listenOnNow();
    } else if (_listen.paused) {
      _listen.resume();
    } else {
      _listen.pause();
    }
  }

  /// Whether Listen along is between one reading and the next, waiting or
  /// paused there.
  bool get _betweenReadings => _listen.active && (_listenOn != null || _listenHeld);

  bool get _canListenBack => _betweenReadings || _listen.hasPrevious;

  bool get _canListenOn => _listen.active && (_listen.hasNext || _listensOn());

  /// Back a verse; between Listen along's readings, the last verse read
  /// again.
  void _listenBack(ReaderTexts texts, ReaderFlow flow) {
    if (_betweenReadings) {
      _startListening(texts, flow, checkVoice: false, startVerse: _listen.verse);
    } else {
      _listen.previous();
    }
  }

  /// On a verse; from the step's last, Listen along goes on to the next
  /// reading.
  void _listenOnVerse() {
    if (!_listen.active) return;
    if (_listen.hasNext) return _listen.next();
    if (_listensOn()) _listenOnNow();
  }

  void _setSpeechRate(double rate) {
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(speechRate: rate));
    _listen.setRate(rate);
  }

  /// Stops Listen, and any speech.
  void _stopListening() {
    _listenOn?.cancel();
    _listenOn = null;
    _listenHeld = false;
    _listen.stop();
  }

  /// Where Listen starts in the full text: at the verse opened at, the verse
  /// focus mode is on, or else the first verse in view.
  int _listenStartVerse(ReaderFlow flow) {
    if (_targetVerse case final target?) {
      final i = flow.verses.indexOf(target);
      if (i >= 0) return i;
    }
    final focused = _focusedVerse;
    if (focused != null && ref.read(settingsProvider).focusMode) return focused;
    return _firstVerseInView(flow.verses.length);
  }

  /// What Listen reads, verse by verse, each item with the index of its verse
  /// among the aliyah's: in the full text, each verse and then its Targum,
  /// where it is shown; in the guided reader, the step shown, as the step
  /// shows it. The Divine Name is spoken as the reader has chosen.
  SpeechQueue _speechQueue(ReaderTexts texts, ReaderFlow flow, AppSettings s) {
    String hebrew(Verse v, {bool targum = false}) =>
        HebrewSpeech.spoken(v.readText, divineName: s.divineName, targum: targum);
    final queue = SpeechQueue(language: 'he-IL');
    if (_fullText || _finished) {
      for (final (i, r) in flow.verses.indexed) {
        queue.add(i, hebrew(texts.mikra.verse(r)));
        if (_fullText && texts.onkelos != null) queue.add(i, hebrew(texts.onkelos!.verse(r), targum: true));
      }
      return queue;
    }
    final kind = flow.stepsFor(_chunk)[_step];
    final refs = flow.stepVerses(_chunk, kind);
    final index = {for (final (i, r) in flow.verses.indexed) r: i};
    switch (kind) {
      case StepKind.targum:
        for (final r in refs) {
          queue.add(index[r]!, hebrew(texts.onkelos!.verse(r), targum: true));
          // With the Hebrew of a verse read a third time among the Targum.
          if (flow.thirdHebrewInTargum(_chunk, r)) queue.add(index[r]!, hebrew(texts.mikra.verse(r)));
        }
      case StepKind.rashi:
        final comments = [for (final r in refs) texts.rashi!.on(r)];
        if (s.secondReading == SecondReading.rashiEnglish) {
          // One voice reads it all: the comments in English, or, where Rashi
          // is silent on the whole step, its verses in Hebrew.
          final english = SpeechQueue(language: 'en-US');
          for (final (i, r) in refs.indexed) {
            for (final c in comments[i]) {
              english.add(index[r]!, spokenRashiEnglish(c, s, speech: true).string);
            }
          }
          if (!english.isEmpty) return english;
          for (final r in refs) {
            queue.add(index[r]!, hebrew(texts.mikra.verse(r)));
          }
        } else {
          // A verse Rashi is silent on is read in Hebrew, as the step shows it.
          for (final (i, r) in refs.indexed) {
            if (comments[i].isEmpty) queue.add(index[r]!, hebrew(texts.mikra.verse(r)));
            for (final c in comments[i]) {
              queue.add(
                index[r]!,
                HebrewSpeech.spoken('${c.heading ?? ''} ${c.text}', divineName: s.divineName, rashi: true),
              );
            }
          }
        }
      case StepKind.mikra1 || StepKind.mikra2 || StepKind.thirdHebrew || StepKind.repeatLast:
        for (final r in refs) {
          queue.add(index[r]!, hebrew(texts.mikra.verse(r)));
        }
    }
    return queue;
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
          _shown = (ctx, texts, flow);
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
      // The inset goes before the title alone (as PageScaffold's does): as
      // titleSpacing it would be kept after it too, and a wide window would
      // leave the title no room beside the actions.
      titleSpacing: 0,
      actionsPadding: EdgeInsetsDirectional.only(end: start - _columnPadding),
      notificationPredicate: scrolledUnder ? defaultScrollNotificationPredicate : (_) => false,
      title: Padding(
        padding: EdgeInsetsDirectional.only(
          start: hasLeading ? max(NavigationToolbar.kMiddleSpacing, start - kToolbarHeight) : start,
          end: NavigationToolbar.kMiddleSpacing,
        ),
        // The app bar makes it a heading; this gives its level, as every
        // page's title has.
        child: Semantics(
          headingLevel: 1,
          label: '$parsha · $aliyah',
          child: ExcludeSemantics(
            child: _ReaderTitle(
              parsha: parsha,
              aliyah: aliyah,
              hebrew: context.isHebrewUi ? null : Names.aliyahHebrew(_aliyah),
            ),
          ),
        ),
      ),
      actions: actions,
    );
  }

  Widget _buildReader(BuildContext context, WeekContext ctx, ReaderTexts texts, ReaderFlow flow, AppSettings s) {
    final l = context.l10n;
    final isMac = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
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
    void listen() => _playPause(texts, flow);
    void listenBack() {
      if (_canListenBack) _listenBack(texts, flow);
    }

    void help() => _showShortcuts(context, isMac, s);
    void verseOptions() => _verseOptionsByKey(texts, flow);

    final singleKeys = ReaderScreen.singleKeyPlatform;
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.pageDown): () => _pageOrStep(1, ctx, flow),
      const SingleActivator(LogicalKeyboardKey.pageUp): () => _pageOrStep(-1, ctx, flow),
      const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): next,
      const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): back,
      // While Listen reads, back or on a verse: in either language, as the
      // player's buttons are, and on the web too.
      SingleActivator(LogicalKeyboardKey.arrowLeft, control: !isMac, meta: isMac, shift: true, includeRepeats: false):
          listenBack,
      SingleActivator(LogicalKeyboardKey.arrowRight, control: !isMac, meta: isMac, shift: true, includeRepeats: false):
          _listenOnVerse,
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
      // The keys that open a context menu, for the verses' options.
      const SingleActivator(LogicalKeyboardKey.f10, shift: true, includeRepeats: false): verseOptions,
      const SingleActivator(LogicalKeyboardKey.contextMenu, includeRepeats: false): verseOptions,
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
      child: OwnContextMenu(
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
                  IconButton(
                    tooltip: _listen.active ? l.stopListening : l.listen,
                    icon: Icon(_listen.active ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
                    onPressed: () => _listen.active ? _stopListening() : _startListening(texts, flow),
                  ),
                  IconButton(
                    tooltip: l.displaySettings,
                    icon: const Icon(Icons.text_format),
                    onPressed: () => showDisplaySheet(context, listenAlong: true),
                  ),
                  PopupMenuButton<String>(
                    tooltip: l.actionMore,
                    popUpAnimationStyle: Motion.of(context).style,
                    onSelected: (v) {
                      switch (v) {
                        case 'mode':
                          // Listen reads what the mode shows.
                          _stopListening();
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
                              speakingVerse: _listen.verse,
                              onTap: _targetVerse == null ? null : () => setState(() => _targetVerse = null),
                              onVerseTap: (i) => setState(() {
                                _focusedVerse = _focusedVerse == i ? null : i;
                                _quietFocus = null;
                              }),
                              onVerseOptions: (r) => _openVerseOptions(texts, flow.book, r),
                              footer: ctx.isOpen && !ctx.progress.isAliyahDone(_aliyah)
                                  ? FilledButton.tonalIcon(
                                      style: AppButtons.tonal(context),
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
                                      justCompleted: _justCompleted,
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
                                  quiet: _quietStep,
                                  speakingVerse: switch (_listen.verse) {
                                    final i? when i < flow.verses.length => flow.verses[i],
                                    _ => null,
                                  },
                                  onVerseOptions: (r) => _openVerseOptions(texts, flow.book, r),
                                ),
                    ),
                  ],
                ),
              ),
              // In the scaffold's own slot, so that status messages rise above
              // it rather than cover it.
              bottomNavigationBar: _bottomBars(ctx, texts, flow, s, columnWidth),
            ),
          ),
        ),
      ),
    );
  }

  /// What sits beneath the text: while Listen reads, its player, and in the
  /// guided reader the bar with Back and Next, which keeps its place under
  /// the player as the player comes and goes.
  Widget? _bottomBars(WeekContext ctx, ReaderTexts texts, ReaderFlow flow, AppSettings s, double columnWidth) {
    final steps = !_fullText && !_finished;
    if (!steps && !_listen.active) return null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_listen.active)
          KeyedSubtree(
            key: const ValueKey('listen'),
            // Above the bottom bar, which keeps clear of the gesture bar.
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: steps,
              child: ListenBar(
                paused: _listen.paused || _listenHeld,
                onPlayPause: () => _playPause(texts, flow),
                onPrevious: _canListenBack ? () => _listenBack(texts, flow) : null,
                onNext: _canListenOn ? _listenOnVerse : null,
                rate: s.speechRate,
                onRate: _setSpeechRate,
                onStop: _stopListening,
                maxWidth: columnWidth,
              ),
            ),
          ),
        if (steps)
          ReaderBottomBar(
            key: const ValueKey('steps'),
            flow: flow,
            chunk: _chunk,
            step: _step,
            onBack: _chunk == 0 && _step == 0 ? null : () => _back(flow),
            onNext: () => _next(ctx, flow),
            backFocus: _backFocus,
            nextFocus: _nextFocus,
            maxWidth: columnWidth,
          ),
      ],
    );
  }

  void _markAliyahRead(WeekContext ctx) {
    final today = ref.read(todayProvider);
    final wasComplete = ref.read(progressProvider).week(ctx.id).isComplete;
    ref.read(progressProvider.notifier).markAliyah(ctx.id, _aliyah, today);
    _justCompleted = !wasComplete && ref.read(progressProvider).week(ctx.id).isComplete;
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
    // Drawn left to right, as the keys are (_KeyCombos).
    final left = _Key(l.keyLeft, Icons.arrow_back);
    final right = _Key(l.keyRight, Icons.arrow_forward);
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
      ([[mod, shift, left], [mod, shift, right]], l.shortcutListenVerse),
      ([[shift, const _Key('F10')]], l.shortcutVerseOptions),
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

/// The reader's title in its app bar: the parsha as an eyebrow over the
/// aliyah, and in the English UI the aliyah's Hebrew name after it ("Revi'i ·
/// רביעי"). Where the line has no room for both (a narrow phone, a wider
/// interface font), the Hebrew goes; and a name that still has no room, as
/// a long double parsha's eyebrow may not, is set a little smaller rather
/// than cut short.
class _ReaderTitle extends StatelessWidget {
  const _ReaderTitle({required this.parsha, required this.aliyah, this.hebrew});

  final String parsha;
  final String aliyah;

  /// The aliyah's Hebrew name, shown after [aliyah] where it fits.
  final String? hebrew;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final hebrew = this.hebrew;
          var line = aliyah;
          if (hebrew != null) {
            final both = '$aliyah · $hebrew';
            // As the app bar sets it: its style, and its text size, which it
            // keeps from growing past 1.34 times.
            final painter = TextPainter(
              text: TextSpan(text: both, style: DefaultTextStyle.of(context).style),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 1,
            )..layout();
            if (painter.width <= constraints.maxWidth) line = both;
            painter.dispose();
          }
          Widget fitted(Widget child) =>
              FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: child);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [fitted(Eyebrow(parsha)), fitted(Text(line))],
          );
        },
      );
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
    this.quiet = false,
    this.speakingVerse,
    required this.onVerseOptions,
  });

  final ReaderFlow flow;
  final ReaderTexts texts;
  final AppSettings settings;
  final int aliyah;
  final int chunk;
  final int step;
  final ScrollController scroll;
  final String stepTitle;

  /// Whether the step, reached by Listen along, goes unannounced: its voice
  /// reads it.
  final bool quiet;

  /// The verse Listen is reading, which is highlighted.
  final VerseRef? speakingVerse;

  /// Opens a verse's options, from a long press on it.
  final ValueChanged<VerseRef> onVerseOptions;

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

    // Every verse of the guided reader hangs its number in the gutter at its
    // start (§4.7).
    ScriptureVerse verse(BookText text, VerseRef r, ScriptureKind kind, {bool secondary = false}) => ScriptureVerse(
          verse: text.verse(r),
          kind: kind,
          settings: settings,
          secondary: secondary,
          hangingNumber: true,
          onLongPress: () => onVerseOptions(r),
        );

    // What goes with a verse shares the edge its text starts at, past the
    // gutter its number hangs in.
    Widget hanging(Widget child) => HangingIndent(settings: settings, child: child);

    Widget translation(VerseRef r) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: hanging(TranslationVerse(text: texts.english!.verse(r).readText, number: r.verse, settings: settings)),
        );

    Widget note(String text) => hanging(_Note(text: text));

    Widget rashi(List<Comment> comments) =>
        hanging(RashiComments(comments: comments, settings: settings, english: englishRashi));

    Widget layerFor(VerseRef r) {
      switch (kind) {
        case StepKind.mikra1:
        case StepKind.mikra2:
        case StepKind.thirdHebrew:
        case StepKind.repeatLast:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              verse(texts.mikra, r, ScriptureKind.mikra),
              if (settings.showTranslation && texts.english != null) translation(r),
              if (kind == StepKind.thirdHebrew) note(settings.usesOnkelos ? l.noTargumNote : l.noRashiNote),
            ],
          );
        case StepKind.targum:
          final targum = verse(texts.onkelos!, r, ScriptureKind.targum);
          if (!flow.thirdHebrewInTargum(chunk, r)) return targum;
          // Read with others, the verse has no step of its own for its third
          // reading: the Hebrew follows its Onkelos here instead, set apart
          // in a block of its own so that it can't be taken for Targum, nor
          // the Targum after it for Torah, which is labelled again (below).
          // Its rule is where the Hebrew begins, at the right in either
          // language of the app, as every scripture rule is (§4.7).
          final scheme = theme.colorScheme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              targum,
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                padding: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: scheme.outline, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    hanging(LayerLabel(l.mikraLabel)),
                    verse(texts.mikra, r, ScriptureKind.mikra),
                    if (settings.showTranslation && texts.english != null) translation(r),
                    note(l.noTargumNote),
                  ],
                ),
              ),
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
                verse(texts.mikra, r, ScriptureKind.mikra),
                note(suggestThird ? l.noRashiNote : l.noRashiComment),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              verse(texts.mikra, r, ScriptureKind.mikra, secondary: true),
              const Gap(8),
              rashi(comments),
            ],
          );
      }
    }

    // The marks between sections stand in the Torah's text: under the steps
    // that read it, not the Targum's or Rashi's.
    final hebrewStep = kind != StepKind.targum && kind != StepKind.rashi;

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
                          liveRegion: !quiet && !MediaQuery.supportsAnnounceOf(context),
                          label: '$stepTitle\n${l.stepOf(step + 1, steps.length)}',
                          child: ExcludeSemantics(child: Text(stepTitle, style: theme.textTheme.bodyLarge)),
                        ),
                        const Gap(12),
                        for (final (i, r) in refs.indexed) ...[
                          if (r.verse == 1) ChapterHeading(chapter: r.chapter, settings: settings),
                          // The Targum again, after the Hebrew of a verse read
                          // a third time among it.
                          if (kind == StepKind.targum && i > 0 && flow.thirdHebrewInTargum(chunk, refs[i - 1]))
                            hanging(LayerLabel(l.targumLabel)),
                          // The verse and what goes with it, highlighted
                          // together while Listen reads it.
                          SpeakingVerseMark(
                            active: r == speakingVerse,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                layerFor(r),
                                if (settings.showRashi &&
                                    kind != StepKind.rashi &&
                                    texts.rashi != null &&
                                    texts.rashi!.on(r).isNotEmpty) ...[
                                  const Gap(4),
                                  hanging(LayerLabel(l.rashiLabel)),
                                  rashi(texts.rashi!.on(r)),
                                ],
                              ],
                            ),
                          ),
                          if (texts.mikra.breaks[r] case final brk? when hebrewStep)
                            SectionGap(kind: brk, settings: settings)
                          else if (i < refs.length - 1)
                            const Gap(20),
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

/// What the reader sees once an aliyah is read (DESIGN_SYSTEM.md §6.23): a
/// divider whose hairlines draw outward from its lozenge, then the title, a
/// line about what comes next, and the way on. Once the parsha is read, it
/// says how the week stands and offers the haftarah.
class _FinishedPanel extends ConsumerStatefulWidget {
  const _FinishedPanel({
    required this.ctx,
    required this.aliyah,
    required this.justCompleted,
    required this.firstFocus,
    required this.onGoToAliyah,
  });

  final WeekContext ctx;
  final int aliyah;

  /// Whether this finish completed the parsha. Stepping once more through a
  /// parsha read already (weeks ago, say) earns nothing new, so the panel
  /// tells only how it stands.
  final bool justCompleted;

  /// For the first of its buttons, which the reader gives the focus.
  final FocusNode firstFocus;
  final ValueChanged<int> onGoToAliyah;

  @override
  ConsumerState<_FinishedPanel> createState() => _FinishedPanelState();
}

class _FinishedPanelState extends ConsumerState<_FinishedPanel> with SingleTickerProviderStateMixin {
  // The completion moment (§8), once: the divider's hairlines draw outward
  // over Motion.long, then the rest fades in over Motion.short.
  late final AnimationController _reveal = AnimationController(vsync: this, duration: Motion.long + Motion.short);
  late final Animation<double> _draw = CurvedAnimation(parent: _reveal, curve: Interval(0, _split, curve: Motion.decelerate));
  late final Animation<double> _fade = CurvedAnimation(parent: _reveal, curve: Interval(_split, 1, curve: Motion.standard));
  bool _started = false;

  static final _split = Motion.long.inMilliseconds / (Motion.long + Motion.short).inMilliseconds;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Under Reduce Motion it is simply there.
    if (Motion.of(context).reduced) {
      _reveal.value = 1;
    } else {
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  WeekContext get ctx => widget.ctx;

  /// The aliyah to continue with: the first after this one not yet read,
  /// then the first before it; null once the parsha is read. A preview
  /// records no reading, so it simply moves on to the next aliyah.
  int? _nextTarget(WeekProgress week) {
    final aliyah = widget.aliyah;
    if (!ctx.isOpen) return aliyah < kAliyot - 1 ? aliyah + 1 : null;
    for (final a in [for (var a = aliyah + 1; a < kAliyot; a++) a, for (var a = 0; a < aliyah; a++) a]) {
      if (!week.isAliyahDone(a)) return a;
    }
    return null;
  }

  /// The line for a reader who has read all that is planned for today and
  /// before, with the parsha still unfinished: when the next reading is, or
  /// on the plan's last day, a greeting for Shabbat (or the Yom Tov that
  /// comes first). Null while anything planned is still unread.
  String? _doneForToday(AppSettings settings) {
    final l = context.l10n;
    final today = ctx.today;
    final day = ctx.plan.dayFor(today);
    if (day == null || day.aliyot.isEmpty || !day.aliyot.every(ctx.progress.isAliyahDone)) return null;
    if (ctx.dueAliyot().isNotEmpty) return null;
    // The next day with reading left: aliyot read ahead leave their days
    // with none.
    final later = ctx.plan.days
        .where((d) => d.date > today && d.aliyot.any((a) => !ctx.progress.isAliyahDone(a)))
        .firstOrNull;
    if (later != null) {
      return later.date == today.addDays(1) ? l.todayReadingDone : l.todayReadingDoneOn(Names(context).weekday(later.date));
    }
    final tomorrow = today.addDays(1);
    final chag = !tomorrow.isShabbat &&
        JewishHolidays.isYomTov(HebrewDate.fromLocalDate(tomorrow), israel: settings.oneDayYomTov);
    final greeting = chag ? 'chag' : 'shabbat';
    return ctx.plan.shabbatAliyot.isEmpty ? l.erevShabbatDone(greeting) : l.erevShabbatDoneMorning(greeting);
  }

  /// How the finished parsha stands (on time, after Shabbat, or doubled up),
  /// with the streak where streaks are shown and the parsha was completed
  /// just now; null for any other standing.
  (WeekStatus, String)? _standing(AppSettings settings) {
    final l = context.l10n;
    final summary = ref.watch(streakSummaryProvider);
    final evaluation = summary.weeks.where((e) => e.plan.weekId == ctx.id).lastOrNull;
    if (evaluation == null) return null;
    // The streak is today's, and the grace day the week's: told only as they
    // are earned, not as a parsha read already is stepped through again.
    final streaks = settings.showStreaks && widget.justCompleted;
    final status = evaluation.status;
    final text = switch (status) {
      WeekStatus.onTime when streaks => [
          l.weekOnTime,
          l.parshaStreakLength(summary.parshaStreak),
          if (evaluation.earnedGrace) l.graceDayEarned,
        ].join(' · '),
      WeekStatus.onTime => l.weekOnTime,
      WeekStatus.late => streaks ? l.parshaDoneLateStreak : l.parshaDoneLate,
      WeekStatus.restored => streaks ? l.parshaDoneRestoredStreak : l.parshaDoneRestored,
      _ => null,
    };
    return text == null ? null : (status, text);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final type = SeferType.of(context);
    final settings = ref.watch(settingsProvider);
    final week = ctx.progress;
    final complete = week.isComplete;
    final next = _nextTarget(week);
    final haftarah = complete && (settings.haftarahEnabled || ctx.haftarahRequired) && week.haftarah == null;
    final doneForToday = complete || next == null ? null : _doneForToday(settings);
    final standing = complete ? _standing(settings) : null;
    final title = complete
        ? l.parshaDoneTitle(names.portion(ctx.portion, ashkenazi: settings.ashkenaziNames))
        : l.aliyahDoneTitle(names.aliyah(widget.aliyah));
    // What the reader's announcement says, where there is one; elsewhere
    // the title's live region says it.
    final spoken = complete
        ? l.parshaComplete(names.portion(ctx.portion, ashkenazi: settings.ashkenaziNames))
        : l.aliyahComplete(names.aliyah(widget.aliyah));
    final announces = MediaQuery.supportsAnnounceOf(context);
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;
    final marginalia = type.marginalia;

    // At most one Filled button (§6.5): the next aliyah, unless the day's
    // reading is done, when Done is, and continuing is a quiet Keep going.
    // The first button takes the focus.
    final buttons = <Widget>[];
    FocusNode? focus() => buttons.isEmpty ? widget.firstFocus : null;
    void done() => context.canPop() ? context.pop() : context.go('/today');
    Widget doneButton({required bool filled}) => filled
        ? FilledButton(
            focusNode: focus(),
            style: FilledButton.styleFrom(minimumSize: const Size(160, 52)),
            onPressed: done,
            child: Text(l.actionDone),
          )
        : TextButton(focusNode: focus(), onPressed: done, child: Text(l.actionDone));
    if (next != null && doneForToday == null) {
      buttons
        ..add(FilledButton.icon(
          focusNode: focus(),
          style: FilledButton.styleFrom(minimumSize: const Size(64, 52)),
          onPressed: () => widget.onGoToAliyah(next),
          icon: const Icon(Icons.chevron_right),
          iconAlignment: IconAlignment.end,
          label: Text(l.nextAliyahAction(names.aliyah(next))),
        ))
        ..add(doneButton(filled: false));
    } else if (next != null) {
      buttons
        ..add(doneButton(filled: true))
        ..add(TextButton(
          focusNode: focus(),
          onPressed: () => widget.onGoToAliyah(next),
          child: Text(l.keepGoingAliyah(names.aliyah(next))),
        ));
    } else {
      if (haftarah) {
        buttons.add(FilledButton.tonalIcon(
          focusNode: focus(),
          style: AppButtons.tonal(context),
          onPressed: () => replaceWithWeekPage(context, 'haftarah/${ctx.id}'),
          icon: const Icon(Icons.auto_stories_outlined),
          label: Text(l.readHaftarah),
        ));
      }
      buttons.add(doneButton(filled: !haftarah));
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _draw,
                builder: (context, _) => SeferDivider(width: SeferDivider.maxWidth, progress: _draw.value),
              ),
              const Gap(16),
              // Faded in together, but present for screen readers from the
              // start, so that the heading is there to be found.
              FadeTransition(
                opacity: _fade,
                alwaysIncludeSemantics: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      // Said by the reader's announcement where there is one,
                      // and elsewhere (on Android) as it appears.
                      liveRegion: !announces,
                      header: true,
                      headingLevel: 1,
                      child: Text(
                        title,
                        semanticsLabel: announces ? null : spoken,
                        textAlign: TextAlign.center,
                        style: (wide ? theme.textTheme.displaySmall : theme.textTheme.headlineMedium)
                            ?.copyWith(color: scheme.onSurface),
                      ),
                    ),
                    if (next != null) ...[
                      const Gap(8),
                      if (doneForToday != null) ...[
                        Text(doneForToday, textAlign: TextAlign.center, style: marginalia),
                        const Gap(4),
                      ],
                      Text(
                        l.nextAliyahLength(names.aliyah(next), ctx.aliyahVerses[next]),
                        textAlign: TextAlign.center,
                        style: marginalia,
                      ),
                    ],
                    if (standing case (final status, final text)) ...[
                      const Gap(8),
                      _StandingLine(status: status, text: text),
                    ],
                    const Gap(24),
                    for (final (i, button) in buttons.indexed) ...[
                      if (i > 0) const Gap(8),
                      button,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How a finished parsha stands: its status's icon, in its colour, and a
/// sentence (§6.23).
class _StandingLine extends StatelessWidget {
  const _StandingLine({required this.status, required this.text});

  final WeekStatus status;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    // The icon rides with the first word, so the line wraps as one sentence.
    return Text.rich(
      TextSpan(children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: Icon(
              WeekStatusBadge.icon(status),
              // Growing with the text, but never outweighing it.
              size: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3).scale(18),
              color: WeekStatusBadge.color(context, status),
            ),
          ),
        ),
        TextSpan(text: text),
      ]),
      textAlign: TextAlign.center,
      style: style,
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
    this.speakingVerse,
    required this.onTap,
    required this.onVerseTap,
    required this.onVerseOptions,
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

  /// The verse Listen is reading, by index: highlighted as focus mode's
  /// verse is, and kept in view.
  final int? speakingVerse;

  /// Called on any tap on the text, wherever it lands.
  final VoidCallback? onTap;
  final ValueChanged<int> onVerseTap;

  /// Opens a verse's options, from a long press anywhere in its block.
  final ValueChanged<VerseRef> onVerseOptions;
  final Widget? footer;

  /// Between one verse's block and the next, which with the blocks' insets
  /// sets their text 20 apart.
  static const _verseGap = 12.0;

  @override
  Widget build(BuildContext context) {
    final styles = ScriptureStyles(context, settings);
    final englishRashi = settings.secondReading == SecondReading.rashiEnglish;

    Widget verse(int i) {
      final r = flow.verses[i];
      final targeted = r == targetVerse;
      final speaking = speakingVerse == i;
      final dimmed = settings.focusMode && focusedVerse != null && focusedVerse != i && !speaking;
      // The mark of the verse opened at stands in for focus mode's own, which
      // stays off after the mark goes, until focus moves. The verse Listen
      // reads has it, in focus mode or not.
      final highlighted = (settings.focusMode && focusedVerse == i && !targeted && quietFocus != i) || speaking;
      final brk = texts.mikra.breaks[r];
      final rashi = settings.showRashi || settings.usesRashi ? texts.rashi?.on(r) ?? const <Comment>[] : const <Comment>[];
      final block = Center(
        key: verseKey(i),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: styles.maxLineWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // At each chapter's start, and at the aliyah's, to say where it
              // begins.
              if (r.verse == 1 || i == 0) ChapterHeading(chapter: r.chapter, settings: settings),
              VerseGroup(
                verse: r,
                highlighted: highlighted,
                onTap: settings.focusMode ? () => onVerseTap(i) : null,
                onLongPress: () => onVerseOptions(r),
                child: TargetVerseMark(
                  active: targeted,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ScriptureVerse(
                        verse: texts.mikra.verse(r),
                        kind: ScriptureKind.mikra,
                        settings: settings,
                        dimmed: dimmed,
                        onLongPress: () => onVerseOptions(r),
                        ownGestures: false,
                      ),
                      // Close beneath its verse, ruled off and without the
                      // verse's number again.
                      if (texts.onkelos != null) ...[
                        const Gap(2),
                        ScriptureVerse(
                          verse: texts.onkelos!.verse(r),
                          kind: ScriptureKind.targum,
                          settings: settings,
                          dimmed: dimmed,
                          secondary: true,
                          showNumber: false,
                          ruled: true,
                          onLongPress: () => onVerseOptions(r),
                          ownGestures: false,
                        ),
                      ],
                      if (settings.showTranslation && texts.english != null) ...[
                        const Gap(6),
                        TranslationVerse(
                          text: texts.english!.verse(r).readText,
                          number: r.verse,
                          settings: settings,
                          dimmed: dimmed,
                        ),
                      ],
                      if (rashi.isNotEmpty) ...[
                        const Gap(10),
                        RashiEyebrow(english: englishRashi, dimmed: dimmed),
                        const Gap(2),
                        RashiComments(comments: rashi, settings: settings, english: englishRashi, dimmed: dimmed),
                      ],
                    ],
                  ),
                ),
              ),
              // The aliyah's last verse is followed by its divider, which
              // marks the end: a section's mark too would be a second
              // ornament on the same break.
              if (brk != null && i < flow.verses.length - 1)
                SectionGap(kind: brk, settings: settings)
              else
                const Gap(_verseGap),
            ],
          ),
        ),
      );
      return FollowedVerse(active: speaking, child: block);
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
              // The aliyah's end, as a book ends a section.
              const Gap(12),
              const SeferDivider(),
              if (footer case final footer?) ...[const Gap(20), Center(child: footer)],
            ],
          ),
        ),
      ),
    );
  }
}
