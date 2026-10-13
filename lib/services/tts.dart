import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// The speech rate Listen reads at unless the reader sets another, which the
/// player and Settings call normal (speechRateLabel). Rates are on the
/// setting's scale, 0.1 to 1.0, on which the engines' own normal pace is 0.5
/// (see [TtsService.webEngine]): a little slower, for following the text.
const kDefaultSpeechRate = 0.45;

/// Text-to-speech for listening to the text (an aid, not a substitute for
/// reading). Hebrew voices are used for both the Hebrew and the Aramaic.
///
/// It speaks one utterance at a time ([speak]), or a queue of them, one for
/// each layer of each verse, that can be paused, resumed and moved through
/// verse by verse ([speakQueue]).
class TtsService {
  /// Speaks through [engine], by default the platform's.
  TtsService({@visibleForTesting FlutterTts? engine}) : _tts = engine ?? FlutterTts() {
    _tts.setStartHandler(() => _speaking = true);
    _tts.setCompletionHandler(() {
      _engineStopped(spokenToEnd: true);
      // Once nothing follows it (another item of a queue, or the next
      // reading of Listen along), the audio session ends.
      _releaseAudioSessionSoon();
    });
    _tts.setCancelHandler(() {
      _engineStopped();
      _releaseAudioSessionSoon();
    });
    _tts.setErrorHandler((_) {
      _engineStopped();
      _releaseAudioSessionSoon();
    });
    _sessionOwner = this;
    audioSessionChannel.setMethodCallHandler(_audioSessionCall);
  }

  /// The audio session that speech holds while it lasts, on iOS
  /// (ios/Runner/AppDelegate.swift) and Android (MainActivity.kt): the app
  /// asks to 'activate' it (Android) and to 'deactivate' it, and the
  /// platform tells of 'focusLost' as a call or another app's audio takes
  /// over ([interruptions]).
  @visibleForTesting
  static const audioSessionChannel = MethodChannel('shnayim_mikrah/audio_session');

  // The service the platform's calls go to: the latest made.
  static TtsService? _sessionOwner;

  /// How long after speech stops the audio session is ended, unless speech
  /// starts again meanwhile.
  @visibleForTesting
  static Duration releaseDelay = const Duration(milliseconds: 300);

  /// How long after a queue is spoken to its end the audio session is
  /// ended: longer than Listen along's breath between readings, whose next
  /// queue keeps it.
  @visibleForTesting
  static Duration finishedReleaseDelay = const Duration(seconds: 1);

  /// How long, at most, the next utterance waits for the engine to report
  /// the one it stopped as stopped (see [_halt]).
  @visibleForTesting
  static Duration settleTimeout = const Duration(milliseconds: 250);

  /// Whether the engine is the browser's SpeechSynthesis, which takes 1 as
  /// the voice's normal speed: it is given twice the rate, as flutter_tts
  /// itself doubles the rate on Android and adds 0.5 to it on Windows (and
  /// iOS takes 0.5 as normal), so that a rate sounds the same everywhere.
  ///
  /// The browser also loads its voices a moment after the page opens.
  @visibleForTesting
  static bool webEngine = kIsWeb;

  /// How many times, and how far apart, the browser's voices are looked for
  /// while it loads them (see [_webVoicesLoaded]).
  static const _webVoiceLooks = 15;
  static const _webVoiceLookInterval = Duration(milliseconds: 100);

  final FlutterTts _tts;

  /// The engine has reported an utterance started, and not yet stopped.
  bool _speaking = false;

  Completer<bool>? _utterance;

  // A Hebrew voice has been found. Only that is kept: one may be installed
  // later in the session, or (on the web) be loaded a moment later.
  bool _hebrewFound = false;

  // The browser has loaded its voices; or it has once been waited for in
  // vain, after which they are looked for again but not waited for.
  bool _webVoicesReady = false;
  bool _webVoicesWaited = false;

  bool _disposed = false;
  Timer? _release;

  // The audio session is ready for speech. On iOS, its category is set,
  // once for the run: the engine activates the session as it speaks. On
  // Android, the app holds audio focus, from the first utterance until
  // speech has stopped ([_releaseAudioSessionSoon]).
  bool _audioSessionReady = false;

  final _interruptions = StreamController<void>.broadcast();

  // The engine has been asked to speak, and hasn't yet reported the
  // utterance finished, cancelled or failed.
  bool _engineBusy = false;
  Completer<void>? _engineSettled;

  // Changes with every utterance asked for and every stop, so that an
  // utterance still being prepared when another is asked for, or speech is
  // stopped, is never spoken.
  int _generation = 0;

  // Utterances asked for that are waiting for the one before to stop.
  int _preparing = 0;

  void _set<T>(ValueNotifier<T> notifier, T value) {
    if (!_disposed) notifier.value = value;
  }

  /// The engine has reported the utterance finished ([spokenToEnd]),
  /// cancelled or failed.
  void _engineStopped({bool spokenToEnd = false}) {
    _engineBusy = false;
    _engineSettled?.complete();
    _engineSettled = null;
    _done(spokenToEnd: spokenToEnd);
  }

  void _done({bool spokenToEnd = false}) {
    _speaking = false;
    _utterance?.complete(spokenToEnd);
    _utterance = null;
  }

  /// Whether a Hebrew voice is installed. Null if it can't be determined,
  /// as while the browser hasn't loaded its voices.
  ///
  /// Only a voice found is remembered: asked again after none was, it looks
  /// again, so that one installed meanwhile is found.
  Future<bool?> hasHebrewVoice() async {
    if (_hebrewFound) return true;
    if (webEngine) {
      // From the browser's list as it is now: the plugin answers
      // isLanguageAvailable from the first list it saw, and so never finds
      // a voice the browser loads later (Edge's online voices come a moment
      // after its own) or one installed while the page is open.
      final voices = await _webVoices();
      if (voices == null) return null;
      return _hebrewFound = voices.any((v) => _isHebrew('${v is Map ? v['locale'] : v}'));
    }
    bool available;
    try {
      final answer = await _tts.isLanguageAvailable('he-IL');
      available = answer == true || answer == 1;
    } catch (_) {
      try {
        final langs = (await _tts.getLanguages as List?)?.cast<Object?>() ?? const [];
        available = langs.any((l) => _isHebrew('$l'));
      } catch (_) {
        return null;
      }
    }
    return _hebrewFound = available;
  }

  /// Whether [locale] ("he-IL", or Android's old "iw") is Hebrew's.
  static bool _isHebrew(String locale) {
    final l = locale.toLowerCase();
    return l.startsWith('he') || l.startsWith('iw');
  }

  /// Whether the browser has loaded its voices (see [_webVoices]). Never
  /// throws.
  Future<bool> _webVoicesLoaded() async => _webVoicesReady || await _webVoices() != null;

  /// The browser's voices, read afresh; null while it has loaded none,
  /// waiting a second and a half at most for them the first time:
  /// Chromium's list is empty until a moment after the page opens, and until
  /// then the engine can neither pick the voice for an utterance's language
  /// nor say whether there is one. Never throws.
  Future<List<Object?>?> _webVoices() async {
    final looks = _webVoicesReady || _webVoicesWaited ? 1 : _webVoiceLooks;
    try {
      for (var i = 0; i < looks; i++) {
        if (i > 0) await Future<void>.delayed(_webVoiceLookInterval);
        final voices = await _tts.getVoices;
        if (voices is List && voices.isNotEmpty) {
          _webVoicesReady = true;
          return voices.cast<Object?>();
        }
      }
    } catch (_) {
      return null;
    }
    _webVoicesWaited = true;
    return null;
  }

  /// Speaks [text], stopping whatever is being spoken first, and completes
  /// when it is finished or stopped: with true if it was spoken to its end.
  /// Throws if the engine can't speak at all.
  Future<bool> speak(String text, {required String language, double rate = kDefaultSpeechRate}) async {
    final generation = ++_generation;
    _preparing++;
    try {
      await _halt();
    } finally {
      _preparing--;
    }
    if (generation != _generation) {
      // Another utterance was asked for, or speech stopped, meanwhile: the
      // audio session goes, unless speech starts again.
      _releaseAudioSessionSoon();
      return false;
    }
    final c = _utterance = Completer<bool>();
    try {
      await _prepareAudioSession();
      // The browser picks the language's voice from those it has loaded. A
      // stop meanwhile is seen below, before anything is spoken.
      if (webEngine) await _webVoicesLoaded();
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(webEngine ? rate * 2 : rate);
      if (!kIsWeb) await _tts.awaitSpeakCompletion(false);
      if (generation == _generation) {
        _engineBusy = true;
        final result = await _tts.speak(text);
        if (result != 1 && result != null && result != true && identical(_utterance, c)) {
          // Refused (a broken or unbound engine): no handler will report
          // it, so the audio focus taken for it is given up here.
          _engineStopped();
          _releaseAudioSessionSoon();
        }
      } else {
        // Stopped, or overtaken, while the session was being readied for it.
        _releaseAudioSessionSoon();
      }
    } catch (_) {
      // Unless another utterance has taken its place meanwhile.
      if (identical(_utterance, c)) _engineStopped();
      _releaseAudioSessionSoon();
      rethrow;
    }
    return c.future;
  }

  /// Stops the utterance being spoken, if there is one, and waits a moment
  /// for the engine to report it stopped. The engines report it a little
  /// later (as cancelled, or on the web as failed), and taken for the next
  /// utterance's report it would end that one before it was heard; the web
  /// engine also ignores an utterance asked for before it has stopped.
  ///
  /// An engine that isn't speaking isn't told to stop: Windows reports a
  /// cancel even then, which would arrive during the next utterance and end
  /// it. An utterance still being prepared needs no stop: it is never
  /// spoken, as another has been asked for, or speech stopped, meanwhile.
  Future<void> _halt() async {
    if (!_engineBusy && !_speaking) {
      if (_utterance != null) {
        _done();
        _releaseAudioSessionSoon();
      }
      return;
    }
    // Already being stopped, for an utterance asked for a moment ago.
    final stopping = _engineSettled != null;
    final settled = _engineSettled ??= Completer<void>();
    if (!stopping) {
      try {
        await _tts.stop();
      } catch (_) {}
    }
    _done();
    _releaseAudioSessionSoon();
    // An engine that never reports it is taken to have stopped.
    await settled.future.timeout(settleTimeout, onTimeout: () {
      if (identical(_engineSettled, settled)) {
        _engineBusy = false;
        _engineSettled = null;
      }
    });
  }

  /// Readies the audio session for speech, on the first Listen rather than
  /// at startup, so that opening the reader never ducks the user's music:
  /// other audio ducks while speaking and comes back up after.
  ///
  /// On iOS, speech is silenced by the Silent switch unless the session is
  /// for playback. The engine would end the session after each utterance it
  /// finishes, and so after each verse: music would come back up and be
  /// ducked again, and a podcast be told it may resume and then be
  /// interrupted, verse by verse. The session is ended here instead, once
  /// speech has stopped ([_releaseAudioSessionSoon]).
  ///
  /// On Android, the app takes audio focus itself, for the same reason,
  /// rather than have the engine take it for each utterance: music ducks
  /// beneath speech, and a call or another app's audio taking focus over is
  /// told as an interruption ([interruptions]).
  Future<void> _prepareAudioSession() async {
    if (kIsWeb || _audioSessionReady) return;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        try {
          await _tts.autoStopSharedSession(false);
          final result = await _tts.setIosAudioCategory(
            IosTextToSpeechAudioCategory.playback,
            [
              IosTextToSpeechAudioCategoryOptions.duckOthers,
              IosTextToSpeechAudioCategoryOptions.interruptSpokenAudioAndMixWithOthers,
            ],
            IosTextToSpeechAudioMode.spokenAudio,
          );
          // The plugin reports a failure as 0, or as null, rather than
          // throwing: tried again on the next Listen.
          _audioSessionReady = result == 1;
        } catch (_) {
          // Speech still works; only the Silent switch silences it.
        }
      case TargetPlatform.android:
        try {
          // Refused during a call, say: speech goes ahead, and focus is asked
          // for again with the next utterance.
          _audioSessionReady = await audioSessionChannel.invokeMethod<bool>('activate') ?? false;
        } catch (_) {
          // Speech still works; other audio just isn't ducked.
        }
      default:
    }
  }

  /// Once speech has stopped (finished, stopped, failed or paused), ends the
  /// audio session readied for it: music it ducked comes back up, and on iOS
  /// spoken audio it interrupted (a podcast) is told it may resume. After
  /// [releaseDelay] ([after]), so that the session isn't ended under speech
  /// that starts again meanwhile: a new Listen, the next verse, or the next
  /// reading of Listen along. A queue playing holds it between its items.
  void _releaseAudioSessionSoon({Duration? after}) {
    if (!_audioSessionReady || _disposed) return;
    _release?.cancel();
    _release = Timer(after ?? releaseDelay, () {
      if (_utterance != null || _preparing > 0 || (_queueEnd != null && !paused.value)) return;
      // Android's focus, once given up, is asked for again; iOS's category
      // stays set.
      if (defaultTargetPlatform == TargetPlatform.android) _audioSessionReady = false;
      unawaited(audioSessionChannel.invokeMethod<bool>('deactivate').then((_) {}, onError: (Object _) {}));
    });
  }

  /// Tells of a call, or another app's audio, taking over from speech, as
  /// the platform reports it: the page listening pauses its Listen there.
  Stream<void> get interruptions => _interruptions.stream;

  Future<Object?> _audioSessionCall(MethodCall call) async {
    if (call.method == 'focusLost' && !_disposed) _interruptions.add(null);
    return null;
  }

  /// Stops speech, and the queue if one is speaking. Never throws: a
  /// platform without a speech engine has nothing to stop.
  Future<void> stop() async {
    _endQueue(completed: false);
    await _silence();
  }

  Future<void> _silence() async {
    _generation++;
    await _halt();
  }

  // --- A queue of utterances --------------------------------------------------

  /// The item of the queue being spoken, or paused at; null while no queue
  /// is.
  final ValueNotifier<int?> currentIndex = ValueNotifier(null);

  /// Whether the queue is paused at [currentIndex].
  final ValueNotifier<bool> paused = ValueNotifier(false);

  /// Which queue is the latest, so that its owner can tell it from another
  /// one: each [speakQueue] takes the next number.
  int get queueId => _queueId;
  int _queueId = 0;

  List<String> _queue = const [];
  List<int> _groups = const [];
  String _queueLanguage = 'he-IL';
  double _queueRate = kDefaultSpeechRate;
  Completer<bool>? _queueEnd;

  // Changes whenever the queue is paused, moved, stopped or replaced, which
  // ends the loop speaking it.
  int _queueToken = 0;

  /// Speaks [items] one after another from [startAt], and completes with
  /// true once the last has been spoken, or false if the queue is stopped or
  /// replaced first (or has no items). While it is paused, it waits. It
  /// completes with an error if the engine can't speak.
  ///
  /// [groups] gives the group each item belongs to (a verse, whose Mikrah and
  /// Targum are two items), which [next] and [previous] move between; by
  /// default each item is a group of its own. A group's items are adjacent.
  Future<bool> speakQueue(
    List<String> items, {
    required String language,
    double rate = kDefaultSpeechRate,
    int startAt = 0,
    List<int>? groups,
  }) {
    assert(groups == null || groups.length == items.length);
    _endQueue(completed: false);
    _queueId++;
    if (items.isEmpty) return Future.value(false);
    _queue = List.unmodifiable(items);
    _groups = List.unmodifiable(groups ?? [for (var i = 0; i < items.length; i++) i]);
    _queueLanguage = language;
    _queueRate = rate;
    final end = _queueEnd = Completer<bool>();
    unawaited(_play(startAt.clamp(0, items.length - 1)));
    return end.future;
  }

  Future<void> _play(int from) async {
    final token = ++_queueToken;
    _set(paused, false);
    for (var i = from; i < _queue.length; i++) {
      _set(currentIndex, i);
      final bool spokenToEnd;
      try {
        spokenToEnd = await speak(_queue[i], language: _queueLanguage, rate: _queueRate);
      } catch (e, s) {
        if (token == _queueToken) _endQueue(completed: false, error: e, stack: s);
        return;
      }
      // Paused, moved, stopped or replaced meanwhile.
      if (token != _queueToken) return;
      if (!spokenToEnd) {
        // Interrupted from outside (by another app's audio, or a call): held
        // where it was, to go on from there.
        _queueToken++;
        _set(paused, true);
        return;
      }
    }
    _endQueue(completed: true);
  }

  void _endQueue({required bool completed, Object? error, StackTrace? stack}) {
    _queueToken++;
    _queue = const [];
    _groups = const [];
    _set(currentIndex, null);
    _set(paused, false);
    final end = _queueEnd;
    _queueEnd = null;
    if (end == null) return;
    _releaseAudioSessionSoon(after: completed ? finishedReleaseDelay : null);
    if (error != null) {
      end.completeError(error, stack);
    } else {
      end.complete(completed);
    }
  }

  /// Pauses the queue at the item being spoken, which [resume] speaks again
  /// from its start.
  Future<void> pause() async {
    if (currentIndex.value == null || paused.value) return;
    _queueToken++;
    _set(paused, true);
    await _silence();
    _releaseAudioSessionSoon();
  }

  /// Goes on with a paused queue, from the item it was paused at.
  void resume() {
    final at = currentIndex.value;
    if (at == null || !paused.value) return;
    unawaited(_play(at));
  }

  /// Whether the queue has a group after the one being spoken.
  bool get hasNext => _groupStart(1) != null;

  /// Whether the queue has a group before the one being spoken.
  bool get hasPrevious => _groupStart(-1) != null;

  /// Moves on to the first item of the next group (the next verse). A paused
  /// queue stays paused there.
  void next() => _moveTo(_groupStart(1));

  /// Moves back to the first item of the group before this one (the verse
  /// before). A paused queue stays paused there.
  void previous() => _moveTo(_groupStart(-1));

  /// Moves to item [index] (the first of a verse, say). A paused queue stays
  /// paused there.
  void moveTo(int index) {
    if (currentIndex.value == null || index < 0 || index >= _queue.length) return;
    _moveTo(index);
  }

  /// Speaks the queue at [rate] from now on: the item being spoken starts
  /// again at it.
  void setRate(double rate) {
    if (rate == _queueRate) return;
    _queueRate = rate;
    final at = currentIndex.value;
    if (at != null && !paused.value) unawaited(_play(at));
  }

  int? _groupStart(int direction) {
    final at = currentIndex.value;
    if (at == null || at >= _queue.length) return null;
    final group = _groups[at];
    if (direction > 0) {
      for (var i = at + 1; i < _queue.length; i++) {
        if (_groups[i] != group) return i;
      }
      return null;
    }
    // Back to this group's first item, and then to the first of the group
    // before it.
    var i = at;
    while (i > 0 && _groups[i - 1] == group) {
      i--;
    }
    if (i == 0) return null;
    final before = _groups[i - 1];
    while (i > 0 && _groups[i - 1] == before) {
      i--;
    }
    return i;
  }

  void _moveTo(int? index) {
    if (index == null) return;
    if (paused.value) {
      _set(currentIndex, index);
    } else {
      unawaited(_play(index));
    }
  }

  void dispose() {
    unawaited(stop().whenComplete(() {
      _disposed = true;
      // A session that was to end in a moment ends now.
      if (_release?.isActive ?? false) {
        unawaited(audioSessionChannel.invokeMethod<bool>('deactivate').then((_) {}, onError: (Object _) {}));
      }
      _release?.cancel();
      if (identical(_sessionOwner, this)) {
        _sessionOwner = null;
        audioSessionChannel.setMethodCallHandler(null);
      }
      unawaited(_interruptions.close());
      currentIndex.dispose();
      paused.dispose();
    }));
  }
}

final ttsProvider = Provider<TtsService>((ref) {
  final t = TtsService();
  ref.onDispose(t.dispose);
  return t;
});
