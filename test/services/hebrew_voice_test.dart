import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/core/text/hebrew_pronunciation.dart';
import 'package:shnayim_mikrah/services/hebrew_voice/hebrew_voice.dart';
import 'package:shnayim_mikrah/services/hebrew_voice/npz.dart';
import 'package:shnayim_mikrah/services/hebrew_voice/voice_catalogue.dart';
import 'package:shnayim_mikrah/services/hebrew_voice/voice_engines.dart';
import 'package:shnayim_mikrah/services/hebrew_voice/voice_routing_tts.dart';
import 'package:shnayim_mikrah/services/hebrew_voice/voice_settings.dart';
import 'package:shnayim_mikrah/services/hebrew_voice/voice_store.dart';
import 'package:shnayim_mikrah/services/tts.dart';

/// Files in memory, fetched as asked, and failing when told to.
class _Store implements VoiceStore {
  final files = <VoiceFile, Uint8List>{};
  final fetched = <VoiceFile>[];
  bool fail = false;

  @override
  Future<bool> has(VoiceFile file) async => files.containsKey(file);

  @override
  Future<void> fetch(List<VoiceFile> wanted, {required void Function(int received, int total) onProgress}) async {
    final missing = {...wanted}.where((f) => !files.containsKey(f)).toList();
    final total = missing.fold<int>(0, (a, f) => a + f.size);
    var received = 0;
    onProgress(0, total);
    for (final f in missing) {
      if (fail) throw const FormatException('not the file');
      files[f] = Uint8List(0);
      fetched.add(f);
      received += f.size;
      onProgress(received, total);
    }
  }

  @override
  Future<void> remove(VoiceFile file) async => files.remove(file);

  @override
  Future<String> location(VoiceFile file) async => file.path;

  @override
  Future<Uint8List> read(VoiceFile file) async => files[file]!;

  final madeModels = <String, Uint8List>{};

  @override
  Future<String> made(String name, Uint8List bytes) async {
    madeModels[name] = bytes;
    return name;
  }
}

class _Session extends Fake implements OrtSession {
  @override
  Future<void> close() async {}
}

VoiceFile _file(String path, int size) => VoiceFile('test/repo', '0123456789abcdef', path, size, 'x' * 64);

final _model = _file('model.onnx', 60000000);
final _otherModel = _file('other.onnx', 40000000);
final _config = _file('model.config.json', 7000);
final _styleA = _file('voices/a.json', 290000);
final _styleB = _file('voices/b.json', 290000);

HebrewVoiceOption _voice(String id, VoiceSpec spec, double clarity) => HebrewVoiceOption(
      id: id,
      name: id,
      nameHe: id,
      gender: VoiceGender.male,
      family: VoiceFamily.blue,
      spec: spec,
      clarity: clarity,
    );

final _testVoices = [
  // Two voices of one model, which share its file.
  _voice('a', BlueSpec(durationPredictor: _model, textEncoder: _model, vectorEstimator: _model, vocoder: _model, vocab: _config, config: _config, style: _styleA), 0.9),
  _voice('b', BlueSpec(durationPredictor: _model, textEncoder: _model, vectorEstimator: _model, vocoder: _model, vocab: _config, config: _config, style: _styleB), 0.95),
  _voice('c', PiperSpec(model: _otherModel, config: _config), 0.8),
];

/// numpy.savez's archive of [arrays]: a ZIP of stored .npy files.
Uint8List _npz(Map<String, (List<int>, List<double>)> arrays) {
  final out = BytesBuilder();
  final directory = BytesBuilder();
  for (final MapEntry(key: name, value: (shape, values)) in arrays.entries) {
    final header = "${"{'descr': '<f4', 'fortran_order': False, 'shape': (${shape.join(', ')},), }".padRight(118)}\n";
    final npy = BytesBuilder()
      ..add([0x93, ...ascii.encode('NUMPY'), 1, 0])
      ..add((ByteData(2)..setUint16(0, header.length, Endian.little)).buffer.asUint8List())
      ..add(latin1.encode(header))
      ..add(Float32List.fromList(values).buffer.asUint8List());
    final data = npy.takeBytes();
    final fileName = utf8.encode('$name.npy');
    final offset = out.length;
    ByteData le(int bytes) => ByteData(bytes);
    out
      ..add((le(4)..setUint32(0, 0x04034b50, Endian.little)).buffer.asUint8List())
      ..add(Uint8List(22))
      ..add((le(2)..setUint16(0, fileName.length, Endian.little)).buffer.asUint8List())
      ..add(Uint8List(2))
      ..add(fileName)
      ..add(data);
    final entry = ByteData(46)
      ..setUint32(0, 0x02014b50, Endian.little)
      ..setUint32(20, data.length, Endian.little)
      ..setUint32(24, data.length, Endian.little)
      ..setUint16(28, fileName.length, Endian.little)
      ..setUint32(42, offset, Endian.little);
    directory
      ..add(entry.buffer.asUint8List())
      ..add(fileName);
  }
  final start = out.length;
  final dir = directory.takeBytes();
  out.add(dir);
  final end = ByteData(22)
    ..setUint32(0, 0x06054b50, Endian.little)
    ..setUint16(10, arrays.length, Endian.little)
    ..setUint32(12, dir.length, Endian.little)
    ..setUint32(16, start, Endian.little);
  out.add(end.buffer.asUint8List());
  return out.takeBytes();
}

class _Voices extends HebrewVoices {
  _Voices() : super(store: _Store(), voices: _testVoices);
  final readyIds = <String>{};
  final asked = <(String, String, double)>[];
  Completer<void>? hold;
  bool fail = false;

  @override
  bool ready(String id) => readyIds.contains(id);

  @override
  Future<Uint8List> speak(String text, {required String id, required VoiceSettings settings, double speed = 1}) async {
    asked.add((text, id, speed));
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

  test('reads the arrays of an .npz, as numpy.savez writes them', () {
    final arrays = readNpz(_npz({
      'mean': ([1, 3, 1], [0.5, -1, 2]),
      'normalizer_scale': ([1], [0.25]),
    }));
    expect(arrays['mean']!.shape, [1, 3, 1]);
    expect(arrays['mean']!.data, [0.5, -1, 2]);
    expect(arrays['normalizer_scale']!.data.single, 0.25);
    expect(() => readNpz(Uint8List(30)), throwsFormatException);
  });

  group('HebrewVoices', () {
    test('finds the voices on the device, the clearest first', () async {
      final store = _Store()..files.addAll({_model: Uint8List(0), _config: Uint8List(0), _styleA: Uint8List(0), _styleB: Uint8List(0)});
      final voices = HebrewVoices(store: store, voices: _testVoices);
      await voices.init();
      expect(voices.readyVoices.map((v) => v.id), ['b', 'a']);
      expect(voices.ready('c'), isFalse);
      expect(voices.bytesOnDevice, _model.size + _config.size + _styleA.size + _styleB.size);
    });

    test('fetches a voice, telling how far it has come; another of its model then takes only its own style', () async {
      final store = _Store();
      final voices = HebrewVoices(store: store, voices: _testVoices);
      await voices.init();
      expect(voices.bytesToFetch('a'), _model.size + _config.size + _styleA.size);
      final seen = <double>[];
      voices.status('a').addListener(() => seen.add(voices.status('a').value.progress));
      await voices.install('a');
      expect(voices.ready('a'), isTrue);
      expect(seen.reduce((a, b) => a > b ? a : b), 1);
      expect(seen.where((p) => p > 0 && p < 1), isNotEmpty);
      expect(voices.bytesToFetch('b'), _styleB.size);
      expect(voices.bytesToFetch('c'), _otherModel.size);
    });

    test('takes a voice off with the files no other voice on the device uses', () async {
      final store = _Store();
      final voices = HebrewVoices(store: store, voices: _testVoices);
      await voices.install('a');
      await voices.install('b');
      await voices.remove('a');
      expect(store.files.keys, containsAll([_model, _config, _styleB]));
      expect(store.files.containsKey(_styleA), isFalse);
      await voices.remove('b');
      expect(store.files.keys.map((f) => f.path), isEmpty);
      expect(voices.readyVoices, isEmpty);
    });

    test('says when a fetch fails, and finishes by itself a voice missing only a small file', () async {
      final failing = _Store()..fail = true;
      final voices = HebrewVoices(store: failing, voices: _testVoices);
      await expectLater(voices.install('c'), throwsFormatException);
      expect(voices.status('c').value.state, HebrewVoiceState.failed);

      // The first release's Shaul: the model on the device, its config not.
      final store = _Store()..files[_otherModel] = Uint8List(0);
      final later = HebrewVoices(store: store, voices: _testVoices);
      await later.init();
      await Future<void>.delayed(Duration.zero);
      expect(store.fetched, [_config]);
      expect(later.ready('c'), isTrue);
    });

    test('makes a 16-bit mono WAV at the voice\'s rate, at an even loudness or only kept from clipping', () {
      final audio = Float32List.fromList([0, 0.1, -0.2]);
      final wav = HebrewVoices.wav(audio, 24000);
      final data = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(data.getUint16(22, Endian.little), 1);
      expect(data.getUint32(24, Endian.little), 24000);
      expect(data.getUint32(40, Endian.little), 6);
      expect(data.getInt16(48, Endian.little), -(0.9 * 32767).round());
      final quiet = ByteData.sublistView(HebrewVoices.wav(audio, 24000, even: false));
      expect(quiet.getInt16(48, Endian.little), -(0.2 * 32767).round());
    });
  });

  group('the engines', () {
    Future<PiperRunner> piper(PiperInput input, {Map<String, String>? letters}) {
      final store = _Store()
        ..files[_config] = utf8.encode(jsonEncode({
          'audio': {'sample_rate': 22050},
          'phoneme_id_map': {
            '_': [0], '^': [1], r'$': [2], ' ': [3], ',': [8], 'a': [14], 'b': [15], 'ˈ': [120], 'ɬ': [40], 'ʎ': [41],
          },
        }));
      final lettersFile = _file('map.json', 600);
      if (letters != null) store.files[lettersFile] = utf8.encode(jsonEncode(letters));
      return PiperRunner.open(
        PiperSpec(model: _model, config: _config, input: input, letters: letters == null ? null : lettersFile),
        store,
        (_) async => _Session(),
      );
    }

    test('Piper: the start, each sound with a pad after it, and the end; without pads where trained so', () async {
      final padded = await piper(PiperInput.sounds);
      expect(padded.sampleRate, 22050);
      expect(padded.ids('bˈa'), [1, 0, 15, 0, 120, 0, 14, 0, 2]);
      expect(padded.ids('b#a'), [1, 0, 15, 0, 14, 0, 2], reason: 'a sound the model lacks is left out');
      final plain = await piper(PiperInput.soundsUnpadded);
      expect(plain.ids('ba'), [1, 15, 14, 2]);
    });

    test('Piper reading the letters: the points as written, or none, and never the cantillation', () async {
      final pointed = await piper(PiperInput.pointedLetters, letters: {'א': 'ɬ', 'ָ': 'ʎ'});
      expect(pointed.symbols('ʔa', 'אָ֑'), 'ɬʎ');
      final bare = await piper(PiperInput.bareLetters, letters: {'א': 'ɬ', 'ָ': 'ʎ'});
      expect(bare.symbols('ʔa', 'אָ֑'), 'ɬ');
    });

    test('Pocket TTS: a sound to an id, and between words the tokenizer\'s boundary and any punctuation', () async {
      List<int> piece(String text) {
        final bytes = utf8.encode(text);
        final inner = [0x0a, bytes.length, ...bytes];
        return [0x0a, inner.length, ...inner];
      }

      final proto = [for (final p in ['<unk>', '<s>', '</s>', '▁', ',', '.']) ...piece(p)];
      final assets = _file('he/assets.json', 1000);
      final store = _Store()
        ..files[assets] = utf8.encode(jsonEncode({
          'config': {
            'sample_rate': 24000, 'flow_layers': 6, 'flow_heads': 16, 'flow_head_dim': 64,
            'mimi_layers': 2, 'mimi_heads': 8, 'mimi_head_dim': 64, 'mimi_kv_len': 266, 'mimi_steps_per_latent': 16,
            'lora': {'atomic_chars': 'abˈ', 'vocab_base': 100},
          },
          'voices': <String, String>{},
          'tokenizer': base64.encode(proto),
        }));
      final runner = await PocketRunner.open(PocketSpec(model: _model, assets: assets, voice: 'omer'), store, (_) async => _Session());
      expect(runner.sampleRate, 24000);
      expect(runner.tokens('ab ba, a.'), [100, 101, 3, 101, 100, 3, 4, 100, 3, 5]);
      expect(runner.tokens('bˈa'), [101, 102, 100]);
      // The caches' joining models, made once.
      expect(store.madeModels.keys, containsAll(['pocket-concat-6x2x1x16x64.onnx', 'pocket-window-2x2x1x8x64-266-16.onnx']));
    });

    test('long sounds are read in pieces, after a pause where there is one', () {
      expect(splitSounds('ab cd', 10), ['ab cd']);
      expect(splitSounds('aaaa bbbb, cccc dddd.', 12), ['aaaa bbbb,', 'cccc dddd.']);
      expect(splitSounds('aaaa bbbb cccc', 9), ['aaaa bbbb', 'cccc']);
    });
  });

  group('VoiceSettings', () {
    test('every choice kept, and a voice no longer offered taken as the default', () {
      final s = const VoiceSettings().copyWith(
        torah: 'blue25-male-6209',
        targum: () => VoiceSettings.deviceVoice,
        pronunciation: HebrewPronunciationPreset.polish.pronunciation,
        pauses: false,
        variation: () => 0.3,
        steps: 16,
      );
      expect(VoiceSettings.fromJson(jsonDecode(jsonEncode(s.toJson()))), s);
      expect(VoiceSettings.fromJson({'torah': 'gone', 'targum': 'gone too'}), const VoiceSettings());
      expect(VoiceSettings.fromJson(null).torah, kDefaultHebrewVoice);
    });

    test('the Targum and the haftarah read as the Torah until given voices of their own', () {
      final s = const VoiceSettings(torah: 'noa');
      expect(s.voiceFor(SpeechRole.targum), 'noa');
      final own = s.withVoice(SpeechRole.haftarah, 'kokoro-shaul');
      expect(own.voiceFor(SpeechRole.haftarah), 'kokoro-shaul');
      expect(own.withVoice(SpeechRole.haftarah, null).voiceFor(SpeechRole.haftarah), 'noa');
    });

    test('every voice in the catalogue has a unique id, and the default is one of them', () {
      expect({for (final v in hebrewVoices) v.id}.length, hebrewVoices.length);
      expect(hebrewVoiceById(kDefaultHebrewVoice), isNotNull);
      for (final v in hebrewVoices) {
        expect(v.clarity, inInclusiveRange(0, 1));
        for (final f in v.files) {
          expect(f.sha256, matches(RegExp(r'^[0-9a-f]{64}$')), reason: f.path);
          expect(f.url, startsWith('https://huggingface.co/'));
        }
      }
    });
  });

  group('VoiceRoutingTts', () {
    const pointed = 'בְּרֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים';
    late List<MethodCall> device;
    late _Voices voices;
    late _Player player;
    late VoiceRoutingTts tts;
    late List<String> events;
    var settings = const VoiceSettings(torah: 'a');

    setUp(() {
      device = [];
      settings = const VoiceSettings(torah: 'a');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async {
        device.add(call);
        return call.method == 'isLanguageAvailable' ? false : 1;
      });
      voices = _Voices();
      player = _Player();
      tts = VoiceRoutingTts(voices, settings: () => settings, player: () => player);
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

    test('with no voice of the app\'s on the device, the device reads, without the cantillation', () async {
      await tts.setLanguage('he-IL');
      await tts.speak(pointed);
      expect(spokenByDevice().single, 'בְּרֵאשִׁית בָּרָא אֱלֹהִים');
      expect(voices.asked, isEmpty);
      expect(await tts.isLanguageAvailable('he-IL'), isFalse);
    });

    test('the voice chosen reads pointed Hebrew at the rate set, reporting its start and end', () async {
      voices.readyIds.add('a');
      await tts.setLanguage('he-IL');
      await tts.setSpeechRate(kDefaultSpeechRate * 2);
      expect(await tts.speak(pointed), 1);
      expect(voices.asked.single, (pointed, 'a', 2.0));
      expect(player.played, hasLength(1));
      expect(spokenByDevice(), isEmpty);
      expect(events, ['start']);
      player.finish();
      await Future<void>.delayed(Duration.zero);
      expect(events, ['start', 'complete']);
      expect(await tts.isLanguageAvailable('he-IL'), isTrue, reason: 'a Hebrew voice, even where the device has none');
    });

    test('each role in its own voice; while one isn\'t on the device, the clearest that is; the device\'s where chosen', () async {
      voices.readyIds.addAll(['a', 'b']);
      settings = const VoiceSettings(torah: 'a', targum: 'c', haftarah: VoiceSettings.deviceVoice);
      await tts.setLanguage('he-IL');
      tts.role = SpeechRole.targum;
      await tts.speak(pointed);
      expect(voices.asked.last.$2, 'b', reason: 'c is not on the device; b is clearer than a');
      tts.role = SpeechRole.haftarah;
      await tts.speak(pointed);
      expect(spokenByDevice(), hasLength(1));
      tts.role = SpeechRole.mikrah;
      await tts.speak(pointed);
      expect(voices.asked.last.$2, 'a');
    });

    test('leaves unpointed Hebrew and other languages to the device', () async {
      voices.readyIds.add('a');
      await tts.setLanguage('he-IL');
      await tts.speak('ויאמר רש"י');
      await tts.setLanguage('en-US');
      await tts.speak('And God said');
      expect(voices.asked, isEmpty);
      expect(spokenByDevice(), ['ויאמר רש"י', 'And God said']);
    });

    test('makes the next utterance ahead of its turn, and reads it from there', () async {
      voices.readyIds.add('a');
      await tts.setLanguage('he-IL');
      tts.prefetch(pointed, role: SpeechRole.mikrah);
      expect(voices.asked, hasLength(1));
      await tts.speak(pointed);
      expect(voices.asked, hasLength(1), reason: 'made once');
    });

    test('stopped while the audio is being made or played, reports a cancel and plays nothing more', () async {
      voices.readyIds.add('a');
      await tts.setLanguage('he-IL');
      voices.hold = Completer<void>();
      final speaking = tts.speak(pointed);
      await Future<void>.delayed(Duration.zero);
      await tts.stop();
      voices.hold!.complete();
      expect(await speaking, 1);
      expect(events, ['cancel']);
      expect(player.played, isEmpty);
      expect(device.where((c) => c.method == 'stop'), isEmpty, reason: 'the device engine was not speaking');

      voices.hold = null;
      await tts.speak('$pointed ׃');
      await tts.stop();
      expect(player.stops, 1);
      expect(events, ['cancel', 'start', 'cancel']);
    });

    test('should the voice fail, the device reads in its place', () async {
      voices
        ..readyIds.add('a')
        ..fail = true;
      await tts.setLanguage('he-IL');
      await tts.speak(pointed);
      expect(spokenByDevice().single, 'בְּרֵאשִׁית בָּרָא אֱלֹהִים');
      expect(player.played, isEmpty);
    });
  });
}
