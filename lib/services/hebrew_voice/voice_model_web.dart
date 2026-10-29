import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'hebrew_voice.dart';
import 'voice_model.dart';

VoiceModel voiceModel() => CachedVoiceModel();

/// On the web: the voice's model in the browser's Cache Storage, fetched once
/// and checked against its digest (its publisher's links are signed afresh
/// each time, so the browser's ordinary cache would fetch it on every
/// visit), and ONNX Runtime Web loaded only once the voice is wanted, not
/// for every visitor.
class CachedVoiceModel implements VoiceModel {
  static const _cacheName = 'hebrew-voice';
  static const _runtime = 'https://cdn.jsdelivr.net/npm/onnxruntime-web@1.30.0/dist/ort.min.js';

  static Future<void>? _runtimeLoaded;
  String? _objectUrl;

  Future<web.Cache> _cache() => web.window.caches.open(_cacheName).toDart;

  @override
  Future<bool> present() async => await (await _cache()).match(HebrewVoice.url.toJS).toDart != null;

  @override
  Future<void> fetch({required void Function(double progress) onProgress}) async {
    await _loadRuntime();
    final response = await web.window.fetch(HebrewVoice.url.toJS).toDart;
    if (!response.ok) throw StateError('The voice answered ${response.status}');
    final reader = response.body!.getReader() as web.ReadableStreamDefaultReader;
    final bytes = BytesBuilder(copy: false);
    while (true) {
      final chunk = await reader.read().toDart;
      if (chunk.done) break;
      bytes.add((chunk.value! as JSUint8Array).toDart);
      onProgress((bytes.length / HebrewVoice.sizeBytes).clamp(0.0, 1.0));
    }
    final model = bytes.takeBytes();
    final digest = (await web.window.crypto.subtle.digest('SHA-256'.toJS, model.toJS).toDart as JSArrayBuffer).toDart.asUint8List();
    final hex = [for (final b in digest) b.toRadixString(16).padLeft(2, '0')].join();
    if (model.length != HebrewVoice.sizeBytes || hex != HebrewVoice.sha256) {
      throw const FormatException('The voice fetched is not the one expected.');
    }
    await (await _cache()).put(HebrewVoice.url.toJS, web.Response(model.toJS)).toDart;
  }

  @override
  Future<void> remove() async {
    if (_objectUrl != null) web.URL.revokeObjectURL(_objectUrl!);
    _objectUrl = null;
    await (await _cache()).delete(HebrewVoice.url.toJS).toDart;
  }

  /// A URL of the model held in memory, which ONNX Runtime Web opens.
  @override
  Future<String> location() async {
    await _loadRuntime();
    if (_objectUrl case final url?) return url;
    final cached = await (await _cache()).match(HebrewVoice.url.toJS).toDart;
    if (cached == null) throw StateError('The Hebrew voice is not on the device.');
    final blob = await cached.blob().toDart;
    return _objectUrl = web.URL.createObjectURL(blob);
  }

  /// Loads ONNX Runtime Web, once, which the plugin finds as `ort`.
  static Future<void> _loadRuntime() => _runtimeLoaded ??= () {
        final done = Completer<void>();
        final script = web.HTMLScriptElement()
          ..src = _runtime
          ..crossOrigin = 'anonymous';
        script.onload = ((web.Event _) => done.complete()).toJS;
        script.onerror = ((web.Event _) {
          _runtimeLoaded = null;
          done.completeError(StateError('ONNX Runtime Web could not be loaded.'));
        }).toJS;
        web.document.head!.append(script);
        return done.future;
      }();
}
