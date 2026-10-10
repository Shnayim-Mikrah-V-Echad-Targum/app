import 'dart:async';

import 'package:flutter/foundation.dart';
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
    _tts.setCancelHandler(_done);
    _tts.setErrorHandler((_) => _done());
  }

  final FlutterTts _tts;
  final ValueNotifier<bool> speaking = ValueNotifier(false);
  Completer<void>? _utterance;
  bool? _hebrewAvailable;
  bool _disposed = false;
  bool _iosAudioReady = false;

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
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.interruptSpokenAudioAndMixWithOthers,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );
      _iosAudioReady = true;
    } catch (_) {
      // Speech still works; only the Silent switch silences it.
    }
  }

  /// Stops speech. Never throws: a platform without a speech engine has
  /// nothing to stop.
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _done();
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
