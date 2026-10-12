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
import '../../ui/widgets/lines.dart' show dateHeldTogether;
import '../../ui/widgets/ornaments.dart' show Eyebrow, SeferDivider;
import '../../ui/widgets/progress_widgets.dart' show WeekStatusBadge;
import '../notes/domain/annotations.dart';
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
import 'whole_parsha.dart';

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

  /// The most the chrome around the text (the aliyah ribbon, the bars
  /// beneath the text and the step's title) grows with the system text:
  /// 200%, as WCAG 1.4.4 asks. Larger text goes to the scripture alone,
  /// which the chrome would otherwise crowd off a phone's screen. The app
  /// bar keeps to less (1.34, as Flutter's does).
  static const double chromeMaxTextScale = 2;

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

  /// The aliyah's position counts when it was opened (null if it was read):
  /// a chunk starts past the readings already done through it
  /// ([ReaderFlow.entryStep]), and Back from there returns to the chunk
  /// before.
  List<int>? _doneAtOpen;

  // Another aliyah was chosen: once the step it resumes at is known, it is
  // announced, as Next and Back announce theirs.
  bool _announceWhenPositioned = false;

  /// Focus mode's verse: its index among the verses the full text shows
  /// ([_textVerses]: in the whole parsha, the parsha's), or in the guided
  /// reader among the aliyah's, where the full text would pick it up.
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

  // Whether positioning the reader on an aliyah also places the full text:
  // at the verse opened at, or focus mode's verse at the reader's place.
  // Not when the whole parsha's text, scrolled to another aliyah, only
  // follows it.
  bool _placeText = true;

  // The verses of every aliyah, for the full text of the whole parsha, and
  // the week they are of.
  ParshaVerses? _parsha;
  String? _parshaOf;

  // One per aliyah of the whole parsha's text, for where each begins.
  final _aliyahKeys = List.generate(kAliyot, (_) => GlobalKey());

  // While the full text is scrolled to a place of the reader's choosing (an
  // aliyah, a verse), the aliyah shown is the one chosen, and doesn't follow
  // the scrolling until the reader scrolls themselves. Each such scroll has
  // its number, so that a later one takes over from it.
  bool _seeking = false;
  int _seek = 0;

  // Whether the aliyah shown is to follow the whole parsha's text once the
  // frame it has scrolled in is laid out.
  bool _followPending = false;

  // The verse Listen last reached, so that the whole parsha's text is
  // brought to it once as it moves on.
  int? _spokenVerse;

  // Whether the whole parsha's text is being brought to the place it opens
  // at, out of sight until it is there.
  bool _placing = false;

  late final TtsService _tts;

  // Listen, from its start until it ends or is stopped (DESIGN.md §3): the
  // verse being read, which is highlighted, and the player beneath the text.
  late final ListenController _listen;

  // Listen along's breath between one reading of the guided reader and the
  // next, and whether it is paused there.
  Timer? _listenOn;
  bool _listenHeld = false;

  // Listen pauses as the app is hidden, and as a call or another app's
  // audio takes over.
  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<void> _interruptions;

  // Whether the reader is shown: its tickers are off while another page
  // covers it, and its secondary animation runs forward as one comes over
  // it (only pages drive it, not sheets, menus or dialogs). Listen stops
  // while it isn't, as it does when the reader is left.
  bool _tickersOn = true;
  Animation<double>? _covering;

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
    _lifecycle = AppLifecycleListener(onHide: _pauseListening);
    _interruptions = _tts.interruptions.listen((_) {
      if (mounted) _pauseListening();
    });
    if (ref.read(settingsProvider).keepScreenOn) {
      WakelockPlus.enable().catchError((_) {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickersOn = TickerMode.valuesOf(context).enabled;
    final covering = ModalRoute.of(context)?.secondaryAnimation;
    if (covering != _covering) {
      _covering?.removeStatusListener(_coveringChanged);
      _covering = covering?..addStatusListener(_coveringChanged);
    }
    // After the frame: stopping sets state, as the player goes.
    WidgetsBinding.instance.addPostFrameCallback((_) => _stopIfHidden());
  }

  void _coveringChanged(AnimationStatus _) => _stopIfHidden();

  /// Stops Listen while another page covers the reader, as leaving it does.
  /// Sheets, menus and dialogs over it leave it be.
  void _stopIfHidden() {
    if (!mounted || !_listen.active) return;
    if (_onTop) return;
    _stopListening();
  }

  /// Whether no other page covers the reader.
  bool get _onTop => _tickersOn && (_covering?.isDismissed ?? true);

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_interruptions.cancel());
    _covering?.removeStatusListener(_coveringChanged);
    WakelockPlus.disable().catchError((_) {});
    _listenOn?.cancel();
    // The voice goes with the reader, unless another page's Listen has taken
    // it over.
    _listen.removeListener(_listenChanged);
    _listen.stop();
    _listen.dispose();
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
      _placeText = true;
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

  // --- The whole parsha --------------------------------------------------------

  /// Whether the full text shows the whole parsha.
  bool get _wholeParsha => _fullText && ref.read(settingsProvider).fullTextWholeParsha;

  /// The verses of every aliyah of [ctx]'s parsha.
  ParshaVerses _parshaFor(WeekContext ctx) {
    if (_parsha == null || _parshaOf != ctx.id) {
      final repo = ref.read(parshaRepositoryProvider);
      _parsha = ParshaVerses([for (var a = 0; a < kAliyot; a++) repo.aliyahVerses(ctx.portion, a)]);
      _parshaOf = ctx.id;
    }
    return _parsha!;
  }

  /// The verses the full text shows, by their index there: the aliyah's, or
  /// in the whole parsha every aliyah's.
  List<VerseRef> _textVerses(ReaderFlow flow) => _wholeParsha ? _parsha!.verses : flow.verses;

  /// The index, among the verses the full text shows, of the aliyah's first.
  int get _aliyahStart => _wholeParsha ? _parsha!.starts[_aliyah] : 0;

  /// The aliyah shown is now [a], as the whole parsha's text has come to it:
  /// the title and the ribbon name it, the menu marks it read, and the guided
  /// reader would open on it. Nothing else of the reader's place changes.
  /// Called within setState.
  void _followAliyah(int a) {
    if (a == _aliyah) return;
    _aliyah = a;
    _positioned = false;
    _finished = false;
    _completedOnVisit = false;
  }

  /// Aliyah [a]'s tab in the whole parsha: its heading is brought to the top
  /// of the text.
  void _showAliyah(int a) {
    _stopListening();
    setState(() {
      _followAliyah(a);
      _targetVerse = null;
      _quietFocus = null;
    });
    _seekAliyah(a);
  }

  /// The whole parsha's text has scrolled: once the frame has laid it out
  /// where it scrolled to (the verses built only as they come near, and the
  /// places of those beyond them reckoned again), the aliyah shown follows
  /// the one at its reading line, a quarter of the way down, unless the text
  /// is being scrolled to a place of the reader's choosing.
  void _textScrolled() {
    if (_followPending) return;
    _followPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followPending = false;
      if (!mounted || _seeking || !_wholeParsha || !_scroll.hasClients) return;
      final p = _scroll.position;
      final line = p.pixels + p.viewportDimension / 4;
      var shown = 0;
      for (var a = 1; a < kAliyot; a++) {
        final start = _aliyahOffset(a);
        if (start != null && start <= line) shown = a;
      }
      if (shown != _aliyah) setState(() => _followAliyah(shown));
    });
  }

  /// Where aliyah [a] begins in the whole parsha's text, as a scroll offset;
  /// null until it is laid out.
  double? _aliyahOffset(int a) {
    final sliver = _aliyahKeys[a].currentContext?.findRenderObject();
    if (sliver is! RenderSliver || sliver.geometry == null) return null;
    return sliver.constraints.precedingScrollExtent;
  }

  /// Scrolls the whole parsha's text to aliyah [a], its heading at the top,
  /// once the frame being built is laid out. Its verses are built only near
  /// the view, so the place of an aliyah far off is known only roughly until
  /// the text comes to it: it is moved again until it stays there.
  Future<void> _seekAliyah(int a) async {
    final seek = ++_seek;
    _seeking = true;
    try {
      for (var i = 0; i < 8; i++) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || seek != _seek || !_scroll.hasClients) return;
        // The first from the very top, with any notice above it.
        final start = a == 0 ? 0.0 : _aliyahOffset(a);
        if (start == null) return;
        final p = _scroll.position;
        final to = start.clamp(p.minScrollExtent, p.maxScrollExtent);
        if ((p.pixels - to).abs() < 0.5) return;
        _scroll.jumpTo(to);
      }
    } finally {
      if (seek == _seek) _seeking = false;
    }
  }

  /// Scrolls verse [i] of the full text [alignment] of the way down the
  /// text's view, once the frame being built is laid out, and says whether it
  /// got there. In the whole parsha, a verse far from the view is not yet
  /// built: the text is first moved to where it should be, reckoned from the
  /// verses that are, until it is; and as the verses built on the way are
  /// measured, moving it, it is brought there again until it stays.
  ///
  /// [onFound] is called once the verse is built, as it is scrolled to.
  Future<bool> _seekVerse(
    int i, {
    required double alignment,
    Duration duration = Duration.zero,
    VoidCallback? onFound,
  }) async {
    final seek = ++_seek;
    _seeking = true;
    var found = false;
    try {
      for (var attempt = 0; attempt < 8; attempt++) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || seek != _seek) return false;
        final verse = i < _verseKeys.length ? _verseKeys[i].currentContext : null;
        if (verse != null && verse.mounted) {
          final box = verse.findRenderObject();
          final viewport = box == null ? null : RenderAbstractViewport.maybeOf(box);
          if (found && viewport != null && _scroll.hasClients) {
            final p = _scroll.position;
            final to = viewport.getOffsetToReveal(box!, alignment).offset.clamp(p.minScrollExtent, p.maxScrollExtent);
            if ((p.pixels - to).abs() < 0.5) return true;
          }
          final first = !found;
          if (first) {
            found = true;
            onFound?.call();
          }
          await Scrollable.ensureVisible(
            verse,
            alignment: alignment,
            duration: first ? duration : Duration.zero,
            curve: Motion.standard,
          );
          if (!mounted || seek != _seek) return false;
          // One aliyah's verses are all built and measured: it is there.
          if (!_wholeParsha) return true;
          continue;
        }
        final to = _wholeParsha && _scroll.hasClients ? _estimatedOffset(i) : null;
        if (to == null) return found;
        final p = _scroll.position;
        _scroll.jumpTo(to.clamp(p.minScrollExtent, p.maxScrollExtent));
      }
      return found;
    } finally {
      if (seek == _seek) _seeking = false;
    }
  }

  /// Where verse [i] of the whole parsha should begin, as a scroll offset:
  /// reckoned from the verse built nearest it in its aliyah, by the height of
  /// the verses built; or, with none of its aliyah built, the aliyah's start.
  double? _estimatedOffset(int i) {
    final parsha = _parsha!;
    final aliyah = parsha.aliyahOf(i);
    (int, double)? nearest;
    var height = 0.0;
    var built = 0;
    for (var j = 0; j < _verseKeys.length; j++) {
      final box = _verseKeys[j].currentContext?.findRenderObject();
      final viewport = box == null ? null : RenderAbstractViewport.maybeOf(box);
      if (box is! RenderBox || !box.hasSize || viewport == null) continue;
      height += box.size.height;
      built++;
      if (parsha.aliyahOf(j) == aliyah && (nearest == null || (j - i).abs() < (nearest.$1 - i).abs())) {
        nearest = (j, viewport.getOffsetToReveal(box, 0).offset);
      }
    }
    if (nearest == null) return _aliyahOffset(aliyah);
    return nearest.$2 + (i - nearest.$1) * height / built;
  }

  /// Shows the whole parsha in the full text, or again one aliyah at a time,
  /// at the reader's place: focus mode's verse, or the aliyah.
  void _setWholeParsha(bool whole, ReaderFlow flow) {
    _stopListening();
    final start = _parsha!.starts[_aliyah];
    setState(() {
      // As with a change of mode, the mark of the verse opened at goes.
      _targetVerse = null;
      _quietFocus = null;
      if (_focusedVerse case final focused?) {
        final local = focused - start;
        _focusedVerse = whole ? start + focused : (local >= 0 && local < flow.verses.length ? local : null);
      }
      // The whole parsha's text, out of sight until it is at the reader's
      // place.
      _placing = whole;
    });
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(fullTextWholeParsha: whole));
    if (_focusedVerse case final focused?) {
      _revealVerse(focused, animate: false, onFound: _placed).whenComplete(_placed);
    } else if (whole) {
      _seekAliyah(_aliyah).whenComplete(_placed);
    } else {
      // The aliyah's text opens at its top, as when it is chosen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
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
    final duration = Motion.of(context).d(const Duration(milliseconds: 300));
    _seekVerse(i, alignment: 0.2, duration: duration, onFound: _placed).then((shown) {
      _placed();
      if (!shown || !mounted || !MediaQuery.supportsAnnounceOf(context)) return;
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
        _step = flow.entryStep(_chunk, _doneAtOpen);
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
      } else if (_step > 0 && (_chunk == 0 || _step != flow.entryStep(_chunk, _doneAtOpen))) {
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
      // In the whole parsha, the aliyah shown is the verse's.
      if (_wholeParsha) _followAliyah(_parsha!.aliyahOf(verse));
    });
    _revealVerse(verse, animate: true);
  }

  /// The first verse of the full text whose top is in view: in the whole
  /// parsha, below the heading held at the top ([topInView]).
  int _firstVerseInView(int count) {
    if (!_scroll.hasClients) return 0;
    for (var i = 0; i < count && i < _verseKeys.length; i++) {
      final box = _verseKeys[i].currentContext?.findRenderObject();
      if (box is RenderBox && RenderAbstractViewport.maybeOf(box) != null && topInView(box, _scroll.position) >= -1) {
        return i;
      }
    }
    return count - 1;
  }

  /// Scrolls verse [i] of the full text into view, nearer the top than the
  /// bottom, once this frame has laid it out.
  Future<bool> _revealVerse(int i, {required bool animate, VoidCallback? onFound}) => _seekVerse(
        i,
        alignment: 0.3,
        duration: animate ? Motion.of(context).d(Motion.medium) : Duration.zero,
        onFound: onFound,
      );

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
      _openVerseOptions(texts, flow.book, _textVerses(flow)[focused]);
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
    final reached = verse != _spokenVerse;
    _spokenVerse = verse;
    setState(() {
      if (verse != null && _fullText && ref.read(settingsProvider).focusMode) {
        _focusedVerse = verse;
        _quietFocus = null;
      }
    });
    // A verse of the whole parsha far from the view is not built, and so
    // can't bring itself into view as the voice reaches it (FollowedVerse):
    // it is sought, unless a finger is scrolling the text.
    if (reached && verse != null && _wholeParsha && _scroll.hasClients && !_scroll.position.isScrollingNotifier.value) {
      final built = verse < _verseKeys.length && _verseKeys[verse].currentContext != null;
      if (!built) _seekVerse(verse, alignment: 0.2, duration: Motion.of(context).d(Motion.medium));
    }
  }

  /// Starts Listen on what the reader shows, from [startVerse] (an index into
  /// the verses shown), or else from where the reader is: in the full
  /// text, the verse opened at, the verse focus mode is on, or the first in
  /// view; in the guided reader, the step's first verse. Until the voice is
  /// stopped, the verse it reads is highlighted and the player shows.
  Future<void> _startListening(ReaderTexts texts, ReaderFlow flow, {bool checkVoice = true, int? startVerse}) async {
    final l = context.l10n;
    final hasHebrew = checkVoice ? await _tts.hasHebrewVoice() : null;
    // The browser may take a moment to load its voices, and an engine to
    // bind: a page covered, or an app hidden, meanwhile starts nothing,
    // which nothing would then stop or pause.
    if (!mounted || !_onTop || appOutOfSight()) return;
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
    } else if (_listenHeld) {
      _listenOnNow();
    } else if (_listenOn == null && _listen.paused) {
      _listen.resume();
    } else {
      _pauseListening();
    }
  }

  /// Pauses Listen at the verse it reads, or in the breath between Listen
  /// along's readings; Play goes on from there. From the player, and as the
  /// app is hidden or a call comes.
  void _pauseListening() {
    if (!_listen.active) return;
    if (_listenOn != null) {
      _listenOn!.cancel();
      setState(() {
        _listenOn = null;
        _listenHeld = true;
      });
    } else if (!_listenHeld && !_listen.paused) {
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

  /// Stops Listen, and its speech.
  void _stopListening() {
    _listenOn?.cancel();
    _listenOn = null;
    _listenHeld = false;
    _listen.stop();
  }

  /// Where Listen starts in the full text: at the verse opened at, the verse
  /// focus mode is on, or else the first verse in view.
  int _listenStartVerse(ReaderFlow flow) {
    final verses = _textVerses(flow);
    if (_targetVerse case final target?) {
      final i = verses.indexOf(target);
      if (i >= 0) return i;
    }
    final focused = _focusedVerse;
    if (focused != null && ref.read(settingsProvider).focusMode) return focused;
    return _firstVerseInView(verses.length);
  }

  /// What Listen reads, verse by verse, each item with the index of its verse
  /// among those shown: in the full text (of the aliyah, or of the whole
  /// parsha), each verse and then its Targum, where it is shown; in the
  /// guided reader, the step shown, as the step shows it. The Divine Name is
  /// spoken as the reader has chosen.
  SpeechQueue _speechQueue(ReaderTexts texts, ReaderFlow flow, AppSettings s) {
    String hebrew(Verse v, {bool targum = false}) =>
        HebrewSpeech.spoken(v.readText, divineName: s.divineName, targum: targum);
    final queue = SpeechQueue(language: 'he-IL');
    if (_fullText || _finished) {
      for (final (i, r) in (_fullText ? _textVerses(flow) : flow.verses).indexed) {
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
          final parsha = _parshaFor(ctx);
          if (!_positioned) {
            final saved = ctx.progress.isAliyahDone(_aliyah) ? null : _savedPositions(ctx.progress, flow);
            _doneAtOpen = saved;
            final (c, st) = flow.resumeFrom(saved);
            _chunk = c.clamp(0, flow.chunks.length - 1);
            _step = st.clamp(0, flow.stepsFor(_chunk).length - 1);
            _positioned = true;
            if (_announceWhenPositioned && !_fullText) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _announceStep(flow));
            }
            _announceWhenPositioned = false;
            // Once for each aliyah opened: not as the whole parsha's text,
            // scrolled on to another aliyah, only follows it.
            if (_placeText) {
              _placeText = false;
              _placeFullText(flow, s);
            }
          }
          // Settings changes can reshape the flow; keep indices in range.
          if (_chunk >= flow.chunks.length) _chunk = flow.chunks.length - 1;
          if (_step >= flow.stepsFor(_chunk).length) _step = flow.stepsFor(_chunk).length - 1;
          _shown = (ctx, texts, flow);
          return _buildReader(context, ctx, texts, flow, parsha, s);
        },
      ),
    );
  }

  /// Places the full text as the reader opens on an aliyah: at the verse
  /// opened at, which is marked; in focus mode, at the reader's place, the
  /// first verse of the step the guided reader resumes at, as switching to
  /// the full text does; and the whole parsha's text at the aliyah. Called
  /// as the reader builds.
  void _placeFullText(ReaderFlow flow, AppSettings s) {
    final verses = _textVerses(flow);
    // The whole parsha's text is out of sight until it is at its place, so
    // that it is never seen elsewhere first.
    _placing = _wholeParsha;
    var revealing = false;
    if (_targetVerse case final target?) {
      final i = verses.indexOf(target);
      if (i < 0) {
        // Not in this aliyah (an old link, say): it opens as usual.
        _targetVerse = null;
      } else {
        // Focus mode reads around it, rather than around nothing.
        if (s.focusMode) _focusedVerse = _quietFocus = i;
        _revealTarget(i, flow.book, target);
        revealing = true;
      }
    }
    if (s.focusMode && _focusedVerse == null) {
      final verse = _aliyahStart + flow.chunks[_chunk].start;
      _focusedVerse = verse;
      if (_fullText && _targetVerse == null) {
        _revealVerse(verse, animate: false, onFound: _placed).whenComplete(_placed);
        revealing = true;
      }
    }
    if (_placing && !revealing) _seekAliyah(_aliyah).whenComplete(_placed);
  }

  /// The whole parsha's text is at the place it opens at, and is shown.
  void _placed() {
    if (mounted && _placing) setState(() => _placing = false);
  }

  /// The side padding of the reading column.
  static const _columnPadding = 20.0;

  /// The app bar's predicate while the text scrolls under something else
  /// with its own rule: the same function at every build, as
  /// [ScrolledUnderRule] asks.
  static bool _neverScrolledUnder(ScrollNotification _) => false;

  /// The reader's app bar (DESIGN_SYSTEM.md §6.2), in two lines: the parsha
  /// as an eyebrow over the aliyah, which the English UI names in Hebrew too
  /// ("Revi'i · רביעי"). Its title starts where the text does, and its
  /// actions end where the text does, however wide the window. Screen
  /// readers hear the title as the page names itself ("Bereshit · Revi'i").
  ///
  /// [scrolledUnder] is false while the aliyah ribbon, with its own rule, is
  /// what the text scrolls under. [columnWidth] is the text's measure: the
  /// reading column's, or wider in parallel columns.
  PreferredSizeWidget _appBar(
    BuildContext context,
    WeekContext ctx,
    AppSettings s, {
    List<Widget>? actions,
    bool scrolledUnder = true,
    double? columnWidth,
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
    final start = max(_columnPadding, (width - (columnWidth ?? ScriptureStyles(context, s).maxLineWidth)) / 2);
    final leading = homeLeading(context);
    final hasLeading = leading != null || (ModalRoute.canPopOf(context) ?? false);
    return ScrolledUnderRule(
      appBar: AppBar(
        leading: leading,
        toolbarHeight: height,
        // The inset goes before the title alone (as PageScaffold's does): as
        // titleSpacing it would be kept after it too, and a wide window would
        // leave the title no room beside the actions.
        titleSpacing: 0,
        actionsPadding: EdgeInsetsDirectional.only(end: start - _columnPadding),
        notificationPredicate: scrolledUnder ? defaultScrollNotificationPredicate : _neverScrolledUnder,
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
      ),
    );
  }

  Widget _buildReader(
    BuildContext context,
    WeekContext ctx,
    ReaderTexts texts,
    ReaderFlow flow,
    ParshaVerses parsha,
    AppSettings s,
  ) {
    final l = context.l10n;
    final isMac = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
    // What the reader has marked on each verse, which its number shows.
    final annotations = ref.watch(annotationsProvider);
    Annotation? marksOf(VerseRef r) => annotations[BookVerse(flow.book, r)];
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

    final whole = _fullText && s.fullTextWholeParsha;
    final verseCount = whole ? parsha.verses.length : flow.verses.length;
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
      // Focus mode's verse; while Listen reads, it is the verse being read,
      // which they move.
      if (_fullText && s.focusMode) ...{
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _listen.active ? _listenOnVerse() : _moveFocusedVerse(1, verseCount),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _listen.active ? listenBack() : _moveFocusedVerse(-1, verseCount),
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

    // On a wide screen the full text sets what goes with the Torah beside
    // it, in a wider column that the title, the ribbon and the player keep
    // to as well.
    final styles = ScriptureStyles(context, s);
    final pane = ScriptureStyles.paneWidth(context);
    final companion = texts.onkelos != null || (s.showTranslation && texts.english != null);
    final parallel = _fullText && styles.parallelColumns(pane, companion: companion);
    final columnWidth = styles.fullTextWidth(parallel: parallel);
    // A week not yet open, previewed: said at the top of the text, where it
    // scrolls away with it rather than squeeze it, and grows to twice its
    // size at most, as the rest of the chrome.
    final preview = ctx.isOpen
        ? null
        : MediaQuery.withClampedTextScaling(
            maxScaleFactor: ReaderScreen.chromeMaxTextScale,
            child: NoticeBanner(
              icon: Icons.visibility_outlined,
              // Its date whole: a line breaks after the weekday, if it must.
              text: l.previewNotOpen(dateHeldTogether(Names(context).dateLong(ctx.week.start))),
            ),
          );
    // Focus mode reads the full text alone: the overflow menu still switches
    // modes and marks the aliyah read.
    final showRibbon = !(_fullText && s.focusMode);
    final names = Names(context);

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
                // The text scrolls under the ribbon, or in the whole parsha
                // under its aliyah's heading, which have their own rules.
                scrolledUnder: !showRibbon && !whole,
                columnWidth: columnWidth,
                actions: [
                  IconButton(
                    tooltip: _listen.active ? l.stopListening : l.listen,
                    icon: Icon(_listen.active ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
                    onPressed: () => _listen.active ? _stopListening() : _startListening(texts, flow),
                  ),
                  IconButton(
                    tooltip: l.displaySettings,
                    icon: const Icon(Icons.text_format),
                    onPressed: () => showDisplaySheet(context, listenAlong: true, sideBySide: _fullText),
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
                            // The whole parsha's numbering of focus mode's
                            // verse, which the guided reader keeps as the
                            // aliyah's.
                            final start = parsha.starts[_aliyah];
                            if (_wholeParsha && _focusedVerse != null) {
                              final local = _focusedVerse! - start;
                              _focusedVerse = local >= 0 && local < flow.verses.length ? local : null;
                            }
                            _fullText = !_fullText;
                            // The mark of the verse opened at goes with a
                            // change of mode.
                            _targetVerse = null;
                            _quietFocus = null;
                            // Focus mode picks up the full text at the verse
                            // being read; a finished aliyah, at the verse it
                            // was at.
                            if (_fullText && s.focusMode && !_finished) {
                              _focusedVerse = _aliyahStart + flow.chunks[_chunk].start;
                            } else if (_wholeParsha && _focusedVerse != null) {
                              _focusedVerse = start + _focusedVerse!;
                            }
                            // The whole parsha's text, out of sight until it
                            // is at the aliyah.
                            _placing = _wholeParsha;
                          });
                          if (_fullText && _focusedVerse != null) {
                            _revealVerse(_focusedVerse!, animate: false, onFound: _placed).whenComplete(_placed);
                          } else if (_placing) {
                            _seekAliyah(_aliyah).whenComplete(_placed);
                          }
                        case 'parsha':
                          _setWholeParsha(!s.fullTextWholeParsha, flow);
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
                      SeferMenuItem(value: 'mode', child: Text(_fullText ? l.guidedMode : l.fullTextMode)),
                      if (_fullText)
                        SeferMenuItem(
                          value: 'parsha',
                          child: Text(s.fullTextWholeParsha ? l.oneAliyahAtATime : l.wholeParsha),
                        ),
                      if (ctx.isOpen && !ctx.progress.isAliyahDone(_aliyah))
                        SeferMenuItem(value: 'mark', child: Text(l.markAliyahRead)),
                      SeferMenuItem(value: 'week', child: Text(l.backToWeek)),
                      SeferMenuItem(value: 'keys', child: Text(l.keyboardShortcuts)),
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
                      MediaQuery.withClampedTextScaling(
                        maxScaleFactor: ReaderScreen.chromeMaxTextScale,
                        child: AliyahRibbon(
                          week: ctx.progress,
                          aliyahVerses: ctx.aliyahVerses,
                          selected: _aliyah,
                          // In the whole parsha, a tab scrolls to its aliyah.
                          onSelected: whole ? _showAliyah : _goToAliyah,
                          maxWidth: columnWidth,
                        ),
                      ),
                    Expanded(
                      child: _fullText
                          ? _FullText(
                              notice: preview,
                              aliyah: _aliyah,
                              verses: flow.verses,
                              texts: texts,
                              settings: s,
                              parallel: parallel,
                              width: columnWidth,
                              scroll: _scroll,
                              verseKey: _verseKey,
                              focusedVerse: _focusedVerse,
                              quietFocus: _quietFocus,
                              targetVerse: _targetVerse,
                              speakingVerse: _listen.verse,
                              onTap: _targetVerse == null ? null : () => setState(() => _targetVerse = null),
                              onVerseTap: (i) {
                                // While Listen reads, the focused verse is the
                                // one being read: a tap reads from the verse
                                // tapped.
                                if (_listen.active) {
                                  if (i != _listen.verse) _listen.moveTo(i);
                                  return;
                                }
                                setState(() {
                                  _focusedVerse = _focusedVerse == i ? null : i;
                                  _quietFocus = null;
                                  // In the whole parsha, the aliyah shown is
                                  // the verse's.
                                  if (whole && _focusedVerse != null) _followAliyah(parsha.aliyahOf(i));
                                });
                              },
                              onVerseOptions: (r) => _openVerseOptions(texts, flow.book, r),
                              marksOf: marksOf,
                              footer: (a) => ctx.isOpen && !ctx.progress.isAliyahDone(a)
                                  ? FilledButton.tonalIcon(
                                      style: AppButtons.tonal(context),
                                      icon: const Icon(Icons.check),
                                      label: Text(l.markAliyahRead),
                                      onPressed: () => _markAliyahRead(ctx, aliyah: a),
                                    )
                                  : null,
                              whole: whole
                                  ? _Whole(
                                      parsha: parsha,
                                      aliyahKey: (a) => _aliyahKeys[a],
                                      heading: (a) {
                                        final r = ctx.portion.aliyot[a];
                                        return HeldHeading(
                                          scroll: _scroll,
                                          start: () => _aliyahOffset(a),
                                          builder: (context, held) => AliyahHeader(
                                            aliyah: a,
                                            range: names.range(
                                              r.book,
                                              r.start.chapter,
                                              r.start.verse,
                                              r.end.chapter,
                                              r.end.verse,
                                            ),
                                            done: ctx.progress.isAliyahDone(a),
                                            width: columnWidth,
                                            padding: _columnPadding,
                                            held: held,
                                          ),
                                        );
                                      },
                                      hidden: _placing,
                                      onScrolled: _textScrolled,
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
                                  notice: preview,
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
                                  marksOf: marksOf,
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
    // Their labels grow to twice their size at most (chromeMaxTextScale).
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: ReaderScreen.chromeMaxTextScale,
      child: Builder(
        // So that the player's padding, taken from this context, keeps the
        // clamp.
        builder: (context) => Column(
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
        ),
      ),
    );
  }

  /// Marks [aliyah] read: the aliyah shown, or in the whole parsha the one
  /// whose button was pressed.
  void _markAliyahRead(WeekContext ctx, {int? aliyah}) {
    final a = aliyah ?? _aliyah;
    final today = ref.read(todayProvider);
    final wasComplete = ref.read(progressProvider).week(ctx.id).isComplete;
    ref.read(progressProvider.notifier).markAliyah(ctx.id, a, today);
    _justCompleted = !wasComplete && ref.read(progressProvider).week(ctx.id).isComplete;
    final verses = ref.read(parshaRepositoryProvider).aliyahVerseCount(ctx.portion, a);
    ref.read(progressProvider.notifier).savePosition(ctx.id, a, [verses, verses, verses]);
    hapticSuccess(ref);
    showStatus(context, context.l10n.markedRead);
    if (a == _aliyah) setState(() => _finished = true);
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
          // Half the end padding goes inside the list (_ShortcutList), where
          // its scrollbar stands clear of the keys.
          contentPadding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24 - _ShortcutList.scrollbarRoom, 24),
          content: _ShortcutList(
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

/// The shortcuts dialog's rows, which scroll where the dialog has no room
/// for them all (a phone, large text). The scrollbar then stays in sight, so
/// that a list cut off between two rows doesn't look complete.
class _ShortcutList extends StatefulWidget {
  const _ShortcutList({required this.children});

  final List<Widget> children;

  /// Between the keys and the dialog's edge, where the scrollbar runs.
  static const double scrollbarRoom = 12;

  @override
  State<_ShortcutList> createState() => _ShortcutListState();
}

class _ShortcutListState extends State<_ShortcutList> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsetsDirectional.only(end: _ShortcutList.scrollbarRoom),
          child: Column(mainAxisSize: MainAxisSize.min, children: widget.children),
        ),
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
    this.notice,
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
    required this.marksOf,
  });

  /// A notice over the pass track, which scrolls with the text: a week
  /// previewed before it opens.
  final Widget? notice;

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

  /// What the reader has marked on a verse: a bookmark, a note.
  final Annotation? Function(VerseRef) marksOf;

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
    ScriptureVerse verse(BookText text, VerseRef r, ScriptureKind kind, {bool secondary = false}) {
      final marks = marksOf(r);
      return ScriptureVerse(
        verse: text.verse(r),
        kind: kind,
        settings: settings,
        secondary: secondary,
        hangingNumber: true,
        onLongPress: () => onVerseOptions(r),
        bookmarked: marks?.bookmarked ?? false,
        hasNote: marks?.hasNote ?? false,
      );
    }

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
                if (notice case final notice?) ...[notice, const Gap(16)],
                // It stays as the step changes, and its bars fill as it does.
                // Its labels, and its check, grow to twice their size at
                // most, as the step's title beneath and the rest of the
                // chrome.
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: ReaderScreen.chromeMaxTextScale,
                  child: PassTrack(steps: steps, step: step),
                ),
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
                          child: ExcludeSemantics(
                            child: Text(
                              stepTitle,
                              style: theme.textTheme.bodyLarge,
                              // At most twice its size, as the rest of the
                              // chrome, so that the verse shows beneath it.
                              textScaler: MediaQuery.textScalerOf(context)
                                  .clamp(maxScaleFactor: ReaderScreen.chromeMaxTextScale),
                            ),
                          ),
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

/// What the full text of the whole parsha needs beyond one aliyah's.
class _Whole {
  const _Whole({
    required this.parsha,
    required this.aliyahKey,
    required this.heading,
    required this.hidden,
    required this.onScrolled,
  });

  final ParshaVerses parsha;

  /// The key of each aliyah's part of the text, which finds where it begins.
  final GlobalKey Function(int aliyah) aliyahKey;

  /// Each aliyah's heading, which stays at the top while it is read.
  final Widget Function(int aliyah) heading;

  /// Whether the text is out of sight, while it is brought to the place it
  /// opens at.
  final bool hidden;

  /// Called as the text scrolls.
  final VoidCallback onScrolled;
}

/// The full text: the aliyah's verses, or with [whole] the whole parsha's,
/// aliyah after aliyah, verse by verse with each layer interleaved. In
/// [parallel] columns, on a wide screen, the Targum (or the translation)
/// stands beside each verse rather than beneath it.
class _FullText extends StatelessWidget {
  const _FullText({
    this.notice,
    required this.aliyah,
    required this.verses,
    required this.texts,
    required this.settings,
    required this.parallel,
    required this.width,
    required this.scroll,
    required this.verseKey,
    required this.focusedVerse,
    this.quietFocus,
    required this.targetVerse,
    this.speakingVerse,
    required this.onTap,
    required this.onVerseTap,
    required this.onVerseOptions,
    required this.marksOf,
    required this.footer,
    this.whole,
  });

  /// The aliyah shown, and its verses, unless the whole parsha is.
  final int aliyah;
  final List<VerseRef> verses;

  final ReaderTexts texts;
  final AppSettings settings;
  final bool parallel;

  /// The text's measure.
  final double width;
  final ScrollController scroll;

  /// The key of each verse's block, by its index among the verses shown,
  /// for scrolling it into view.
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

  /// What the reader has marked on a verse: a bookmark, a note.
  final Annotation? Function(VerseRef) marksOf;

  /// What ends an aliyah's text, after its divider: the button that marks
  /// it read, while it isn't.
  final Widget? Function(int aliyah) footer;

  /// The whole parsha, when it is shown.
  final _Whole? whole;

  /// A notice at the top of the text, which scrolls with it: a week
  /// previewed before it opens.
  final Widget? notice;

  /// Between one verse's block and the next, which with the blocks' insets
  /// sets their text 20 apart.
  static const _verseGap = 12.0;

  /// The page's side padding, and around the text at its top and end.
  static const _side = 20.0;

  /// [child] in the reading column, as a verse's block is set.
  Widget _column(Widget child) => Center(
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: width), child: child),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final englishRashi = settings.secondReading == SecondReading.rashiEnglish;
    final whole = this.whole;

    // Verse [i] of those shown, [r], with all that goes with it. The first of
    // an aliyah is headed by its chapter, and in parallel columns by the
    // columns' names; the last ends at the aliyah's divider.
    // While Listen reads, the verse being read is focus mode's verse, and the
    // only one highlighted.
    final focused = speakingVerse ?? focusedVerse;
    Widget verse(int i, VerseRef r, {required bool first, required bool last}) {
      final targeted = r == targetVerse;
      final speaking = speakingVerse == i;
      final dimmed = settings.focusMode && focused != null && focused != i;
      // The mark of the verse opened at stands in for focus mode's own, which
      // stays off after the mark goes, until focus moves. The verse Listen
      // reads has it, in focus mode or not.
      final highlighted = (settings.focusMode && focused == i && !targeted && quietFocus != i) || speaking;
      final brk = texts.mikra.breaks[r];
      final rashi = settings.showRashi || settings.usesRashi ? texts.rashi?.on(r) ?? const <Comment>[] : const <Comment>[];
      final marks = marksOf(r);
      final focusTap = settings.focusMode ? () => onVerseTap(i) : null;
      final mikra = ScriptureVerse(
        verse: texts.mikra.verse(r),
        kind: ScriptureKind.mikra,
        settings: settings,
        dimmed: dimmed,
        onLongPress: () => onVerseOptions(r),
        ownGestures: false,
        onFocusTap: focusTap,
        bookmarked: marks?.bookmarked ?? false,
        hasNote: marks?.hasNote ?? false,
      );
      // Without the verse's number again: beneath it, ruled off; beside it,
      // on its line.
      final targum = texts.onkelos == null
          ? null
          : ScriptureVerse(
              verse: texts.onkelos!.verse(r),
              kind: ScriptureKind.targum,
              settings: settings,
              dimmed: dimmed,
              secondary: true,
              showNumber: false,
              ruled: !parallel,
              onLongPress: () => onVerseOptions(r),
              ownGestures: false,
              onFocusTap: focusTap,
            );
      final translation = settings.showTranslation && texts.english != null
          ? TranslationVerse(text: texts.english!.verse(r).readText, number: r.verse, settings: settings, dimmed: dimmed)
          : null;
      final commentary = rashi.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RashiEyebrow(english: englishRashi, dimmed: dimmed),
                const Gap(2),
                RashiComments(comments: rashi, settings: settings, english: englishRashi, dimmed: dimmed),
              ],
            );
      final beside = parallel ? targum ?? translation : null;
      final Widget content = beside != null
          // The Targum beside the verse, and the translation (where the
          // Targum isn't it) and Rashi after the verse in its column.
          ? ParallelVerse(
              torah: mikra,
              beside: beside,
              below: [
                if (translation != null && beside != translation)
                  Padding(padding: const EdgeInsets.only(top: 6), child: translation),
                if (commentary != null) Padding(padding: const EdgeInsets.only(top: 10), child: commentary),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                mikra,
                // Close beneath its verse.
                if (targum != null) ...[const Gap(2), targum],
                if (translation != null) ...[const Gap(6), translation],
                if (commentary != null) ...[const Gap(10), commentary],
              ],
            );
      final block = Center(
        key: verseKey(i),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (first && beside != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ParallelHeading(
                    torah: l.mikraLabel,
                    beside: beside == targum ? l.targumLabel : l.translationLabel,
                    besideDirection: beside == targum ? TextDirection.rtl : TextDirection.ltr,
                  ),
                ),
              // At each chapter's start, and at the aliyah's, to say where it
              // begins: in the whole parsha, beneath the aliyah's heading.
              if (r.verse == 1 || first)
                ChapterHeading(chapter: r.chapter, settings: settings, headingLevel: whole == null ? 2 : 3),
              VerseGroup(
                verse: r,
                highlighted: highlighted,
                onTap: focusTap,
                onLongPress: () => onVerseOptions(r),
                child: TargetVerseMark(active: targeted, child: content),
              ),
              // The aliyah's last verse is followed by its divider, which
              // marks the end: a section's mark too would be a second
              // ornament on the same break.
              if (brk != null && !last) SectionGap(kind: brk, settings: settings) else const Gap(_verseGap),
            ],
          ),
        ),
      );
      return FollowedVerse(active: speaking, child: block);
    }

    // The aliyah's end, as a book ends a section: its divider, and the
    // button that marks it read.
    List<Widget> end(int aliyah) => [
          const Gap(12),
          const SeferDivider(),
          if (footer(aliyah) case final footer?) ...[
            const Gap(20),
            Center(child: whole == null ? footer : _InViewWhenFocused(child: footer)),
          ],
        ];

    // With no bottom bar beneath it, its end clears the gesture bar.
    final bottom = 32 + MediaQuery.paddingOf(context).bottom;

    if (whole == null) {
      return TapObserver(
        onTap: onTap,
        child: Scrollbar(
          controller: scroll,
          // Every verse is built (an aliyah has 72 at most), so that any of
          // them can be scrolled to, and Tab reaches the button at the end.
          child: SingleChildScrollView(
            controller: scroll,
            padding: EdgeInsets.fromLTRB(_side, 8, _side, bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (notice case final notice?) ...[_column(notice), const Gap(8)],
                for (final (i, r) in verses.indexed) verse(i, r, first: i == 0, last: i == verses.length - 1),
                ...end(aliyah),
              ],
            ),
          ),
        ),
      );
    }

    // The whole parsha, up to 244 verses: each aliyah under its heading,
    // which stays at the top while it is read, and its verses built only as
    // they come near the view.
    final parsha = whole.parsha;
    final last = parsha.aliyot.length - 1;
    return TapObserver(
      onTap: onTap,
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) {
          if (n.depth == 0) whole.onScrolled();
          return false;
        },
        child: Opacity(
          opacity: whole.hidden ? 0 : 1,
          child: Scrollbar(
            controller: scroll,
            child: CustomScrollView(
              controller: scroll,
              slivers: [
                if (notice case final notice?)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(_side, 8, _side, 8),
                    sliver: SliverToBoxAdapter(child: _column(notice)),
                  ),
                for (final (a, aliyot) in parsha.aliyot.indexed)
                  SliverMainAxisGroup(
                    key: whole.aliyahKey(a),
                    slivers: [
                      PinnedHeaderSliver(child: whole.heading(a)),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(_side, 8, _side, 0),
                        sliver: SliverList.builder(
                          itemCount: aliyot.length,
                          itemBuilder: (context, j) => verse(
                            parsha.starts[a] + j,
                            aliyot[j],
                            first: j == 0,
                            last: j == aliyot.length - 1,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(_side, 0, _side, a == last ? bottom : 40),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: end(a)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps [child] in view while it has the keyboard focus, in the whole
/// parsha's text, whose verses are built only as they come near the view.
/// Tab brings a button far down the parsha into view by where it was
/// reckoned to be; once the verses before it are built and its place is
/// known, it is brought into view again.
class _InViewWhenFocused extends StatefulWidget {
  const _InViewWhenFocused({required this.child});

  final Widget child;

  @override
  State<_InViewWhenFocused> createState() => _InViewWhenFocusedState();
}

class _InViewWhenFocusedState extends State<_InViewWhenFocused> {
  int _tries = 0;

  void _focusChanged(bool focused) {
    if (!focused) return;
    _tries = 0;
    _keepInView();
  }

  void _keepInView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ++_tries > 4) return;
      final box = context.findRenderObject();
      final viewport = box == null ? null : RenderAbstractViewport.maybeOf(box);
      final position = Scrollable.maybeOf(context)?.position;
      if (box is! RenderBox || !box.hasSize || viewport == null || position == null) return;
      // The scroll offsets that set its top at the top of the view, and its
      // foot at the foot: between them, it is wholly in view.
      final top = viewport.getOffsetToReveal(box, 0).offset;
      final foot = viewport.getOffsetToReveal(box, 1).offset;
      if (position.pixels <= top + 0.5 && position.pixels >= foot - 0.5) return;
      Scrollable.ensureVisible(
        context,
        alignmentPolicy: position.pixels > top
            ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
            : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      _keepInView();
    });
  }

  @override
  Widget build(BuildContext context) =>
      Focus(canRequestFocus: false, skipTraversal: true, onFocusChange: _focusChanged, child: widget.child);
}
