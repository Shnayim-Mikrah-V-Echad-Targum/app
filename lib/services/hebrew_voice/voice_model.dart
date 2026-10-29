/// Where the Hebrew voice's model is kept (HebrewVoice): a file in the app's
/// support folder, or on the web the browser's cache.
abstract class VoiceModel {
  /// Whether the model is on the device.
  Future<bool> present();

  /// Fetches the model, telling how much of it has come (0 to 1). Throws if
  /// it can't be fetched, or isn't the model it should be.
  Future<void> fetch({required void Function(double progress) onProgress});

  /// Takes the model off the device.
  Future<void> remove();

  /// Where ONNX Runtime opens it from: a file's path, or on the web a URL.
  Future<String> location();
}
