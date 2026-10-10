import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech for listening to the text (an aid, not a substitute for
/// reading). Hebrew voices are used for both the Hebrew and the Aramaic.
class TtsService {
  /// Speaks through [engine], by default the platform's.
  TtsService({@visibleForTesting FlutterTts? engine}) : _tts = engine ?? FlutterTts() {
    _tts.setStartHandler(() {
      if (!_disposed) speaking.value = true;
    });
    _tts.setCompletionHandler(_done);
    _tts.setCancelHandler(() {
      _done();
      _releaseIosAudioSoon();
    });
    _tts.setErrorHandler((_) {
      _done();
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

  final FlutterTts _tts;
  final ValueNotifier<bool> speaking = ValueNotifier(false);
  Completer<void>? _utterance;
  bool? _hebrewAvailable;
  bool _disposed = false;
  bool _iosAudioReady = false;
  Timer? _release;

  void _done() {
    if (!_disposed) speaking.value = false;
    _utterance?.complete();
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

  /// Speaks [text] and completes when finished or stopped.
  Future<void> speak(String text, {required String language, double rate = 0.45}) async {
    await stop();
    final c = _utterance = Completer<void>();
    try {
      await _prepareIosAudio();
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(rate);
      if (!kIsWeb) await _tts.awaitSpeakCompletion(false);
      speaking.value = true;
      final result = await _tts.speak(text);
      if (result != 1 && result != null && result != true) _done();
    } catch (_) {
      _done();
      rethrow;
    }
    return c.future;
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
  /// ended under speech that a new Listen starts.
  void _releaseIosAudioSoon() {
    if (!_iosAudioReady || _disposed) return;
    _release?.cancel();
    _release = Timer(releaseDelay, () {
      if (_utterance != null) return;
      unawaited(audioSessionChannel.invokeMethod<bool>('deactivate').then((_) {}, onError: (Object _) {}));
    });
  }

  /// Stops speech. Never throws: a platform without a speech engine has
  /// nothing to stop.
  Future<void> stop() async {
    final wasSpeaking = _utterance != null || speaking.value;
    try {
      await _tts.stop();
    } catch (_) {}
    _done();
    if (wasSpeaking) _releaseIosAudioSoon();
  }

  void dispose() {
    unawaited(stop().whenComplete(() {
      _disposed = true;
      speaking.dispose();
    }));
  }
}

final ttsProvider = Provider<TtsService>((ref) {
  final t = TtsService();
  ref.onDispose(t.dispose);
  return t;
});
