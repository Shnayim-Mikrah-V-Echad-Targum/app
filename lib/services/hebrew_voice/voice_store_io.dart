import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'voice_catalogue.dart';
import 'voice_store.dart';

VoiceStore voiceStore() => FileVoiceStore();

/// The voices' files in the app's support folder, under voices/, each named
/// for its repository and revision. A file is fetched to a .part beside it
/// and takes its name once its digest is checked: a fetch cut short leaves
/// nothing behind.
class FileVoiceStore implements VoiceStore {
  FileVoiceStore({Future<Directory> Function()? folder, http.Client Function()? client})
    : _folder = folder ?? getApplicationSupportDirectory,
      _client = client ?? http.Client.new;

  final Future<Directory> Function() _folder;
  final http.Client Function() _client;

  Future<File> _file(VoiceFile f) async {
    await (_migrated ??= _migrate());
    final root = (await _folder()).path;
    final sep = Platform.pathSeparator;
    return File('$root${sep}voices$sep${f.localName.replaceAll('/', sep)}');
  }

  Future<void>? _migrated;

  /// The first release kept its one voice, Shaul, under a name of its own:
  /// it takes its catalogue's name, rather than be fetched again.
  Future<void> _migrate() async {
    try {
      final root = (await _folder()).path;
      final sep = Platform.pathSeparator;
      final old = File('$root${sep}voices${sep}hebrew-voice-shaul-ff64ba3.onnx');
      if (!await old.exists()) return;
      final now = File('$root${sep}voices${sep}Phonikud__phonikud-tts-checkpoints@ff64ba3${sep}shaul.onnx');
      await now.parent.create(recursive: true);
      if (!await now.exists()) await old.rename(now.path);
    } catch (_) {
      // Fetched again, should it come to that.
    }
  }

  @override
  Future<bool> has(VoiceFile file) async {
    final f = await _file(file);
    return await f.exists() && await f.length() == file.size;
  }

  @override
  Future<void> fetch(List<VoiceFile> files, {required void Function(int received, int total) onProgress}) async {
    final wanted = <VoiceFile>[];
    for (final f in {...files}) {
      if (!await has(f)) wanted.add(f);
    }
    final total = wanted.fold<int>(0, (a, f) => a + f.size);
    var received = 0;
    onProgress(0, total);
    final client = _client();
    try {
      for (final f in wanted) {
        received = await _fetchOne(client, f, (n) => onProgress(received + n, total)) + received;
        onProgress(received, total);
      }
    } finally {
      client.close();
    }
  }

  Future<int> _fetchOne(http.Client client, VoiceFile f, void Function(int) onProgress) async {
    final file = await _file(f);
    await file.parent.create(recursive: true);
    final part = File('${file.path}.part');
    try {
      final response = await client.send(http.Request('GET', Uri.parse(f.url)));
      if (response.statusCode != 200) throw HttpException('${f.path} answered ${response.statusCode}', uri: Uri.parse(f.url));
      final sink = part.openWrite();
      final digest = _DigestSink();
      final hasher = sha256.startChunkedConversion(digest);
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          hasher.add(chunk);
          received += chunk.length;
          onProgress(received);
        }
      } finally {
        await sink.close();
        hasher.close();
      }
      if (received != f.size || digest.value.toString() != f.sha256) {
        throw FormatException('${f.path} is not the file expected.');
      }
      await part.rename(file.path);
      return received;
    } finally {
      if (await part.exists()) await part.delete();
    }
  }

  @override
  Future<void> remove(VoiceFile file) async {
    final f = await _file(file);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<String> location(VoiceFile file) async => (await _file(file)).path;

  @override
  Future<Uint8List> read(VoiceFile file) async => (await _file(file)).readAsBytes();

  @override
  Future<String> made(String name, Uint8List bytes) async {
    final sep = Platform.pathSeparator;
    final file = File('${(await _folder()).path}${sep}voices${sep}made$sep$name');
    if (!await file.exists() || await file.length() != bytes.length) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    }
    return file.path;
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
