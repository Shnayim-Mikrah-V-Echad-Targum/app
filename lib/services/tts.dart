import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech for listening to the text (an aid, not a substitute for
/// reading). Hebrew voices are used for both the Hebrew and the Aramaic.
class TtsService {
  TtsService() {
    _tts.setStartHandler(() => speaking.value = true);
    _tts.setCompletionHandler(_done);
    _tts.setCancelHandler(_done);
    _tts.setErrorHandler((_) => _done());
  }

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<bool> speaking = ValueNotifier(false);
  Completer<void>? _utterance;
  bool? _hebrewAvailable;

  void _done() {
    speaking.value = false;
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
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(rate);
    if (!kIsWeb) await _tts.awaitSpeakCompletion(false);
    final c = _utterance = Completer<void>();
    speaking.value = true;
    final result = await _tts.speak(text);
    if (result != 1 && result != null && result != true) _done();
    return c.future;
  }

  Future<void> stop() async {
    await _tts.stop();
    _done();
  }

  void dispose() {
    _tts.stop();
    speaking.dispose();
  }
}

final ttsProvider = Provider<TtsService>((ref) {
  final t = TtsService();
  ref.onDispose(t.dispose);
  return t;
});
