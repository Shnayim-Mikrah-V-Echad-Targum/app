import 'dart:typed_data';

import 'voice_catalogue.dart';

/// Where the voices' files are kept (HebrewVoices): in the app's support
/// folder, or on the web in the browser's Cache Storage. Each file is
/// checked against its digest as it is fetched, and only then kept.
abstract class VoiceStore {
  /// Whether [file] is on the device.
  Future<bool> has(VoiceFile file);

  /// Fetches each of [files] not on the device yet, telling how many bytes
  /// of them all have come. Throws if one can't be fetched, or isn't the file
  /// it should be; those fetched before it are kept.
  Future<void> fetch(List<VoiceFile> files, {required void Function(int received, int total) onProgress});

  /// Takes [file] off the device.
  Future<void> remove(VoiceFile file);

  /// Where ONNX Runtime opens [file] from: a path, or on the web a URL.
  Future<String> location(VoiceFile file);

  /// The bytes of [file], a small one (a config, a style).
  Future<Uint8List> read(VoiceFile file);
}
