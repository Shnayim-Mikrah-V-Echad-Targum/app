import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  Future<dynamic> autoStopSharedSession(bool autoStop) async => calls.add('autoStopSharedSession($autoStop)');

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

/// A speech engine that reports as the platforms' do: each utterance starts
/// as it is spoken, ends when the test says it has been spoken to its end
/// ([finish]) or something outside interrupts it ([interrupt]), and is
/// reported cancelled a moment after it is stopped ([cancelDelay]); told to
/// stop while silent, it reports a cancel all the same, as Windows does
/// ([cancelsWhenSilent]).
class _Engine extends Fake implements FlutterTts {
  VoidCallback? _onStart;
  VoidCallback? _onComplete;
  VoidCallback? _onCancel;

  /// What was spoken, utterance by utterance, and at what rate.
  final said = <String>[];
  final rates = <double>[];
  double _rate = 0;

  /// Whether an utterance is being spoken.
  bool talking = false;

  /// How many times it was told to stop.
  int stops = 0;

  Duration cancelDelay = Duration.zero;
  bool failSpeak = false;
  bool cancelsWhenSilent = false;

  /// Holds each utterance in preparation, at its language, until completed.
  Completer<void>? preparing;

  /// Whether it is told to end the iOS session after each utterance.
  bool? autoStop;

  @override
  Future<dynamic> autoStopSharedSession(bool autoStop) async {
    this.autoStop = autoStop;
    return 1;
  }

  @override
  Future<dynamic> setIosAudioCategory(
          IosTextToSpeechAudioCategory category, List<IosTextToSpeechAudioCategoryOptions> options,
          [IosTextToSpeechAudioMode mode = IosTextToSpeechAudioMode.defaultMode]) async =>
      1;

  @override
  void setStartHandler(VoidCallback callback) => _onStart = callback;
  @override
  void setCompletionHandler(VoidCallback callback) => _onComplete = callback;
  @override
  void setCancelHandler(VoidCallback callback) => _onCancel = callback;
  @override
  void setErrorHandler(ErrorHandler handler) {}

  @override
  Future<dynamic> setLanguage(String language) async {
    await preparing?.future;
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    _rate = rate;
    return 1;
  }

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    if (failSpeak) throw PlatformException(code: 'no-engine');
    said.add(text);
    rates.add(_rate);
    talking = true;
    _onStart?.call();
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    stops++;
    if (talking || cancelsWhenSilent) {
      talking = false;
      Timer(cancelDelay, () => _onCancel?.call());
    }
    return 1;
  }

  /// The utterance being spoken reaches its end.
  void finish() {
    talking = false;
    _onComplete?.call();
  }

  /// Something outside the app (a call, another app's audio) cuts the
  /// utterance short.
  void interrupt() {
    talking = false;
    _onCancel?.call();
  }
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
    TtsService.finishedReleaseDelay = Duration.zero;
    TtsService.settleTimeout = Duration.zero;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(TtsService.audioSessionChannel, (call) async {
      sessionCalls.add(call.method);
      return true;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TtsService.releaseDelay = const Duration(milliseconds: 300);
    TtsService.finishedReleaseDelay = const Duration(seconds: 1);
    TtsService.settleTimeout = const Duration(milliseconds: 250);
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
      // The app ends the session itself, rather than the engine after each
      // utterance.
      expect(engine.calls.indexOf('autoStopSharedSession(false)'), lessThan(engine.calls.indexOf('speak')));

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

    group('a queue', () {
      late _Engine engine;
      late TtsService tts;
      setUp(() {
        engine = _Engine();
        tts = TtsService(engine: engine);
      });

      Future<void> settled() => Future<void>.delayed(const Duration(milliseconds: 5));

      test('keeps the session from one item to the next, and ends it once spoken to its end', () async {
        final done = tts.speakQueue(['mikra 1', 'targum 1', 'mikra 2'], language: 'he-IL', groups: [0, 0, 1]);
        await settled();
        expect(engine.autoStop, isFalse);
        engine.finish();
        await settled();
        engine.finish();
        await settled();
        expect(engine.said, ['mikra 1', 'targum 1', 'mikra 2']);
        expect(sessionCalls, isEmpty, reason: 'other audio stays ducked between verses');

        engine.finish();
        expect(await done, isTrue);
        await settled();
        expect(sessionCalls, ['deactivate']);
      });

      test('moved verse by verse, keeps the session', () async {
        unawaited(tts.speakQueue(['א', 'ב', 'ג'], language: 'he-IL'));
        await settled();
        tts.next();
        await settled();
        tts.previous();
        await settled();
        expect(sessionCalls, isEmpty);
      });

      test('ends the session when paused or stopped, and keeps it again once resumed', () async {
        unawaited(tts.speakQueue(['א', 'ב'], language: 'he-IL'));
        await settled();
        await tts.pause();
        await settled();
        expect(sessionCalls, ['deactivate'], reason: 'paused, other audio may come back');

        tts.resume();
        await settled();
        engine.finish();
        await settled();
        expect(sessionCalls, ['deactivate']);

        await tts.stop();
        await settled();
        expect(sessionCalls, ['deactivate', 'deactivate']);
      });

      test('keeps the session through Listen along\'s breath between readings', () async {
        TtsService.finishedReleaseDelay = const Duration(milliseconds: 50);
        final first = tts.speakQueue(['א'], language: 'he-IL');
        await settled();
        engine.finish();
        expect(await first, isTrue);
        // The next reading, a breath later.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        unawaited(tts.speakQueue(['ב'], language: 'he-IL'));
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(sessionCalls, isEmpty);
      });

      test('ends the session when it fails', () async {
        engine.failSpeak = true;
        await expectLater(tts.speakQueue(['א'], language: 'he-IL'), throwsA(isA<PlatformException>()));
        await settled();
        expect(sessionCalls, ['deactivate']);
      });
    });

    test('a single utterance spoken to its end ends the session', () async {
      final engine = _Engine();
      final tts = TtsService(engine: engine);
      final spoken = tts.speak('בראשית ברא', language: 'he-IL');
      await pumpEventQueue();
      engine.finish();
      expect(await spoken, isTrue);
      await settle();
      expect(sessionCalls, ['deactivate']);
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

  group('a queue', () {
    late _Engine engine;
    late TtsService tts;
    setUp(() {
      engine = _Engine();
      tts = TtsService(engine: engine);
      TtsService.settleTimeout = const Duration(milliseconds: 200);
    });

    /// Lets the engine's reports and the queue's next utterance through.
    Future<void> settled() => Future<void>.delayed(const Duration(milliseconds: 5));

    test('speaks its items in turn, and says when the last is done', () async {
      final done = tts.speakQueue(['א', 'ב', 'ג'], language: 'he-IL');
      await settled();
      expect(engine.said, ['א']);
      expect(tts.currentIndex.value, 0);
      engine.finish();
      await settled();
      expect(engine.said, ['א', 'ב']);
      expect(tts.currentIndex.value, 1);
      engine.finish();
      await settled();
      engine.finish();
      expect(await done, isTrue);
      expect(engine.said, ['א', 'ב', 'ג']);
      expect(tts.currentIndex.value, isNull);
    });

    test('paused, it holds its place, and goes on from the start of the item it was speaking', () async {
      unawaited(tts.speakQueue(['א', 'ב', 'ג'], language: 'he-IL'));
      await settled();
      engine.finish();
      await settled();
      await tts.pause();
      expect((tts.currentIndex.value, tts.paused.value, engine.talking), (1, true, false));
      // Nothing more is said while it is paused.
      await settled();
      expect(engine.said, ['א', 'ב']);

      tts.resume();
      await settled();
      expect((tts.currentIndex.value, tts.paused.value), (1, false));
      expect(engine.said, ['א', 'ב', 'ב']);
      engine.finish();
      await settled();
      expect(engine.said.last, 'ג');
    });

    test('moves verse by verse, from the Mikra of one to the Mikra of the next', () async {
      unawaited(tts.speakQueue(
        ['mikra 1', 'targum 1', 'mikra 2', 'targum 2', 'mikra 3'],
        language: 'he-IL',
        groups: [0, 0, 1, 1, 2],
      ));
      await settled();
      engine.finish();
      await settled();
      expect(tts.currentIndex.value, 1);
      expect((tts.hasPrevious, tts.hasNext), (false, true));

      tts.next();
      await settled();
      expect((tts.currentIndex.value, engine.said.last), (2, 'mikra 2'));
      tts.next();
      await settled();
      expect((tts.currentIndex.value, engine.said.last), (4, 'mikra 3'));
      expect(tts.hasNext, isFalse);
      tts.previous();
      await settled();
      expect((tts.currentIndex.value, engine.said.last), (2, 'mikra 2'));

      // Paused, it moves without speaking, and stays paused.
      await tts.pause();
      final said = engine.said.length;
      tts.previous();
      await settled();
      expect((tts.currentIndex.value, tts.paused.value, engine.said.length), (0, true, said));
      tts.resume();
      await settled();
      expect(engine.said.last, 'mikra 1');
    });

    test("the report of an utterance stopped isn't taken for the next one's", () async {
      // The platforms report a stop a moment after it: the next utterance
      // waits for it, rather than end as it arrives.
      engine.cancelDelay = const Duration(milliseconds: 20);
      unawaited(tts.speakQueue(['א', 'ב', 'ג'], language: 'he-IL'));
      await settled();
      tts.next();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect((tts.currentIndex.value, tts.paused.value, engine.talking), (1, false, true));
      expect(engine.said, ['א', 'ב']);
    });

    test('interrupted from outside, it pauses where it was', () async {
      unawaited(tts.speakQueue(['א', 'ב'], language: 'he-IL'));
      await settled();
      engine.interrupt();
      await settled();
      expect((tts.currentIndex.value, tts.paused.value), (0, true));
      tts.resume();
      await settled();
      expect(engine.said, ['א', 'א']);
    });

    test('a new rate starts the item being spoken again at it', () async {
      unawaited(tts.speakQueue(['א', 'ב'], language: 'he-IL', rate: 0.45));
      await settled();
      tts.setRate(0.65);
      await settled();
      expect(engine.said, ['א', 'א']);
      expect(engine.rates, [0.45, 0.65]);
      engine.finish();
      await settled();
      expect(engine.rates.last, 0.65);
    });

    test('stopped, or replaced by another, it says it did not finish', () async {
      final first = tts.speakQueue(['א', 'ב'], language: 'he-IL');
      await settled();
      final second = tts.speakQueue(['ג'], language: 'he-IL');
      expect(await first, isFalse);
      await settled();
      expect(engine.said.last, 'ג');
      await tts.stop();
      expect(await second, isFalse);
      expect((tts.currentIndex.value, engine.talking), (null, false));
    });

    test('nothing speaking, the engine is not told to stop', () async {
      engine.cancelsWhenSilent = true;
      await tts.stop();
      await tts.pause();
      expect(engine.stops, 0);

      // Nor once the queue has been spoken to its end.
      final done = tts.speakQueue(['א'], language: 'he-IL');
      await settled();
      engine.finish();
      await done;
      await tts.stop();
      expect(engine.stops, 0);
    });

    test('an utterance overtaken while it is prepared is never spoken, and stops nothing', () async {
      // Windows reports a cancel even for a stop while silent, which would
      // end the utterance after it.
      engine
        ..cancelsWhenSilent = true
        ..cancelDelay = const Duration(milliseconds: 10);
      final gate = engine.preparing = Completer<void>();
      final first = tts.speak('א', language: 'he-IL');
      await settled();
      final second = tts.speak('ב', language: 'he-IL');
      await settled();
      gate.complete();
      expect(await first, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(engine.said, ['ב']);
      expect(engine.stops, 0);
      expect(engine.talking, isTrue, reason: 'no late cancel ends it');
      engine.finish();
      expect(await second, isTrue);
    });

    test('Next pressed twice in quick succession speaks the verse it reaches, and keeps playing', () async {
      engine
        ..cancelsWhenSilent = true
        ..cancelDelay = const Duration(milliseconds: 10);
      unawaited(tts.speakQueue(['א', 'ב', 'ג'], language: 'he-IL'));
      await settled();
      engine.preparing = Completer<void>();
      tts.next();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // The second press lands while the verse the first reached is prepared.
      tts.next();
      await settled();
      engine.preparing!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(engine.said, ['א', 'ג']);
      expect(engine.stops, 1, reason: 'only the verse being spoken was stopped');
      expect((tts.currentIndex.value, tts.paused.value, engine.talking), (2, false, true));
    });

    test('an engine that cannot speak ends it with the error', () async {
      engine.failSpeak = true;
      await expectLater(tts.speakQueue(['א'], language: 'he-IL'), throwsA(isA<PlatformException>()));
      expect(tts.currentIndex.value, isNull);
    });
  });
}
