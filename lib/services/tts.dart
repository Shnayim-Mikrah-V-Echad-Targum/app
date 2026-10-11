import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech for listening to the text (an aid, not a substitute for
/// reading). Hebrew voices are used for both the Hebrew and the Aramaic.
///
/// It speaks one utterance at a time ([speak]), or a queue of them, one for
/// each layer of each verse, that can be paused, resumed and moved through
/// verse by verse ([speakQueue]).
class TtsService {
  /// Speaks through [engine], by default the platform's.
  TtsService({@visibleForTesting FlutterTts? engine}) : _tts = engine ?? FlutterTts() {
    _tts.setStartHandler(() {
      if (!_disposed) speaking.value = true;
    });
    _tts.setCompletionHandler(() => _engineStopped(spokenToEnd: true));
    _tts.setCancelHandler(() {
      _engineStopped();
      _releaseIosAudioSoon();
    });
    _tts.setErrorHandler((_) {
      _engineStopped();
      _releaseIosAudioSoon();
    });
  }

  /// Ends the iOS audio session (ios/Runner/AppDelegate.swift).
  @visibleForTesting
  static const audioSessionChannel = MethodChannel('shnayim_mikra/audio_session');

  /// How long after speech stops part-way the iOS audio session is ended,
  /// unless speech starts again meanwhile.
  @visibleForTesting
  static Duration releaseDelay = const Duration(milliseconds: 300);

  /// How long, at most, the next utterance waits for the engine to report
  /// the one it stopped as stopped (see [_halt]).
  @visibleForTesting
  static Duration settleTimeout = const Duration(milliseconds: 250);

  final FlutterTts _tts;
  final ValueNotifier<bool> speaking = ValueNotifier(false);
  Completer<bool>? _utterance;
  bool? _hebrewAvailable;
  bool _disposed = false;
  bool _iosAudioReady = false;
  Timer? _release;

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
    _set(speaking, false);
    _utterance?.complete(spokenToEnd);
    _utterance = null;
  }

  /// Whether a Hebrew voice is installed. Null if it can't be determined.
  Future<bool?> hasHebrewVoice() async {
    if (_hebrewAvailable != null) return _hebrewAvailable;
    try {
      final available = await _tts.isLanguageAvailable('he-IL');
      _hebrewAvailable = available == true || available == 1;
    } catch (_) {
      try {
        final langs = (await _tts.getLanguages as List?)?.cast<Object?>() ?? const [];
        _hebrewAvailable = langs.any((l) => '$l'.toLowerCase().startsWith('he') || '$l'.toLowerCase().startsWith('iw'));
      } catch (_) {
        return null;
      }
    }
    return _hebrewAvailable;
  }

  /// Speaks [text], stopping whatever is being spoken first, and completes
  /// when it is finished or stopped: with true if it was spoken to its end.
  /// Throws if the engine can't speak at all.
  Future<bool> speak(String text, {required String language, double rate = 0.45}) async {
    final generation = ++_generation;
    _preparing++;
    try {
      await _halt();
    } finally {
      _preparing--;
    }
    if (generation != _generation) {
      // Another utterance was asked for, or speech stopped, meanwhile: the
      // iOS session goes, unless speech starts again.
      _releaseIosAudioSoon();
      return false;
    }
    final c = _utterance = Completer<bool>();
    try {
      await _prepareIosAudio();
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(rate);
      if (!kIsWeb) await _tts.awaitSpeakCompletion(false);
      if (generation == _generation) {
        _engineBusy = true;
        speaking.value = true;
        final result = await _tts.speak(text);
        if (result != 1 && result != null && result != true) _engineStopped();
      }
    } catch (_) {
      _engineStopped();
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
  /// cancel even then.
  Future<void> _halt() async {
    final busy = _engineBusy;
    if (!busy && _utterance == null && !speaking.value) return;
    // Already being stopped, for an utterance asked for a moment ago.
    final stopping = _engineSettled != null;
    final settled = busy ? (_engineSettled ??= Completer<void>()) : null;
    if (!stopping) {
      try {
        await _tts.stop();
      } catch (_) {}
    }
    _done();
    _releaseIosAudioSoon();
    if (settled == null) return;
    // An engine that never reports it is taken to have stopped.
    await settled.future.timeout(settleTimeout, onTimeout: () {
      if (identical(_engineSettled, settled)) {
        _engineBusy = false;
        _engineSettled = null;
      }
    });
  }

  /// On iOS, speech is silenced by the Silent switch unless the audio session
  /// is for playback. Set on the first Listen rather than at startup, so that
  /// opening the reader never ducks the user's music; other audio ducks while
  /// speaking and resumes after.
  Future<void> _prepareIosAudio() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS || _iosAudioReady) return;
    try {
      final result = await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.interruptSpokenAudioAndMixWithOthers,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );
      // The plugin reports a failure as 0, or as null, rather than throwing:
      // tried again on the next Listen.
      _iosAudioReady = result == 1;
    } catch (_) {
      // Speech still works; only the Silent switch silences it.
    }
  }

  /// On iOS, once speech has stopped part-way, ends the audio session set
  /// for it, as the engine does by itself only when speech finishes: music
  /// it ducked comes back up, and spoken audio it interrupted (a podcast)
  /// is told it may resume. After [releaseDelay], so that the session isn't
  /// ended under speech that a new Listen (or the next verse) starts.
  void _releaseIosAudioSoon() {
    if (!_iosAudioReady || _disposed) return;
    _release?.cancel();
    _release = Timer(releaseDelay, () {
      if (_utterance != null || _preparing > 0) return;
      unawaited(audioSessionChannel.invokeMethod<bool>('deactivate').then((_) {}, onError: (Object _) {}));
    });
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
  double _queueRate = 0.45;
  Completer<bool>? _queueEnd;

  // Changes whenever the queue is paused, moved, stopped or replaced, which
  // ends the loop speaking it.
  int _queueToken = 0;

  /// Speaks [items] one after another from [startAt], and completes with
  /// true once the last has been spoken, or false if the queue is stopped or
  /// replaced first (or has no items). While it is paused, it waits. It
  /// completes with an error if the engine can't speak.
  ///
  /// [groups] gives the group each item belongs to (a verse, whose Mikra and
  /// Targum are two items), which [next] and [previous] move between; by
  /// default each item is a group of its own. A group's items are adjacent.
  Future<bool> speakQueue(
    List<String> items, {
    required String language,
    double rate = 0.45,
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
      speaking.dispose();
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
