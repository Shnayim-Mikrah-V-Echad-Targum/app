import 'dart:typed_data';

import 'voice_runtime_io.dart' if (dart.library.js_interop) 'voice_runtime_web.dart' as platform;

/// ONNX Runtime, as the voices run on it: flutter_onnxruntime on Android,
/// iOS and the desktop, and ONNX Runtime Web itself in the browser, whose
/// int64 tensors the plugin's web side can't make (and whose ids for
/// sessions and tensors, the time of day, two made in one millisecond would
/// share).
abstract class VoiceRuntime {
  /// The model at [location]: a file's path, or on the web a URL.
  Future<OnnxModel> open(String location);

  Future<OnnxTensor> float32(Float32List data, List<int> shape);

  Future<OnnxTensor> int64(List<int> data, List<int> shape);
}

/// A model opened in ONNX Runtime.
abstract class OnnxModel {
  List<String> get inputNames;

  /// Its outputs for [feeds], by name, in the model's order.
  Future<Map<String, OnnxTensor>> run(Map<String, OnnxTensor> feeds);

  Future<void> close();
}

/// A tensor ONNX Runtime holds: an input, or an output, which may be fed to
/// another model without leaving it.
abstract class OnnxTensor {
  /// Its values, a float32 tensor's.
  Future<Float32List> floats();

  Future<void> dispose();
}

/// The runtime of the platform the app runs on.
VoiceRuntime voiceRuntime() => platform.voiceRuntime();
