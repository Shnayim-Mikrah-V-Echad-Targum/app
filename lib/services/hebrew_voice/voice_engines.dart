import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'npz.dart';
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
    };

Future<Map<String, dynamic>> _json(VoiceStore store, VoiceFile file) async =>
    jsonDecode(utf8.decode(await store.read(file))) as Map<String, dynamic>;

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

/// An int64 tensor, built as int32, which every platform's lists hold (the
/// web's have no int64), and converted.
Future<OrtValue> _int64(List<int> data, List<int> shape, List<OrtValue> values) async {
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
  Future<Float32List> synthesize(String sounds, {required VoiceSpec voice, required String spoken, required VoiceTuning tuning}) =>
      _withValues((values) async {
        final ids = this.ids(symbols(sounds, spoken));
        final scales = Float32List.fromList([
          tuning.variation ?? spec.noise,
          spec.length / tuning.speed.clamp(0.25, 4.0),
          tuning.rhythm ?? spec.noiseWidth,
        ]);
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
  })  : _dp = durationPredictor,
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
        NpyArray array(Map<String, dynamic> m) => NpyArray(
              [for (final d in m['dims'] as List) (d as num).toInt()],
              Float32List.fromList([for (final x in _flatten(m['data'])) x.toDouble()]),
            );
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
