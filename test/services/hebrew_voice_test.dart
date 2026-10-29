import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/services/hebrew_voice/hebrew_voice.dart';
import 'package:shnayim_mikrah/services/hebrew_voice/voice_model.dart';
import 'package:shnayim_mikrah/services/hebrew_voice/voice_routing_tts.dart';

class _Model implements VoiceModel {
  bool here = false;
  bool fail = false;
  final fetches = <double>[];

  @override
  Future<bool> present() async => here;

  @override
  Future<void> fetch({required void Function(double progress) onProgress}) async {
    for (final p in [0.25, 0.5, 1.0]) {
      fetches.add(p);
      onProgress(p);
    }
    if (fail) throw const FormatException('not the voice');
    here = true;
  }

  @override
  Future<void> remove() async => here = false;

  @override
  Future<String> location() async => '/voices/hebrew.onnx';
}

/// A voice that "speaks" without a model: it records what it was asked, and
/// can be held back or made to fail.
class _Voice extends HebrewVoice {
  _Voice() : super(model: _Model());
  final asked = <(String, double)>[];
  Completer<void>? hold;
  bool fail = false;

  @override
  Future<Uint8List> speak(String text, {double rate = 0.5}) async {
    asked.add((text, rate));
    await hold?.future;
    if (fail) throw StateError('no model');
    return Uint8List.fromList([1, 2, 3]);
  }
}

class _Player extends Fake implements AudioPlayer {
  final played = <Source>[];
  int stops = 0;
  final _complete = StreamController<void>.broadcast();

  void finish() => _complete.add(null);

  @override
  Future<void> setAudioContext(AudioContext ctx) async {}

  @override
  Stream<void> get onPlayerComplete => _complete.stream;

  @override
  Future<void> play(Source source, {double? volume, double? balance, AudioContext? ctx, Duration? position, PlayerMode? mode}) async =>
      played.add(source);

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async => _complete.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HebrewVoice', () {
    test('gives Piper its ids: the start, each sound with a pad after it, and the end', () {
      expect(HebrewVoice.phonemeIds('ba'), [1, 0, 15, 0, 14, 0, 2]);
      expect(HebrewVoice.phonemeIds('ʃˈa.'), [1, 0, 96, 0, 120, 0, 14, 0, 10, 0, 2]);
      expect(HebrewVoice.phonemeIds('b#a'), [1, 0, 15, 0, 14, 0, 2], reason: 'a sound the voice lacks is left out');
    });

    test('speaks at the rate asked, 0.5 its own pace', () {
      expect(HebrewVoice.lengthScaleFor(0.5), 1);
      expect(HebrewVoice.lengthScaleFor(1), 0.5);
      expect(HebrewVoice.lengthScaleFor(0.25), 2);
    });

    test('makes a 16-bit mono WAV at its rate, brought up to a common loudness', () {
      final wav = HebrewVoice.wav(Float32List.fromList([0, 0.1, -0.2]));
      final data = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(data.getUint16(22, Endian.little), 1);
      expect(data.getUint32(24, Endian.little), 22050);
      expect(data.getUint32(40, Endian.little), 6);
      // The loudest sample is brought to 0.9 of full scale.
      expect(data.getInt16(48, Endian.little), -(0.9 * 32767).round());
      expect(data.getInt16(46, Endian.little), (0.45 * 32767).round());
    });

    test('is fetched when turned on, telling how far it has come, and taken off when turned off', () async {
      final model = _Model();
      final voice = HebrewVoice(model: model);
      await voice.init();
      expect(voice.state.value, HebrewVoiceState.absent);
      final seen = <double>[];
      voice.progress.addListener(() => seen.add(voice.progress.value));
      await voice.install();
      expect(seen, [0.25, 0.5, 1.0]);
      expect(voice.state.value, HebrewVoiceState.ready);
      await voice.remove();
      expect(voice.state.value, HebrewVoiceState.absent);
      expect(model.here, isFalse);
    });

    test('is found on the device when it was fetched before, and says when a fetch fails', () async {
      final here = HebrewVoice(model: _Model()..here = true);
      await here.init();
      expect(here.ready, isTrue);

      final failing = HebrewVoice(model: _Model()..fail = true);
      await expectLater(failing.install(), throwsFormatException);
      expect(failing.state.value, HebrewVoiceState.failed);
      await expectLater(failing.synthesize('ba'), throwsStateError, reason: 'nothing to speak with');
    });
  });

  group('VoiceRoutingTts', () {
    const pointed = 'בְּרֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים';
    late List<MethodCall> device;
    late _Voice voice;
    late _Player player;
    late VoiceRoutingTts tts;
    late List<String> events;

    setUp(() {
      device = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async {
        device.add(call);
        return call.method == 'isLanguageAvailable' ? false : 1;
      });
      voice = _Voice();
      player = _Player();
      tts = VoiceRoutingTts(voice, player: () => player);
      events = [];
      tts
        ..setStartHandler(() => events.add('start'))
        ..setCompletionHandler(() => events.add('complete'))
        ..setCancelHandler(() => events.add('cancel'));
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
      tts.dispose();
    });

    List<Object?> spokenByDevice() => [for (final c in device) if (c.method == 'speak') c.arguments];

    test('until the voice is on the device, the device reads, without the cantillation', () async {
      await tts.setLanguage('he-IL');
      await tts.speak(pointed);
      expect(spokenByDevice().single, 'בְּרֵאשִׁית בָּרָא אֱלֹהִים');
      expect(voice.asked, isEmpty);
      expect(await tts.isLanguageAvailable('he-IL'), isFalse);
    });

    test('once it is, it reads pointed Hebrew, at the rate set, and reports its start and end', () async {
      voice.state.value = HebrewVoiceState.ready;
      await tts.setLanguage('he-IL');
      await tts.setSpeechRate(0.4);
      expect(await tts.speak(pointed), 1);
      expect(voice.asked.single, (pointed, 0.4));
      expect(player.played, hasLength(1));
      expect(spokenByDevice(), isEmpty);
      expect(events, ['start']);
      player.finish();
      await Future<void>.delayed(Duration.zero);
      expect(events, ['start', 'complete']);
      expect(await tts.isLanguageAvailable('he-IL'), isTrue, reason: 'a Hebrew voice, even where the device has none');
    });

    test('leaves unpointed Hebrew and other languages to the device', () async {
      voice.state.value = HebrewVoiceState.ready;
      await tts.setLanguage('he-IL');
      await tts.speak('ויאמר רש"י');
      await tts.setLanguage('en-US');
      await tts.speak('And God said');
      expect(voice.asked, isEmpty);
      expect(spokenByDevice(), ['ויאמר רש"י', 'And God said']);
    });

    test('stopped while the audio is being made or played, reports a cancel and plays nothing more', () async {
      voice.state.value = HebrewVoiceState.ready;
      await tts.setLanguage('he-IL');
      voice.hold = Completer<void>();
      final speaking = tts.speak(pointed);
      await Future<void>.delayed(Duration.zero);
      await tts.stop();
      voice.hold!.complete();
      expect(await speaking, 1);
      expect(events, ['cancel']);
      expect(player.played, isEmpty);
      expect(device.where((c) => c.method == 'stop'), isEmpty, reason: 'the device engine was not speaking');

      voice.hold = null;
      await tts.speak(pointed);
      await tts.stop();
      expect(player.stops, 1);
      expect(events, ['cancel', 'start', 'cancel']);
    });

    test('should the voice fail, the device reads in its place', () async {
      voice
        ..state.value = HebrewVoiceState.ready
        ..fail = true;
      await tts.setLanguage('he-IL');
      await tts.speak(pointed);
      expect(spokenByDevice().single, 'בְּרֵאשִׁית בָּרָא אֱלֹהִים');
      expect(player.played, isEmpty);
    });
  });
}
