import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'hebrew_voice.dart';
import 'voice_model.dart';

VoiceModel voiceModel() => FileVoiceModel();

/// The voice's model as a file in the app's support folder, fetched once and
/// checked against its digest before it takes its name: a fetch cut short
/// leaves no model behind.
class FileVoiceModel implements VoiceModel {
  FileVoiceModel({Future<Directory> Function()? folder, http.Client Function()? client})
      : _folder = folder ?? getApplicationSupportDirectory,
        _client = client ?? http.Client.new;

  final Future<Directory> Function() _folder;
  final http.Client Function() _client;

  /// Named for the revision, so that another voice, or another revision of
  /// this one, never mistakes this file for itself.
  static const _name = 'hebrew-voice-shaul-ff64ba3.onnx';

  Future<File> _file() async => File('${(await _folder()).path}${Platform.pathSeparator}voices${Platform.pathSeparator}$_name');

  @override
  Future<bool> present() async {
    final file = await _file();
    return await file.exists() && await file.length() == HebrewVoice.sizeBytes;
  }

  @override
  Future<void> fetch({required void Function(double progress) onProgress}) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final part = File('${file.path}.part');
    final client = _client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(HebrewVoice.url)));
      if (response.statusCode != 200) throw HttpException('The voice answered ${response.statusCode}', uri: Uri.parse(HebrewVoice.url));
      final total = response.contentLength ?? HebrewVoice.sizeBytes;
      final sink = part.openWrite();
      final digest = _DigestSink();
      final hasher = sha256.startChunkedConversion(digest);
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          hasher.add(chunk);
          received += chunk.length;
          onProgress((received / total).clamp(0.0, 1.0));
        }
      } finally {
        await sink.close();
        hasher.close();
      }
      if (received != HebrewVoice.sizeBytes || digest.value.toString() != HebrewVoice.sha256) {
        throw const FormatException('The voice fetched is not the one expected.');
      }
      await part.rename(file.path);
    } finally {
      client.close();
      if (await part.exists()) await part.delete();
    }
  }

  @override
  Future<void> remove() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }

  @override
  Future<String> location() async => (await _file()).path;
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
