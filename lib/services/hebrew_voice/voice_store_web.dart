import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'voice_catalogue.dart';
import 'voice_store.dart';

VoiceStore voiceStore() => CachedVoiceStore();

/// On the web: the voices' files in the browser's Cache Storage, fetched
/// once and checked against their digests (their publisher's links are
/// signed afresh each time, so the browser's ordinary cache would fetch them
/// on every visit), and ONNX Runtime Web loaded only once a voice is wanted,
/// not for every visitor.
class CachedVoiceStore implements VoiceStore {
  static const _cacheName = 'hebrew-voice';
  static const _runtime = 'https://cdn.jsdelivr.net/npm/onnxruntime-web@1.30.0/dist/ort.min.js';

  static Future<void>? _runtimeLoaded;
  final _objectUrls = <String, String>{};

  Future<web.Cache> _cache() => web.window.caches.open(_cacheName).toDart;

  @override
  Future<bool> has(VoiceFile file) async => await (await _cache()).match(file.url.toJS).toDart != null;

  @override
  Future<void> fetch(List<VoiceFile> files, {required void Function(int received, int total) onProgress}) async {
    await _loadRuntime();
    final wanted = <VoiceFile>[];
    for (final f in {...files}) {
      if (!await has(f)) wanted.add(f);
    }
    final total = wanted.fold<int>(0, (a, f) => a + f.size);
    var received = 0;
    onProgress(0, total);
    for (final f in wanted) {
      final response = await web.window.fetch(f.url.toJS).toDart;
      if (!response.ok) throw StateError('${f.path} answered ${response.status}');
      final reader = response.body!.getReader() as web.ReadableStreamDefaultReader;
      final bytes = BytesBuilder(copy: false);
      while (true) {
        final chunk = await reader.read().toDart;
        if (chunk.done) break;
        bytes.add((chunk.value! as JSUint8Array).toDart);
        onProgress(received + bytes.length, total);
      }
      final data = bytes.takeBytes();
      final digest = (await web.window.crypto.subtle.digest('SHA-256'.toJS, data.toJS).toDart as JSArrayBuffer).toDart.asUint8List();
      final hex = [for (final b in digest) b.toRadixString(16).padLeft(2, '0')].join();
      if (data.length != f.size || hex != f.sha256) throw FormatException('${f.path} is not the file expected.');
      await (await _cache()).put(f.url.toJS, web.Response(data.toJS)).toDart;
      received += data.length;
      onProgress(received, total);
    }
  }

  @override
  Future<void> remove(VoiceFile file) async {
    final url = _objectUrls.remove(file.url);
    if (url != null) web.URL.revokeObjectURL(url);
    await (await _cache()).delete(file.url.toJS).toDart;
  }

  /// A URL of the file held in memory, which ONNX Runtime Web opens.
  @override
  Future<String> location(VoiceFile file) async {
    await _loadRuntime();
    if (_objectUrls[file.url] case final url?) return url;
    final cached = await (await _cache()).match(file.url.toJS).toDart;
    if (cached == null) throw StateError('${file.path} is not on the device.');
    final blob = await cached.blob().toDart;
    return _objectUrls[file.url] = web.URL.createObjectURL(blob);
  }

  @override
  Future<Uint8List> read(VoiceFile file) async {
    final cached = await (await _cache()).match(file.url.toJS).toDart;
    if (cached == null) throw StateError('${file.path} is not on the device.');
    return (await cached.arrayBuffer().toDart).toDart.asUint8List();
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
