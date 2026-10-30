import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'voice_runtime.dart';

VoiceRuntime voiceRuntime() => _PluginRuntime();

/// ONNX Runtime through flutter_onnxruntime: on Android, iOS, Windows,
/// macOS and Linux.
class _PluginRuntime implements VoiceRuntime {
  final _ort = OnnxRuntime();

  @override
  Future<OnnxModel> open(String location) async => _PluginModel(await _ort.createSession(location));

  @override
  Future<OnnxTensor> float32(Float32List data, List<int> shape) async => _PluginTensor(await OrtValue.fromList(data, shape));

  @override
  Future<OnnxTensor> int64(List<int> data, List<int> shape) async => _PluginTensor(await OrtValue.fromList(Int64List.fromList(data), shape));
}

class _PluginModel implements OnnxModel {
  _PluginModel(this._session);
  final OrtSession _session;

  @override
  List<String> get inputNames => _session.inputNames;

  @override
  Future<Map<String, OnnxTensor>> run(Map<String, OnnxTensor> feeds) async {
    final out = await _session.run({for (final MapEntry(:key, :value) in feeds.entries) key: (value as _PluginTensor).value});
    return {for (final MapEntry(:key, :value) in out.entries) key: _PluginTensor(value)};
  }

  @override
  Future<void> close() => _session.close();
}

class _PluginTensor implements OnnxTensor {
  _PluginTensor(this.value);
  final OrtValue value;

  @override
  Future<Float32List> floats() async {
    final list = await value.asFlattenedList();
    if (list is Float32List) return list;
    return Float32List.fromList([for (final s in list) (s as num).toDouble()]);
  }

  @override
  Future<void> dispose() => value.dispose();
}
