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
    // As the plugin reports a failure: 0, never an exception.
    if (failCategory) return 0;
    this.category = (category, options, mode);
    return 1;
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
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Starts speaking and stops, as a Listen tapped twice does.
  Future<void> listen(TtsService tts) async {
    final spoken = tts.speak('בראשית ברא', language: 'he-IL');
    await pumpEventQueue();
    await tts.stop();
    await spoken;
  }

  /// The calls made to end the iOS audio session.
  late List<String> sessionCalls;
  setUp(() {
    sessionCalls = [];
    TtsService.releaseDelay = Duration.zero;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(TtsService.audioSessionChannel, (call) async {
      sessionCalls.add(call.method);
      return true;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TtsService.releaseDelay = const Duration(milliseconds: 300);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(TtsService.audioSessionChannel, null);
  });

  /// Lets the delayed end of the session run.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 1));

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

    test('speech stopped part-way ends the session, so that other audio comes back', () async {
      final tts = TtsService(engine: _FakeTts());
      await listen(tts);
      await settle();
      expect(sessionCalls, ['deactivate']);
    });

    test('a Listen started just after a stop keeps the session', () async {
      final tts = TtsService(engine: _FakeTts());
      final first = tts.speak('בראשית ברא', language: 'he-IL');
      await pumpEventQueue();
      // As speak() does: it stops what was speaking first.
      final second = tts.speak('אלהים', language: 'he-IL');
      await settle();
      expect(sessionCalls, isEmpty);
      await tts.stop();
      await Future.wait([first, second]);
      await settle();
      expect(sessionCalls, ['deactivate']);
    });

    test('nothing speaking, a stop leaves the session alone', () async {
      final tts = TtsService(engine: _FakeTts());
      await listen(tts);
      await settle();
      sessionCalls.clear();
      await tts.stop();
      await settle();
      expect(sessionCalls, isEmpty);
    });

    test('a session that could not be set still speaks, and is tried again next time', () async {
      final engine = _FakeTts()..failCategory = true;
      final tts = TtsService(engine: engine);

      await listen(tts);
      expect(engine.calls, contains('speak'));

      await settle();
      expect(sessionCalls, isEmpty, reason: 'there is no session of its own to end');

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
    await settle();
    expect(engine.calls, contains('speak'));
    expect(engine.calls, isNot(contains('setIosAudioCategory')));
    expect(sessionCalls, isEmpty);
  });
}
