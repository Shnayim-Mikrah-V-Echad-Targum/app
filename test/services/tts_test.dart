import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shnayim_mikra/services/tts.dart';

/// Records the calls made to the speech engine.
class _FakeTts extends Fake implements FlutterTts {
  final calls = <String>[];
  (IosTextToSpeechAudioCategory, List<IosTextToSpeechAudioCategoryOptions>, IosTextToSpeechAudioMode)? category;
  bool failCategory = false;

  @override
  void setStartHandler(VoidCallback callback) {}
  @override
  void setCompletionHandler(VoidCallback callback) {}
  @override
  void setCancelHandler(VoidCallback callback) {}
  @override
  void setErrorHandler(ErrorHandler handler) {}

  @override
  Future<dynamic> setIosAudioCategory(
      IosTextToSpeechAudioCategory category, List<IosTextToSpeechAudioCategoryOptions> options,
      [IosTextToSpeechAudioMode mode = IosTextToSpeechAudioMode.defaultMode]) async {
    calls.add('setIosAudioCategory');
    if (failCategory) throw Exception('no audio session');
    this.category = (category, options, mode);
  }

  @override
  Future<dynamic> setLanguage(String language) async => calls.add('setLanguage');
  @override
  Future<dynamic> setSpeechRate(double rate) async => calls.add('setSpeechRate');
  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => calls.add('awaitSpeakCompletion');
  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    calls.add('speak');
    return 1;
  }

  @override
  Future<dynamic> stop() async => calls.add('stop');
}

void main() {
  /// Starts speaking and stops, as a Listen tapped twice does.
  Future<void> listen(TtsService tts) async {
    final spoken = tts.speak('בראשית ברא', language: 'he-IL');
    await pumpEventQueue();
    await tts.stop();
    await spoken;
  }

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('on iOS', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

    test('the first Listen sets a playback session that ducks other audio, before speaking', () async {
      final engine = _FakeTts();
      final tts = TtsService(engine: engine);
      expect(engine.calls, isNot(contains('setIosAudioCategory')), reason: 'opening the reader must not duck music');

      await listen(tts);
      final (category, options, mode) = engine.category!;
      expect((category, mode), (IosTextToSpeechAudioCategory.playback, IosTextToSpeechAudioMode.spokenAudio));
      expect(options, [
        IosTextToSpeechAudioCategoryOptions.duckOthers,
        IosTextToSpeechAudioCategoryOptions.interruptSpokenAudioAndMixWithOthers,
      ]);
      expect(engine.calls.indexOf('setIosAudioCategory'), lessThan(engine.calls.indexOf('speak')));

      await listen(tts);
      expect(engine.calls.where((c) => c == 'setIosAudioCategory'), hasLength(1));
    });

    test('a session that could not be set still speaks, and is tried again next time', () async {
      final engine = _FakeTts()..failCategory = true;
      final tts = TtsService(engine: engine);

      await listen(tts);
      expect(engine.calls, contains('speak'));

      engine.failCategory = false;
      await listen(tts);
      expect(engine.calls.where((c) => c == 'setIosAudioCategory'), hasLength(2));
      expect(engine.category, isNotNull);
    });
  });

  test('elsewhere, the audio session is left alone', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final engine = _FakeTts();
    await listen(TtsService(engine: engine));
    expect(engine.calls, contains('speak'));
    expect(engine.calls, isNot(contains('setIosAudioCategory')));
  });
}
