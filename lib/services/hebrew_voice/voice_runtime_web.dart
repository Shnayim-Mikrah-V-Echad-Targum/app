import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'voice_runtime.dart';

VoiceRuntime voiceRuntime() => _WebRuntime();

/// ONNX Runtime Web, called directly: loaded from its CDN once a voice is
/// wanted, not for every visitor.
class _WebRuntime implements VoiceRuntime {
  static const _script = 'https://cdn.jsdelivr.net/npm/onnxruntime-web@1.30.0/dist/ort.min.js';
  static Future<JSObject>? _loaded;

  static Future<JSObject> _ort() => _loaded ??= () {
    final done = Completer<JSObject>();
    final script = web.HTMLScriptElement()
      ..src = _script
      ..crossOrigin = 'anonymous';
    script.onload = ((web.Event _) => done.complete(globalContext['ort']! as JSObject)).toJS;
    script.onerror = ((web.Event _) {
      _loaded = null;
      done.completeError(StateError('ONNX Runtime Web could not be loaded.'));
    }).toJS;
    web.document.head!.append(script);
    return done.future;
  }();

  @override
  Future<OnnxModel> open(String location) async {
    final ort = await _ort();
    final sessions = ort['InferenceSession']! as JSObject;
    final options = JSObject()..['executionProviders'] = ['wasm'.toJS].toJS;
    final session = await (sessions.callMethod<JSPromise<JSObject>>('create'.toJS, location.toJS, options)).toDart;
    return _WebModel(session);
  }

  static JSArray<JSNumber> _dims(List<int> shape) => [for (final d in shape) d.toJS].toJS;

  @override
  Future<OnnxTensor> float32(Float32List data, List<int> shape) async {
    final ort = await _ort();
    final tensor = (ort['Tensor']! as JSFunction).callAsConstructor<JSObject>('float32'.toJS, data.toJS, _dims(shape));
    return _WebTensor(tensor);
  }

  @override
  Future<OnnxTensor> int64(List<int> data, List<int> shape) async {
    final ort = await _ort();
    // A BigInt64Array, from numbers through BigInt.
    final numbers = [for (final v in data) v.toJS].toJS;
    final big = (globalContext['BigInt64Array']! as JSObject).callMethod<JSObject>('from'.toJS, numbers, globalContext['BigInt']);
    final tensor = (ort['Tensor']! as JSFunction).callAsConstructor<JSObject>('int64'.toJS, big, _dims(shape));
    return _WebTensor(tensor);
  }
}

class _WebModel implements OnnxModel {
  _WebModel(this._session) : inputNames = [for (final n in (_session['inputNames']! as JSArray<JSString>).toDart) n.toDart];

  final JSObject _session;

  @override
  final List<String> inputNames;

  List<String> get _outputNames => [for (final n in (_session['outputNames']! as JSArray<JSString>).toDart) n.toDart];

  @override
  Future<Map<String, OnnxTensor>> run(Map<String, OnnxTensor> feeds) async {
    final js = JSObject();
    for (final MapEntry(:key, :value) in feeds.entries) {
      js[key] = (value as _WebTensor).tensor;
    }
    final results = await _session.callMethod<JSPromise<JSObject>>('run'.toJS, js).toDart;
    return {for (final name in _outputNames) name: _WebTensor(results[name]! as JSObject)};
  }

  @override
  Future<void> close() async {
    try {
      await _session.callMethod<JSPromise<JSAny?>>('release'.toJS).toDart;
    } catch (_) {}
  }
}

class _WebTensor implements OnnxTensor {
  _WebTensor(this.tensor);
  final JSObject tensor;

  @override
  Future<Float32List> floats() async => Float32List.fromList((tensor['data']! as JSFloat32Array).toDart);

  @override
  Future<void> dispose() async {
    try {
      tensor.callMethod<JSAny?>('dispose'.toJS);
    } catch (_) {}
  }
}
