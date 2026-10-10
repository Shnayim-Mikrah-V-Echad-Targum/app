import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The web build's bootstrap and service worker configuration (web/,
/// workbox-config.cjs), which no widget test runs.
void main() {
  group('offline', () {
    test('the bootstrap registers the Workbox worker, not Flutter\'s', () {
      final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
      expect(bootstrap, startsWith('{{flutter_js}}\n{{flutter_build_config}}\n'));
      expect(bootstrap, contains('_flutter.loader.load();'));
      expect(bootstrap, isNot(contains('serviceWorkerSettings:')));
      expect(bootstrap, isNot(contains('serviceWorkerVersion')));
      expect(bootstrap, contains("navigator.serviceWorker.register('sw.js')"));
      expect(bootstrap, contains("addEventListener('flutter-first-frame'"));
    });

    // workbox-config.cjs precaches assets/fonts/*.{ttf,otf}: exactly the
    // fonts the engine loads at start-up, which pubspec.yaml declares.
    test('the fonts directly in assets/fonts are the ones pubspec.yaml declares', () {
      final declared = RegExp(r'- asset: (assets/fonts/[^\s]+)')
          .allMatches(File('pubspec.yaml').readAsStringSync())
          .map((m) => m[1]!)
          .toSet();
      final topLevel = Directory('assets/fonts')
          .listSync()
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where((p) => p.endsWith('.ttf') || p.endsWith('.otf'))
          .toSet();
      expect(topLevel, declared);
      expect(File('workbox-config.cjs').readAsStringSync(), contains("'assets/assets/fonts/*.{ttf,otf}'"));
    });
  });
}
