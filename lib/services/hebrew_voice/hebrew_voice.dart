import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/text/hebrew_phonemes.dart';
import 'voice_model.dart';
import 'voice_model_io.dart' if (dart.library.js_interop) 'voice_model_web.dart' as platform;

/// Where the Hebrew voice is, on the device.
enum HebrewVoiceState {
  /// Not on the device: the device's own Hebrew voice reads.
  absent,

  /// Being fetched ([HebrewVoice.progress]).
  downloading,

  /// On the device, and reading the pointed Hebrew and Aramaic.
  ready,

  /// The last fetch failed; tried again from Settings.
  failed,
}

/// The app's own Hebrew voice, which reads the vowels as written, and the
/// stress the cantillation marks (HebrewPhonemes): for a reader who can't
/// read the text, or see it, and on a device with no Hebrew voice of its own.
///
/// It is the "Shaul" voice of Phonikud TTS (a Piper VITS model, trained on
/// the SASPEECH recordings; licensed for non-commercial use, CC BY-NC), run
/// on the device by ONNX Runtime. It is fetched once, when the reader turns
/// it on in Settings, from its publisher's copy at a fixed revision, and
/// checked against its digest.
class HebrewVoice {
  HebrewVoice({VoiceModel? model, OrtSessionFactory? openSession})
      : _model = model ?? platform.voiceModel(),
        _openSession = openSession ?? _defaultSession;

  static const url =
      'https://huggingface.co/Phonikud/phonikud-tts-checkpoints/resolve/ff64ba389a3833c49a85c58fc51a7060a6984b87/shaul.onnx';
  static const sizeBytes = 63516050;
  static const sha256 = '7bcbd364b0bc357df8ef6c7c873e48f22897df16ec6c9d8f9d7ef792f6ae03c9';
  static const sampleRate = 22050;

  /// The voice's own scales: how much it varies its sound and its timing.
  static const _noiseScale = 0.667;
  static const _noiseWidth = 0.8;

  final VoiceModel _model;
  final OrtSessionFactory _openSession;

  final state = ValueNotifier(HebrewVoiceState.absent);

  /// How much of the voice has been fetched, from 0 to 1, while it is.
  final progress = ValueNotifier<double>(0);

  bool get ready => state.value == HebrewVoiceState.ready;

  Future<OrtSession>? _session;
  bool _disposed = false;

  /// Finds whether the voice is on the device already.
  Future<void> init() async {
    try {
      if (await _model.present() && !_disposed) state.value = HebrewVoiceState.ready;
    } catch (_) {
      // Unknown: as if absent, to fetch again.
    }
  }

  /// Fetches the voice, and readies it. Throws if it can't be fetched.
  Future<void> install() async {
    if (state.value == HebrewVoiceState.downloading || ready) return;
    state.value = HebrewVoiceState.downloading;
    progress.value = 0;
    try {
      await _model.fetch(onProgress: (p) {
        if (!_disposed) progress.value = p;
      });
      if (!_disposed) state.value = HebrewVoiceState.ready;
    } catch (_) {
      if (!_disposed) state.value = HebrewVoiceState.failed;
      rethrow;
    }
  }

  /// Takes the voice off the device: the device's own voice reads again.
  Future<void> remove() async {
    final session = _session;
    _session = null;
    if (session != null) unawaited(session.then((s) => s.close()).then((_) {}, onError: (Object _) {}));
    await _model.remove();
    if (!_disposed) state.value = HebrewVoiceState.absent;
  }

  /// [text], pointed Hebrew or Aramaic (with its cantillation, where it has
  /// it), spoken at [rate] (the speech service's scale, on which 0.5 is the
  /// voice's own pace) as a WAV file.
  Future<Uint8List> speak(String text, {double rate = 0.5}) async {
    final audio = await synthesize(HebrewPhonemes.phonemize(text), lengthScale: lengthScaleFor(rate));
    return wav(audio);
  }

  /// The length scale for [rate]: 0.5 is the voice's own pace, 1 twice as
  /// fast, 0.25 half as fast.
  @visibleForTesting
  static double lengthScaleFor(double rate) => 0.5 / rate.clamp(0.1, 1.0);

  /// The audio of [phonemes] (HebrewPhonemes), at [sampleRate].
  Future<Float32List> synthesize(String phonemes, {double lengthScale = 1}) async {
    if (!ready) throw StateError('The Hebrew voice is not on the device.');
    final session = await (_session ??= _open());
    final ids = phonemeIds(phonemes);
    // Built as int32, which every platform's lists hold (the web's have no
    // int64), and given to the model as the int64 it takes.
    final values = <OrtValue>[];
    Future<OrtValue> int64(List<int> data, List<int> shape) async {
      final v32 = await OrtValue.fromList(Int32List.fromList(data), shape);
      values.add(v32);
      final v64 = await v32.to(OrtDataType.int64);
      values.add(v64);
      return v64;
    }

    try {
      final scales = await OrtValue.fromList(Float32List.fromList([_noiseScale, lengthScale, _noiseWidth]), [3]);
      values.add(scales);
      final outputs = await session.run({
        'input': await int64(ids, [1, ids.length]),
        'input_lengths': await int64([ids.length], [1]),
        'scales': scales,
      });
      values.addAll(outputs.values);
      final samples = await outputs.values.first.asFlattenedList();
      return Float32List.fromList([for (final s in samples) (s as num).toDouble()]);
    } finally {
      for (final v in values) {
        unawaited(v.dispose().then((_) {}, onError: (Object _) {}));
      }
    }
  }

  Future<OrtSession> _open() async {
    try {
      return await _openSession(await _model.location());
    } catch (_) {
      _session = null;
      rethrow;
    }
  }

  static Future<OrtSession> _defaultSession(String location) => OnnxRuntime().createSession(location);

  /// The model's ids for [phonemes], as Piper takes them: the start, each
  /// sound followed by a pad, and the end. A sound the voice lacks is left
  /// out.
  static List<int> phonemeIds(String phonemes) {
    final ids = [_ids['^']!, _ids['_']!];
    for (final rune in phonemes.runes) {
      final id = _ids[String.fromCharCode(rune)];
      if (id == null) continue;
      ids
        ..add(id)
        ..add(_ids['_']!);
    }
    return ids..add(_ids[r'$']!);
  }

  /// The voice's ids for the sounds HebrewPhonemes writes (its
  /// model.config.json, phoneme_id_map: espeak's IPA symbols).
  static const _ids = {
    '_': 0, '^': 1, r'$': 2, ' ': 3, '!': 4, ',': 8, '.': 10, '?': 13, //
    'a': 14, 'b': 15, 'd': 17, 'e': 18, 'f': 19, 'h': 20, 'i': 21, 'j': 22, 'k': 23, 'l': 24, 'm': 25,
    'n': 26, 'o': 27, 'p': 28, 's': 31, 't': 32, 'u': 33, 'v': 34, 'z': 38, //
    'ɡ': 66, 'ʁ': 94, 'ʃ': 96, 'ʒ': 108, 'ʔ': 109, 'ˈ': 120, 'χ': 127,
  };

  /// Whether the voice speaks [symbol] (for the tests).
  @visibleForTesting
  static bool speaks(String symbol) => _ids.containsKey(symbol);

  /// [audio] as a 16-bit mono WAV file, brought up to a common loudness:
  /// the voice speaks softly.
  static Uint8List wav(Float32List audio) {
    var peak = 0.0;
    for (final s in audio) {
      peak = math.max(peak, s.abs());
    }
    final gain = peak > 0 ? 0.9 / peak : 1.0;
    final data = ByteData(44 + audio.length * 2);
    void ascii(int at, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(at + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    data.setUint32(4, 36 + audio.length * 2, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    data.setUint32(40, audio.length * 2, Endian.little);
    for (var i = 0; i < audio.length; i++) {
      data.setInt16(44 + i * 2, (audio[i] * gain * 32767).round().clamp(-32768, 32767), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  void dispose() {
    _disposed = true;
    final session = _session;
    _session = null;
    if (session != null) unawaited(session.then((s) => s.close()).then((_) {}, onError: (Object _) {}));
    state.dispose();
    progress.dispose();
  }
}

/// Opens an ONNX Runtime session on the model at a location (a file, or on
/// the web a URL).
typedef OrtSessionFactory = Future<OrtSession> Function(String location);

final hebrewVoiceProvider = Provider<HebrewVoice>((ref) {
  final voice = HebrewVoice();
  unawaited(voice.init());
  ref.onDispose(voice.dispose);
  return voice;
});
