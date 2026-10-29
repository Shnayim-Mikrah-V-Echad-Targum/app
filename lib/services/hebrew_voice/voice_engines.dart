import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'npz.dart';
import 'onnx_graphs.dart';
import 'voice_catalogue.dart';
import 'voice_store.dart';

/// Opens an ONNX Runtime session on the model at a location (a file, or on
/// the web a URL).
typedef OrtSessionFactory = Future<OrtSession> Function(String location);

/// How the voices read one utterance, as the reader has set them
/// (VoiceSettings).
class VoiceTuning {
  const VoiceTuning({this.speed = 1, this.variation, this.rhythm, this.steps = 8, this.guidance = 3});

  /// How fast, relative to the voice's own pace.
  final double speed;

  /// A Piper voice's variation of sound (its noise scale); null for the
  /// voice's own.
  final double? variation;

  /// A Piper voice's variation of timing (its noise width); null for the
  /// voice's own.
  final double? rhythm;

  /// A Blue voice's steps from noise to speech: more are cleaner, and slower.
  final int steps;

  /// How closely a Blue voice keeps to the text, where the model leaves it
  /// to be set.
  final double guidance;
}

/// A voice's model, opened: it turns the sounds of an utterance
/// (HebrewPhonemes) into audio. One model of many voices (Blue) is opened
/// once for them all: [voice] says whose style it reads in.
abstract class VoiceRunner {
  int get sampleRate;

  /// The audio of [sounds], read by [voice], at [sampleRate]. [spoken] is
  /// the text they were made from, which a voice that reads the letters
  /// reads instead.
  Future<Float32List> synthesize(String sounds, {required VoiceSpec voice, required String spoken, required VoiceTuning tuning});

  Future<void> close();
}

/// Opens [spec]'s model, its files on the device in [store].
Future<VoiceRunner> openVoice(VoiceSpec spec, VoiceStore store, OrtSessionFactory open) => switch (spec) {
  PiperSpec() => PiperRunner.open(spec, store, open),
  KokoroSpec() => KokoroRunner.open(spec, store, open),
  BlueSpec() => BlueRunner.open(spec, store, open),
  PocketSpec() => PocketRunner.open(spec, store, open),
};

Future<Map<String, dynamic>> _json(VoiceStore store, VoiceFile file) async => jsonDecode(utf8.decode(await store.read(file))) as Map<String, dynamic>;

/// Runs [body] with a list to put the values it makes in, which are all
/// let go of afterwards.
Future<T> _withValues<T>(Future<T> Function(List<OrtValue> values) body) async {
  final values = <OrtValue>[];
  try {
    return await body(values);
  } finally {
    for (final v in values) {
      unawaited(v.dispose().then((_) {}, onError: (Object _) {}));
    }
  }
}

/// An int64 tensor: on the web, whose lists hold no int64, built as int32
/// and converted.
Future<OrtValue> _int64(List<int> data, List<int> shape, List<OrtValue> values) async {
  if (!kIsWeb) {
    final v = await OrtValue.fromList(Int64List.fromList(data), shape);
    values.add(v);
    return v;
  }
  final v32 = await OrtValue.fromList(Int32List.fromList(data), shape);
  values.add(v32);
  final v64 = await v32.to(OrtDataType.int64);
  values.add(v64);
  return v64;
}

Future<OrtValue> _float(Float32List data, List<int> shape, List<OrtValue> values) async {
  final v = await OrtValue.fromList(data, shape);
  values.add(v);
  return v;
}

Future<Float32List> _floats(OrtValue v) async {
  final list = await v.asFlattenedList();
  if (list is Float32List) return list;
  return Float32List.fromList([for (final s in list) (s as num).toDouble()]);
}

Float32List _ones(int n) => Float32List(n)..fillRange(0, n, 1);

/// [sounds] in pieces of at most [max] characters, split after a pause (a
/// comma or full stop) where it can be, else between words: for models
/// that read only so much at once.
List<String> splitSounds(String sounds, int max) {
  if (sounds.length <= max) return [sounds];
  final pieces = <String>[];
  var current = '';
  void add(String part) {
    if (current.isNotEmpty && current.length + 1 + part.length > max) {
      pieces.add(current);
      current = '';
    }
    current = current.isEmpty ? part : '$current $part';
  }

  for (final clause in sounds.split(RegExp(r'(?<=[,.])\s+'))) {
    if (clause.length <= max) {
      add(clause);
    } else {
      clause.split(' ').forEach(add);
    }
  }
  if (current.isNotEmpty) pieces.add(current);
  return pieces;
}

/// [parts] one after another, a breath of [gap] seconds between them.
Float32List _join(List<Float32List> parts, int rate, {double gap = 0.15}) {
  if (parts.length == 1) return parts.single;
  final silence = (gap * rate).round();
  final out = Float32List(parts.fold<int>(0, (a, p) => a + p.length) + silence * (parts.length - 1));
  var at = 0;
  for (var i = 0; i < parts.length; i++) {
    if (i > 0) at += silence;
    out.setAll(at, parts[i]);
    at += parts[i].length;
  }
  return out;
}

// --- Piper -------------------------------------------------------------------

class PiperRunner implements VoiceRunner {
  PiperRunner._(this.spec, this._session, this._ids, this._letters, this.sampleRate);

  static Future<PiperRunner> open(PiperSpec spec, VoiceStore store, OrtSessionFactory open) async {
    final config = await _json(store, spec.config);
    final ids = {
      for (final e in (config['phoneme_id_map'] as Map).entries) e.key as String: [for (final i in e.value as List) i as int],
    };
    final letters = spec.letters == null ? null : (await _json(store, spec.letters!)).cast<String, String>();
    final rate = ((config['audio'] as Map?)?['sample_rate'] as num?)?.toInt() ?? 22050;
    return PiperRunner._(spec, await open(await store.location(spec.model)), ids, letters, rate);
  }

  final PiperSpec spec;
  final OrtSession _session;
  final Map<String, List<int>> _ids;
  final Map<String, String>? _letters;

  @override
  final int sampleRate;

  /// The symbols the model reads: the sounds, or for a model that reads the
  /// letters, the letters and points of [spoken] (without the cantillation),
  /// as it was trained to see them.
  String symbols(String sounds, String spoken) {
    final letters = _letters;
    if (letters == null) return sounds;
    final out = StringBuffer();
    for (final rune in spoken.runes) {
      final cantillation = (rune >= 0x0591 && rune <= 0x05AF) || rune == 0x05BD || rune == 0x05C0 || rune == 0x05C3;
      final point = rune >= 0x05B0 && rune <= 0x05C7;
      if (cantillation || (point && spec.input == PiperInput.bareLetters)) continue;
      final c = String.fromCharCode(rune);
      out.write(letters[c] ?? c);
    }
    return out.toString();
  }

  /// The model's ids for [symbols]: the start, each symbol (with a pad after
  /// it, as Piper trains, unless the model was trained without), and the
  /// end. A symbol it lacks is left out.
  List<int> ids(String symbols) {
    final pad = spec.input == PiperInput.soundsUnpadded ? const <int>[] : _ids['_']!;
    final out = [..._ids['^']!, ...pad];
    for (final rune in symbols.runes) {
      final id = _ids[String.fromCharCode(rune)];
      if (id == null) continue;
      out
        ..addAll(id)
        ..addAll(pad);
    }
    return out..addAll(_ids[r'$']!);
  }

  @override
  Future<Float32List> synthesize(String sounds, {required VoiceSpec voice, required String spoken, required VoiceTuning tuning}) => _withValues((values) async {
    final ids = this.ids(symbols(sounds, spoken));
    final scales = Float32List.fromList([tuning.variation ?? spec.noise, spec.length / tuning.speed.clamp(0.25, 4.0), tuning.rhythm ?? spec.noiseWidth]);
    final outputs = await _session.run({
      'input': await _int64(ids, [1, ids.length], values),
      'input_lengths': await _int64([ids.length], [1], values),
      'scales': await _float(scales, [3], values),
      if (spec.speaker != null) 'sid': await _int64([spec.speaker!], [1], values),
    });
    values.addAll(outputs.values);
    return _floats(outputs.values.first);
  });

  @override
  Future<void> close() => _session.close();
}

// --- Kokoro ------------------------------------------------------------------

class KokoroRunner implements VoiceRunner {
  KokoroRunner._(this._session, this._vocab, this._styles, this._styleCount);

  /// Kokoro reads 510 symbols at most at once.
  static const maxSymbols = 500;
  static const _styleSize = 256;

  static Future<KokoroRunner> open(KokoroSpec spec, VoiceStore store, OrtSessionFactory open) async {
    final config = await _json(store, spec.config);
    final vocab = {for (final e in (config['vocab'] as Map).entries) e.key as String: (e.value as num).toInt()};
    final styles = readNpz(await store.read(spec.styles))[spec.style];
    if (styles == null) throw FormatException('No style ${spec.style}');
    return KokoroRunner._(await open(await store.location(spec.model)), vocab, styles.data, styles.shape.first);
  }

  final OrtSession _session;
  final Map<String, int> _vocab;
  final Float32List _styles;
  final int _styleCount;

  @override
  int get sampleRate => 24000;

  @override
  Future<Float32List> synthesize(String sounds, {required VoiceSpec voice, required String spoken, required VoiceTuning tuning}) async {
    final parts = <Float32List>[];
    for (final piece in splitSounds(sounds, maxSymbols)) {
      parts.add(await _piece(piece, tuning));
    }
    return _join(parts, sampleRate);
  }

  Future<Float32List> _piece(String sounds, VoiceTuning tuning) => _withValues((values) async {
    final tokens = [for (final rune in sounds.runes) ?_vocab[String.fromCharCode(rune)]];
    // One style for each number of symbols: n of them take row n - 1.
    final row = math.min(math.max(tokens.length, 1), _styleCount) - 1;
    final style = Float32List.sublistView(_styles, row * _styleSize, (row + 1) * _styleSize);
    final ids = [0, ...tokens, 0];
    final outputs = await _session.run({
      'input_ids': await _int64(ids, [1, ids.length], values),
      'style': await _float(Float32List.fromList(style), [1, _styleSize], values),
      'speed': await _float(Float32List.fromList([tuning.speed.clamp(0.5, 2.0)]), [1], values),
    });
    values.addAll(outputs.values);
    return _floats(outputs['waveform'] ?? outputs.values.first);
  });

  @override
  Future<void> close() => _session.close();
}

// --- Blue --------------------------------------------------------------------

class BlueRunner implements VoiceRunner {
  BlueRunner._({
    required this.spec,
    required this.sampleRate,
    required this.baseChunk,
    required this.compress,
    required this.latentDim,
    required OrtSession durationPredictor,
    required OrtSession textEncoder,
    required OrtSession vectorEstimator,
    required OrtSession vocoder,
    required this._vocab,
    required int padId,
    required this._store,
    this.mean,
    this.std,
    this.scale = 1,
    this.uText,
    this.uRef,
    math.Random? random,
  }) : _dp = durationPredictor,
       _te = textEncoder,
       _ve = vectorEstimator,
       _vo = vocoder,
       _pad = padId,
       _random = random ?? math.Random();

  /// A Blue model's duration saturates near 16.5 seconds: longer text is
  /// read in pieces.
  static const maxSymbols = 200;

  static Future<BlueRunner> open(BlueSpec spec, VoiceStore store, OrtSessionFactory open) async {
    final config = await _json(store, spec.config);
    final vocab = await _json(store, spec.vocab);
    final stats = spec.stats == null ? null : readNpz(await store.read(spec.stats!));
    final uncond = spec.uncond == null ? null : readNpz(await store.read(spec.uncond!));
    final ae = config['ae'] as Map;
    final ttl = config['ttl'] as Map;
    return BlueRunner._(
      spec: spec,
      sampleRate: (ae['sample_rate'] as num).toInt(),
      baseChunk: (ae['base_chunk_size'] as num).toInt(),
      compress: (ttl['chunk_compress_factor'] as num).toInt(),
      latentDim: (ttl['latent_dim'] as num).toInt(),
      durationPredictor: await open(await store.location(spec.durationPredictor)),
      textEncoder: await open(await store.location(spec.textEncoder)),
      vectorEstimator: await open(await store.location(spec.vectorEstimator)),
      vocoder: await open(await store.location(spec.vocoder)),
      vocab: {for (final e in (vocab['char_to_id'] as Map).entries) e.key as String: (e.value as num).toInt()},
      padId: (vocab['pad_id'] as num?)?.toInt() ?? 0,
      store: store,
      mean: stats?['mean']?.data,
      std: stats?['std']?.data,
      scale: stats?['normalizer_scale']?.data.first ?? 1,
      uText: uncond?['u_text'],
      uRef: uncond?['u_ref'],
    );
  }

  static Iterable<num> _flatten(Object? data) sync* {
    if (data is num) {
      yield data;
    } else if (data is List) {
      for (final d in data) {
        yield* _flatten(d);
      }
    }
  }

  final BlueSpec spec;
  @override
  final int sampleRate;
  final int baseChunk;
  final int compress;
  final int latentDim;
  final OrtSession _dp;
  final OrtSession _te;
  final OrtSession _ve;
  final OrtSession _vo;
  final Map<String, int> _vocab;
  final int _pad;
  final VoiceStore _store;

  // Each voice's style, read once: for the acoustic model, and for the
  // duration.
  final _styles = <VoiceFile, Future<(NpyArray, NpyArray)>>{};

  Future<(NpyArray, NpyArray)> _style(VoiceFile file) => _styles[file] ??= () async {
    final style = await _json(_store, file);
    NpyArray array(Map<String, dynamic> m) =>
        NpyArray([for (final d in m['dims'] as List) (d as num).toInt()], Float32List.fromList([for (final x in _flatten(m['data'])) x.toDouble()]));
    return (array(style['style_ttl'] as Map<String, dynamic>), array(style['style_dp'] as Map<String, dynamic>));
  }();
  final Float32List? mean;
  final Float32List? std;
  final double scale;
  final NpyArray? uText;
  final NpyArray? uRef;
  final math.Random _random;

  int get _channels => latentDim * compress;

  @override
  Future<Float32List> synthesize(String sounds, {required VoiceSpec voice, required String spoken, required VoiceTuning tuning}) async {
    final style = await _style((voice as BlueSpec).style);
    final parts = <Float32List>[];
    for (final piece in splitSounds(sounds, maxSymbols)) {
      parts.add(await _piece(piece, tuning, style));
    }
    return _join(parts, sampleRate);
  }

  double _gaussian() {
    // Box-Muller.
    final u = 1 - _random.nextDouble();
    final v = _random.nextDouble();
    return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
  }

  Future<Float32List> _piece(String sounds, VoiceTuning tuning, (NpyArray, NpyArray) style) => _withValues((values) async {
    final (styleTtl, styleDuration) = style;
    final text = RegExp(r'[.!?;:,]$').hasMatch(sounds) ? sounds : '$sounds.';
    final ids = [for (final rune in text.runes) _vocab[String.fromCharCode(rune)] ?? _pad];
    final n = ids.length;
    final textIds = await _int64(ids, [1, n], values);
    final textMask = await _float(_ones(n), [1, 1, n], values);
    final ttl = await _float(styleTtl.data, styleTtl.shape, values);
    final styleDp = await _float(styleDuration.data, styleDuration.shape, values);

    final dpOut = await _dp.run({'text_ids': textIds, 'style_dp': styleDp, 'text_mask': textMask});
    values.addAll(dpOut.values);
    final seconds = (await _floats(dpOut.values.first)).first / tuning.speed.clamp(0.25, 4.0);
    final teOut = await _te.run({'text_ids': textIds, 'style_ttl': ttl, 'text_mask': textMask});
    values.addAll(teOut.values);
    final textEmb = teOut.values.first;

    final chunk = baseChunk * compress;
    final frames = math.max(1, ((seconds * sampleRate).floor() + chunk - 1) ~/ chunk);
    final noise = Float32List(_channels * frames);
    for (var i = 0; i < noise.length; i++) {
      noise[i] = _gaussian();
    }
    var x = await _float(noise, [1, _channels, frames], values);
    final latentMask = await _float(_ones(frames), [1, 1, frames], values);
    final steps = tuning.steps.clamp(1, 64);
    final total = await _float(Float32List.fromList([steps.toDouble()]), [1], values);
    final cfg = await _float(Float32List.fromList([tuning.guidance]), [1], values);
    final OrtValue? uTextValue = uText == null ? null : await _float(uText!.data, uText!.shape, values);
    final OrtValue? uRefValue = uRef == null ? null : await _float(uRef!.data, uRef!.shape, values);
    final uMask = uText == null ? null : await _float(_ones(uText!.shape.last), [1, 1, uText!.shape.last], values);

    for (var step = 0; step < steps; step++) {
      final current = await _float(Float32List.fromList([step.toDouble()]), [1], values);
      final feeds = {
        'noisy_latent': x,
        'text_emb': textEmb,
        'style_ttl': ttl,
        'latent_mask': latentMask,
        'text_mask': textMask,
        'current_step': current,
        'total_step': total,
      };
      switch (spec.guidance) {
        case BlueGuidance.input:
          final out = await _ve.run({...feeds, 'cfg_scale': cfg});
          values.addAll(out.values);
          x = out.values.first;
        case BlueGuidance.inGraph:
          final out = await _ve.run(feeds);
          values.addAll(out.values);
          x = out.values.first;
        case BlueGuidance.runtime:
          // v = v_uncond + s (v_cond - v_uncond), each step's output being
          // x + v / steps: the next x is x_uncond + s (x_cond - x_uncond).
          final conditioned = await _ve.run(feeds);
          values.addAll(conditioned.values);
          final unconditioned = await _ve.run({...feeds, 'text_emb': uTextValue!, 'style_ttl': uRefValue!, 'text_mask': uMask!});
          values.addAll(unconditioned.values);
          final c = await _floats(conditioned.values.first);
          final u = await _floats(unconditioned.values.first);
          final s = tuning.guidance;
          final next = Float32List(c.length);
          for (var i = 0; i < c.length; i++) {
            next[i] = u[i] + s * (c[i] - u[i]);
          }
          x = await _float(next, [1, _channels, frames], values);
      }
    }

    var latent = x;
    var shape = [1, _channels, frames];
    if (mean != null || spec.foldLatent) {
      var z = await _floats(x);
      if (mean != null) {
        z = Float32List.fromList(z);
        for (var ch = 0; ch < _channels; ch++) {
          final m = mean![ch], d = std![ch];
          for (var t = 0; t < frames; t++) {
            final i = ch * frames + t;
            z[i] = z[i] / scale * d + m;
          }
        }
      }
      if (spec.foldLatent) {
        // [1, latentDim * compress, T] as [1, latentDim, T * compress].
        final folded = Float32List(z.length);
        for (var d = 0; d < latentDim; d++) {
          for (var k = 0; k < compress; k++) {
            for (var t = 0; t < frames; t++) {
              folded[d * frames * compress + t * compress + k] = z[(d * compress + k) * frames + t];
            }
          }
        }
        z = folded;
        shape = [1, latentDim, frames * compress];
      }
      latent = await _float(z, shape, values);
    }
    final voOut = await _vo.run({_vo.inputNames.first: latent});
    values.addAll(voOut.values);
    final wav = await _floats(voOut.values.first);
    // The vocoder's first and last frames are its warm-up and tail.
    return wav.length > 2 * chunk ? Float32List.sublistView(wav, chunk, wav.length - chunk) : wav;
  });

  @override
  Future<void> close() async {
    for (final s in [_dp, _te, _ve, _vo]) {
      await s.close();
    }
  }
}

// --- Pocket TTS --------------------------------------------------------------

/// Pocket TTS: one streaming step at a time, each making 80 ms of audio from
/// the keys and values of every step before it. Those are kept in ONNX
/// Runtime, joined by small models of the app's own (OnnxGraphs), so that
/// only the audio and the end-of-speech score cross into Dart each step.
class PocketRunner implements VoiceRunner {
  PocketRunner._(this._step, this._concat, this._window, this._config, this._voices, this._ids, this._space, this._pieces);

  static Future<PocketRunner> open(PocketSpec spec, VoiceStore store, OrtSessionFactory open) async {
    final assets = await _json(store, spec.assets);
    final config = assets['config'] as Map<String, dynamic>;
    final lora = config['lora'] as Map<String, dynamic>;
    final atomic = (lora['atomic_chars'] ?? lora['ipa_chars']) as String;
    final base = (lora['vocab_base'] as num).toInt();
    final ids = <String, int>{};
    var i = 0;
    for (final rune in atomic.runes) {
      ids[String.fromCharCode(rune)] = base + i++;
    }
    final pieces = _sentencePieces(base64.decode(assets['tokenizer'] as String));
    int n(String key) => (config[key] as num).toInt();
    final flowRest = [n('flow_layers'), 2, 1, n('flow_heads'), n('flow_head_dim')];
    final mimiRest = [n('mimi_layers'), 2, 1, n('mimi_heads'), n('mimi_head_dim')];
    final step = await open(await store.location(spec.model));
    final concat = await open(await store.made('pocket-concat-${flowRest.join('x')}.onnx', OnnxGraphs.concat(flowRest)));
    final window = await open(
      await store.made(
        'pocket-window-${mimiRest.join('x')}-${n('mimi_kv_len')}-${n('mimi_steps_per_latent')}.onnx',
        OnnxGraphs.window(mimiRest, keep: n('mimi_kv_len'), step: n('mimi_steps_per_latent')),
      ),
    );
    return PocketRunner._(step, concat, window, config, (assets['voices'] as Map).cast<String, String>(), ids, pieces['▁'] ?? 0, pieces);
  }

  /// The pieces of a SentencePiece model, by text: their ids are their
  /// places in it.
  static Map<String, int> _sentencePieces(Uint8List proto) {
    final pieces = <String, int>{};
    var at = 0;
    int varint() {
      var result = 0, shift = 0;
      while (true) {
        final b = proto[at++];
        result += (b & 0x7f) * math.pow(2, shift).toInt();
        if (b < 0x80) return result;
        shift += 7;
      }
    }

    while (at < proto.length) {
      final key = varint();
      switch (key & 7) {
        case 2:
          final length = varint();
          if (key >> 3 == 1) {
            // A piece: its text is its field 1.
            var p = at;
            final end = at + length;
            while (p < end) {
              final k = proto[p++];
              if (k == 0x0a) {
                var len = 0, shift = 0;
                while (true) {
                  final b = proto[p++];
                  len += (b & 0x7f) << shift;
                  if (b < 0x80) break;
                  shift += 7;
                }
                pieces.putIfAbsent(utf8.decode(proto.sublist(p, p + len)), () => pieces.length);
                break;
              }
              break;
            }
          }
          at += length;
        case 0:
          varint();
        case 5:
          at += 4;
        case 1:
          at += 8;
      }
    }
    return pieces;
  }

  final OrtSession _step;
  final OrtSession _concat;
  final OrtSession _window;
  final Map<String, dynamic> _config;
  final Map<String, String> _voices;
  final Map<String, int> _ids;
  final int _space;
  final Map<String, int> _pieces;
  final _random = math.Random();

  // Each voice's keys and values, prefilled once: its length, and the value.
  final _prefilled = <String, Future<(int, OrtValue)>>{};

  int _n(String key) => (_config[key] as num).toInt();
  Map<String, dynamic> get _lora => _config['lora'] as Map<String, dynamic>;
  Map<String, dynamic> get _defaults => (_lora['defaults'] as Map?)?.cast<String, dynamic>() ?? const {};

  @override
  int get sampleRate => _n('sample_rate');

  /// The ids of [sounds]: one for each sound, and for what lies between
  /// them, the tokenizer's word boundary and any punctuation.
  List<int> tokens(String sounds) {
    final out = <int>[];
    final pending = StringBuffer();
    void flush() {
      final run = pending.toString().trim();
      pending.clear();
      if (out.isEmpty && run.isEmpty) return;
      out.add(_space);
      for (final rune in run.runes) {
        final id = _pieces[String.fromCharCode(rune)];
        if (id != null) out.add(id);
      }
    }

    for (final rune in sounds.runes) {
      final id = _ids[String.fromCharCode(rune)];
      if (id == null) {
        pending.writeCharCode(rune);
      } else {
        if (pending.isNotEmpty) flush();
        out.add(id);
      }
    }
    if (pending.isNotEmpty) flush();
    return out;
  }

  /// [voice]'s conditioning: float16, as base64.
  Float32List _conditioning(String voice) {
    final bytes = base64.decode(_voices[voice]!);
    final data = ByteData.sublistView(bytes);
    final out = Float32List(bytes.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = _half(data.getUint16(i * 2, Endian.little));
    }
    return out;
  }

  static double _half(int h) {
    final sign = (h & 0x8000) != 0 ? -1.0 : 1.0;
    final exponent = (h >> 10) & 0x1f;
    final fraction = h & 0x3ff;
    if (exponent == 0) return sign * fraction * math.pow(2, -24);
    if (exponent == 31) return fraction == 0 ? sign * double.infinity : double.nan;
    return sign * (1 + fraction / 1024) * math.pow(2, exponent - 15);
  }

  Future<OrtValue> _scalar64(int v, List<OrtValue> values) => _int64([v], const [], values);
  Future<OrtValue> _scalar(double v, List<OrtValue> values) => _float(Float32List.fromList([v]), const [], values);

  /// The feeds of one step, as the graph takes them (older exports lack some).
  Map<String, OrtValue> _feeds(Map<String, OrtValue> all) => {
    for (final MapEntry(:key, :value) in all.entries)
      if (_step.inputNames.contains(key)) key: value,
  };

  Future<(int, OrtValue)> _prefill(String voice) => _prefilled[voice] ??= _withValues((values) async {
    final shape = [for (final d in (_config['voices'] as Map)[voice] as List) (d as num).toInt()];
    final length = shape.first;
    final model = _n('model_dim');
    final flowRest = [_n('flow_layers'), 2, 1, _n('flow_heads'), _n('flow_head_dim')];
    final mimiRest = [_n('mimi_layers'), 2, 1, _n('mimi_heads'), _n('mimi_head_dim')];
    final mimiLength = _n('mimi_kv_len') * mimiRest.fold<int>(1, (a, b) => a * b);
    final out = await _step.run(
      _feeds({
        'tokens': await _int64(List.filled(length, 0), [1, length], values),
        'latent': await _float(Float32List(length * _n('latent_dim')), [1, length, _n('latent_dim')], values),
        'is_bos': await _float(Float32List(length), [1, length, 1], values),
        'cond': await _float(_conditioning(voice), [1, length, model], values),
        'gates': await _float(Float32List.fromList([0, 0, 1]), [3], values),
        'noise': await _float(Float32List(_n('latent_dim')), [1, _n('latent_dim')], values),
        'flow_kv': await _float(Float32List(0), [0, ...flowRest], values),
        'flow_offset': await _scalar64(0, values),
        'mimi_kv': await _float(Float32List(mimiLength), [_n('mimi_kv_len'), ...mimiRest], values),
        'mimi_offset': await _scalar64(0, values),
        'mimi_conv': await _float(Float32List(_n('conv_state_size')), [_n('conv_state_size')], values),
        'decode_steps': await _scalar(1, values),
        'lora': await _scalar(1, values),
      }),
    );
    final kept = out['flow_kv_new']!;
    values.addAll(out.values.where((v) => !identical(v, kept)));
    return (length, kept);
  });

  @override
  Future<Float32List> synthesize(String sounds, {required VoiceSpec voice, required String spoken, required VoiceTuning tuning}) async {
    final name = (voice as PocketSpec).voice;
    final limit = (_defaults['max_tokens_per_chunk'] as num?)?.toInt() ?? _n('max_tokens_per_chunk');
    final parts = <Float32List>[];
    for (final piece in splitSounds(sounds, (limit * 0.9).floor())) {
      parts.add(await _piece(piece, name, tuning));
    }
    return _join(parts, sampleRate);
  }

  Future<Float32List> _piece(String sounds, String voice, VoiceTuning tuning) => _withValues((values) async {
    final (voiceLength, voiceFlow) = await _prefill(voice);
    final ids = tokens(sounds);
    final t = ids.length;
    final latentDim = _n('latent_dim');
    final mimiRest = [_n('mimi_layers'), 2, 1, _n('mimi_heads'), _n('mimi_head_dim')];
    final mimiLength = _n('mimi_kv_len') * mimiRest.fold<int>(1, (a, b) => a * b);
    final temperature = tuning.variation ?? (_defaults['temperature'] as num?)?.toDouble() ?? (_config['temperature'] as num).toDouble();
    final afterEnd = (_defaults['frames_after_eos'] as num?)?.toInt() ?? 2;
    final maxFrames = ((t / (_config['tokens_per_second_estimate'] as num) + (_config['gen_seconds_padding'] as num)) * (_config['frame_rate'] as num)).ceil();
    final steps = await _scalar(((_config['sampler_decode_steps'] as num?) ?? 1).toDouble(), values);
    final lora = await _scalar(1, values);
    final zeroMimi = await _float(Float32List(mimiLength), [_n('mimi_kv_len'), ...mimiRest], values);
    final zeroConv = await _float(Float32List(_n('conv_state_size')), [_n('conv_state_size')], values);
    final zeroOffset = await _scalar64(0, values);

    // The text, after the voice.
    final text = await _step.run(
      _feeds({
        'tokens': await _int64(ids, [1, t], values),
        'latent': await _float(Float32List(t * latentDim), [1, t, latentDim], values),
        'is_bos': await _float(Float32List(t), [1, t, 1], values),
        'cond': await _float(Float32List(t * _n('model_dim')), [1, t, _n('model_dim')], values),
        'gates': await _float(Float32List.fromList([1, 0, 0]), [3], values),
        'noise': await _float(Float32List(latentDim), [1, latentDim], values),
        'flow_kv': voiceFlow,
        'flow_offset': await _scalar64(voiceLength, values),
        'mimi_kv': zeroMimi,
        'mimi_offset': zeroOffset,
        'mimi_conv': zeroConv,
        'decode_steps': steps,
        'lora': lora,
      }),
    );
    values.addAll(text.values);
    var flow = (await _concat.run({'past': voiceFlow, 'next': text['flow_kv_new']!})).values.single;
    values.add(flow);
    var flowLength = voiceLength + t;

    // Then the speech, a frame at a time, until it ends.
    var latent = await _float(Float32List(latentDim), [1, 1, latentDim], values);
    var isBos = await _float(Float32List.fromList([1]), [1, 1, 1], values);
    final notBos = await _float(Float32List.fromList([0]), [1, 1, 1], values);
    final gates = await _float(Float32List.fromList([0, 1, 0]), [3], values);
    final zeroToken = await _int64([0], [1, 1], values);
    final zeroCond = await _float(Float32List(_n('model_dim')), [1, 1, _n('model_dim')], values);
    var mimi = zeroMimi, conv = zeroConv, offset = zeroOffset;
    final threshold = (_config['eos_threshold'] as num).toDouble();
    final audio = <Float32List>[];
    int? end;
    final deviation = math.sqrt(temperature);
    for (var frame = 0; frame < maxFrames; frame++) {
      // Each step's own values go as soon as the next has taken what it needs.
      final stepValues = <OrtValue>[];
      final noise = Float32List(latentDim);
      for (var i = 0; i < latentDim; i++) {
        noise[i] = _gaussian() * deviation;
      }
      final out = await _step.run(
        _feeds({
          'tokens': zeroToken,
          'latent': latent,
          'is_bos': isBos,
          'cond': zeroCond,
          'gates': gates,
          'noise': await _float(noise, [1, latentDim], stepValues),
          'flow_kv': flow,
          'flow_offset': await _scalar64(flowLength, stepValues),
          'mimi_kv': mimi,
          'mimi_offset': offset,
          'mimi_conv': conv,
          'decode_steps': steps,
          'lora': lora,
        }),
      );
      final joined = (await _concat.run({'past': flow, 'next': out['flow_kv_new']!})).values.single;
      final windowed = (await _window.run({'past': mimi, 'next': out['mimi_kv_new']!})).values.single;
      final eos = (await _floats(out['eos_logit']!)).first;
      final sound = await _floats(out['audio']!);
      // Let go of what this step replaces: the caches it joined, and the
      // last step's state (but the zeros all steps start from).
      stepValues.addAll([out['flow_kv_new']!, out['mimi_kv_new']!, out['eos_logit']!, out['audio']!]);
      if (frame > 0) stepValues.addAll([flow, mimi, conv, offset, latent]);
      if (frame == 0 && !identical(flow, voiceFlow)) stepValues.add(flow);
      flow = joined;
      mimi = windowed;
      conv = out['mimi_conv_out']!;
      offset = out['mimi_offset_out']!;
      latent = out['next_latent']!;
      isBos = notBos;
      flowLength += 1;
      for (final v in stepValues) {
        unawaited(v.dispose().then((_) {}, onError: (Object _) {}));
      }
      if (end == null && eos > threshold) end = frame;
      if (end != null && frame >= end + afterEnd) break;
      audio.add(Float32List.fromList(sound));
    }
    values.addAll([flow, mimi, conv, offset, latent]);
    final out = Float32List(audio.fold<int>(0, (a, f) => a + f.length));
    var at = 0;
    for (final f in audio) {
      out.setAll(at, f);
      at += f.length;
    }
    return out;
  });

  double _gaussian() {
    final u = 1 - _random.nextDouble();
    final v = _random.nextDouble();
    return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
  }

  @override
  Future<void> close() async {
    for (final prefilled in _prefilled.values) {
      try {
        await (await prefilled).$2.dispose();
      } catch (_) {}
    }
    _prefilled.clear();
    for (final s in [_step, _concat, _window]) {
      await s.close();
    }
  }
}
