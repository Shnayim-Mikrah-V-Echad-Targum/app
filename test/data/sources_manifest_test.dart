import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// assets/text/SOURCES.json, which tool/data/build_data.mjs writes: every file
/// the app ships from its text and data folders, with its SHA-256, and every
/// source file the build reads, with the Sefaria address to download it from.
/// These tests check the bundled files still match the manifest, and that the
/// manifest covers every file the folders hold.
void main() {
  final manifest = jsonDecode(File('assets/text/SOURCES.json').readAsStringSync()) as Map<String, dynamic>;
  final files = manifest['files'] as Map<String, dynamic>;
  final sources = manifest['sources'] as Map<String, dynamic>;

  String sha256Of(File file) => sha256.convert(file.readAsBytesSync()).toString();

  test('every bundled text and data file matches its checksum in the manifest', () {
    for (final entry in files.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} is missing');
      expect(sha256Of(file), (entry.value as Map)['sha256'], reason: '${entry.key} differs from the manifest');
    }
  });

  test('the manifest lists every file the text and data folders hold', () {
    final held = [
      for (final dir in ['assets/text', 'assets/data'])
        for (final f in Directory(dir).listSync(recursive: true))
          if (f is File && f.path.endsWith('.json') && !f.path.endsWith('SOURCES.json')) f.path,
    ]..sort();
    expect(files.keys.toList()..sort(), held);
  });

  test('every source file has an address to download it from and a checksum of its exact bytes', () {
    expect(sources, isNotEmpty);
    for (final entry in sources.entries) {
      final source = entry.value as Map<String, dynamic>;
      expect(source['url'] as String, startsWith('https://'), reason: entry.key);
      expect(source['sha256'] as String, matches(RegExp(r'^[0-9a-f]{64}$')), reason: entry.key);
    }
  });

  test('the texts come from the Sefaria export, the places from the GeoNames package', () {
    final fromSefaria = sources.values.where((s) => (s as Map)['builtBy'] == 'build_data.mjs');
    expect(fromSefaria, isNotEmpty);
    for (final source in fromSefaria) {
      expect((source as Map)['url'] as String, startsWith('https://storage.googleapis.com/sefaria-export/json/'));
    }
    final places = sources['geonamescache 3.0.2 wheel'] as Map<String, dynamic>;
    expect(places['url'] as String, startsWith('https://files.pythonhosted.org/'));
  });

  test('the manifest names the versions of the tools that built it', () {
    expect(manifest['builtWith'], {'@hebcal/leyning': '10.1.0', '@hebcal/core': '6.14.1'});
  });
}
