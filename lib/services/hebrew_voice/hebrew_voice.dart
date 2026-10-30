import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/text/hebrew_phonemes.dart';
import 'stretch.dart';
import 'voice_catalogue.dart';
import 'voice_engines.dart';
import 'voice_runtime.dart';
import 'voice_settings.dart';
import 'voice_store.dart';
import 'voice_store_io.dart' if (dart.library.js_interop) 'voice_store_web.dart' as platform;

export 'voice_engines.dart' show VoiceTuning;

/// Where a voice is, on the device.
enum HebrewVoiceState {
  /// Not on the device.
  absent,

  /// Being fetched ([HebrewVoiceStatus.progress]).
  downloading,

  /// On the device, and ready to read.
  ready,

  /// The last fetch failed; tried again from Settings.
  failed,
}

/// A voice's state, and while it is being fetched, how far it has come.
@immutable
class HebrewVoiceStatus {
  const HebrewVoiceStatus(this.state, {this.received = 0, this.total = 0});
  final HebrewVoiceState state;
  final int received;
  final int total;

  /// How much of the fetch has come, from 0 to 1.
  double get progress => total == 0 ? 0 : (received / total).clamp(0.0, 1.0);

  @override
  bool operator ==(Object other) => other is HebrewVoiceStatus && other.state == state && other.received == received && other.total == total;

  @override
  int get hashCode => Object.hash(state, received, total);
}

/// The app's own Hebrew voices ([hebrewVoices]), which read the vowels as
/// written, and the stress the cantillation marks (HebrewPhonemes): for a
/// reader who can't read the text, or see it, and on a device with no
/// Hebrew voice of its own.
///
/// Each is fetched when the reader asks for it, from its publisher's copy at
/// a fixed revision, checked against its digests, and run on the device by
/// ONNX Runtime. Voices of one model share its files, which are taken off
/// the device with the last of them.
class HebrewVoices {
  HebrewVoices({VoiceStore? store, VoiceRuntime? runtime, List<HebrewVoiceOption>? voices})
    : _store = store ?? platform.voiceStore(),
      _runtime = runtime ?? voiceRuntime(),
      voices = voices ?? hebrewVoices {
    for (final v in this.voices) {
      _status[v.id] = ValueNotifier(const HebrewVoiceStatus(HebrewVoiceState.absent));
    }
  }

  final VoiceStore _store;
  final VoiceRuntime _runtime;

  /// Every voice offered, clearest first within each group.
  final List<HebrewVoiceOption> voices;
  final _status = <String, ValueNotifier<HebrewVoiceStatus>>{};

  /// Changes as any voice is fetched, readied or taken off.
  late final Listenable changes = Listenable.merge(_status.values.toList());

  bool _disposed = false;

  /// [id]'s state.
  ValueListenable<HebrewVoiceStatus> status(String id) => _status[id]!;

  bool ready(String id) => _status[id]?.value.state == HebrewVoiceState.ready;

  /// The voices on the device, clearest first.
  List<HebrewVoiceOption> get readyVoices => [...voices.where((v) => ready(v.id))]..sort((a, b) => b.clarity.compareTo(a.clarity));

  /// Finds which voices are on the device already.
  Future<void> init() => _refresh();

  Future<void> _refresh({Set<String> skip = const {}}) async {
    final present = <VoiceFile, bool>{};
    final finish = <String>[];
    for (final v in voices) {
      if (skip.contains(v.id) || _status[v.id]!.value.state == HebrewVoiceState.downloading) continue;
      final missing = <VoiceFile>[];
      for (final f in v.files) {
        try {
          if (!(present[f] ??= await _store.has(f))) missing.add(f);
        } catch (_) {
          missing.add(f);
        }
      }
      if (_disposed) return;
      final current = _status[v.id]!.value.state;
      if (missing.isEmpty) {
        _set(v.id, const HebrewVoiceStatus(HebrewVoiceState.ready));
      } else {
        if (current == HebrewVoiceState.ready) _set(v.id, const HebrewVoiceStatus(HebrewVoiceState.absent));
        // A voice on the device but for a small file a later catalogue added
        // (the first release's Shaul and its config) gets it by itself; one
        // whose own file isn't there is another voice of the model, not yet
        // chosen.
        if ((present[v.spec.own] ?? false) && missing.every((f) => f.size <= _smallFile)) finish.add(v.id);
      }
    }
    for (final id in finish) {
      unawaited(install(id).then((_) {}, onError: (Object _) {}));
    }
  }

  static const _smallFile = 1000000;

  void _set(String id, HebrewVoiceStatus s) {
    if (!_disposed) _status[id]!.value = s;
  }

  /// Fetches [id], and readies it. Throws if it can't be fetched.
  Future<void> install(String id) async {
    final voice = voices.firstWhere((v) => v.id == id);
    final now = _status[id]!.value.state;
    if (now == HebrewVoiceState.downloading || now == HebrewVoiceState.ready) return;
    _set(id, const HebrewVoiceStatus(HebrewVoiceState.downloading));
    try {
      await _store.fetch(
        voice.files,
        onProgress: (received, total) {
          _set(id, HebrewVoiceStatus(HebrewVoiceState.downloading, received: received, total: total));
        },
      );
      _set(id, const HebrewVoiceStatus(HebrewVoiceState.ready));
      // Another voice of the same model may need nothing more now.
      await _refresh(skip: {id});
    } catch (_) {
      _set(id, const HebrewVoiceStatus(HebrewVoiceState.failed));
      rethrow;
    }
  }

  /// Takes [id] off the device, and the files it shares with no other voice
  /// still on it.
  Future<void> remove(String id) async {
    final voice = voices.firstWhere((v) => v.id == id);
    final kept = {
      for (final v in voices)
        if (v.id != id && ready(v.id)) ...v.files,
    };
    await _closeRunner(voice.spec);
    for (final f in voice.files) {
      if (!kept.contains(f)) await _store.remove(f);
    }
    _set(id, const HebrewVoiceStatus(HebrewVoiceState.absent));
  }

  /// What the voices on the device take up, in bytes.
  int get bytesOnDevice => {for (final v in readyVoices) ...v.files}.fold(0, (a, f) => a + f.size);

  /// What fetching [id] would take now, in bytes: its files not on the
  /// device for another voice.
  int bytesToFetch(String id) {
    final have = {for (final v in readyVoices) ...v.files};
    return {...voices.firstWhere((v) => v.id == id).files}.where((f) => !have.contains(f)).fold(0, (a, f) => a + f.size);
  }

  // The models open, most recently used last: two at most, so that the
  // Torah's voice and the Targum's can take turns without reopening. The
  // voices of a model of many share it (VoiceSpec.modelKey).
  final _runners = <String, Future<VoiceRunner>>{};
  static const _openAtOnce = 2;

  // Utterances are made one at a time.
  Future<void> _queue = Future.value();

  Future<VoiceRunner> _runner(VoiceSpec spec) {
    final key = spec.modelKey;
    final open = _runners.remove(key);
    if (open != null) return _runners[key] = open;
    while (_runners.length >= _openAtOnce) {
      final oldest = _runners.keys.first;
      final runner = _runners.remove(oldest)!;
      unawaited(runner.then((r) => r.close()).then((_) {}, onError: (Object _) {}));
    }
    final opening = _runners[key] = openVoice(spec, _store, _runtime);
    opening.then(
      (_) {},
      onError: (Object _) {
        if (identical(_runners[key], opening)) _runners.remove(key);
      },
    );
    return opening;
  }

  Future<void> _closeRunner(VoiceSpec spec) async {
    final runner = _runners.remove(spec.modelKey);
    if (runner == null) return;
    try {
      await (await runner).close();
    } catch (_) {}
  }

  /// [text], pointed Hebrew or Aramaic (with its cantillation, where it has
  /// it), read by voice [id] as [settings] say, at [speed] (1 for the pace
  /// Listen calls normal, kReadingPace, whichever voice reads), as a WAV
  /// file. Throws if the voice isn't on the device or
  /// can't read it.
  Future<Uint8List> speak(String text, {required String id, required VoiceSettings settings, double speed = 1}) {
    final done = Completer<Uint8List>();
    _queue = _queue.then((_) async {
      try {
        done.complete(await _speak(text, id: id, settings: settings, speed: speed));
      } catch (e, s) {
        done.completeError(e, s);
      }
    });
    return done.future;
  }

  Future<Uint8List> _speak(String text, {required String id, required VoiceSettings settings, required double speed}) async {
    if (!ready(id)) throw StateError('The voice $id is not on the device.');
    final voice = voices.firstWhere((v) => v.id == id);
    final runner = await _runner(voice.spec);
    final sounds = HebrewPhonemes.phonemize(text, pronunciation: settings.pronunciation, pauses: settings.pauses);
    // How fast, relative to the voice's own pace: the model reads at part
    // of it, and the rest is stretched.
    final pace = voice.normalSpeed * speed;
    final own = runner.ownSpeed(pace);
    final audio = await runner.synthesize(
      sounds,
      voice: voice.spec,
      spoken: text,
      tuning: VoiceTuning(speed: own, variation: settings.variation, rhythm: settings.rhythm, steps: settings.steps, guidance: settings.guidance),
    );
    return wav(stretch(audio, pace / own, runner.sampleRate), runner.sampleRate, even: settings.evenLoudness);
  }

  /// [audio] at [sampleRate] as a 16-bit mono WAV file; with [even], brought
  /// to a common loudness (its peak at 0.9 of full scale), else only kept
  /// from clipping.
  static Uint8List wav(Float32List audio, int sampleRate, {bool even = true}) {
    var peak = 0.0;
    for (final s in audio) {
      peak = math.max(peak, s.abs());
    }
    final gain = peak == 0 ? 1.0 : (even || peak > 0.95 ? (even ? 0.9 : 0.95) / peak : 1.0);
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
    for (final runner in _runners.values) {
      unawaited(runner.then((r) => r.close()).then((_) {}, onError: (Object _) {}));
    }
    _runners.clear();
    for (final s in _status.values) {
      s.dispose();
    }
  }
}

final hebrewVoicesProvider = Provider<HebrewVoices>((ref) {
  final voices = HebrewVoices();
  unawaited(voices.init());
  ref.onDispose(voices.dispose);
  return voices;
});
