import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';

/// The web build's page, manifest and bootstrap (web/), which no widget test
/// renders: the loading screen in the app's theme, link previews, the
/// installed app's metadata, and the offline service worker's registration.
/// tool/web/web.test.mjs runs their scripts against fixtures.
void main() {
  final html = File('web/index.html').readAsStringSync();
  final manifest = jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, dynamic>;

  group('index.html', () {
    test('keeps the brand theme-color only until the first frame', () {
      expect(html, contains('<meta name="theme-color" content="#1D3F75" class="boot-theme">'));
      expect(html, contains('<meta name="color-scheme" content="light dark">'));
      // Flutter's own theme-color (MaterialApp.color) then takes over.
      final listener = html.substring(html.indexOf("addEventListener('flutter-first-frame'"));
      expect(listener, contains("querySelectorAll('meta.boot-theme')"));
      expect(listener, contains('loading.remove()'));
    });

    // CI's web job finds the canonical and og:image tags exactly as written
    // here, to make their URLs absolute.
    test('describes the app for link previews', () {
      for (final tag in [
        '<link rel="canonical" href="./">',
        '<meta property="og:type" content="website">',
        '<meta property="og:title" content="Shnayim Mikra · שניים מקרא">',
        '<meta property="og:image" content="og.png">',
        '<meta property="og:image:width" content="1200">',
        '<meta property="og:image:height" content="630">',
        '<meta name="twitter:card" content="summary_large_image">',
      ]) {
        expect(html, contains(tag));
      }
      expect(html, contains('<meta property="og:description" content="'));
      expect(_pngSize('web/og.png'), (1200, 630));
    });

    test('shows the mark that make_icon.py drew', () {
      final mark = RegExp(
        r'<!-- mark: tool/branding/make_icon\.py --post -->\n\s*(<svg class="mark" [^\n]*</svg>)\n\s*<!-- /mark -->',
      ).firstMatch(html);
      expect(mark, isNotNull, reason: 'run python3 tool/branding/make_icon.py --post');
      expect(mark![1], contains('aria-hidden="true"'));
    });

    test("paints the loading screen in each of the app's themes", () {
      String vars(String selector) {
        final start = html.indexOf('$selector {');
        expect(start, isNot(-1), reason: selector);
        return html.substring(start, html.indexOf('}', start));
      }

      String hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
      for (final (selector, scheme, sefer) in <(String, ColorScheme, SeferColors)>[
        (':root', Palettes.light, Palettes.seferLight),
        (':root:not([data-theme])', Palettes.dark, Palettes.seferDark),
        (':root[data-theme=${AppThemeMode.dark.name}]', Palettes.dark, Palettes.seferDark),
        (':root[data-theme=${AppThemeMode.sepia.name}]', Palettes.sepia, Palettes.seferSepia),
        (':root[data-theme=${AppThemeMode.highContrastLight.name}]', Palettes.hcLight, Palettes.seferHcLight),
        (':root[data-theme=${AppThemeMode.highContrastDark.name}]', Palettes.hcDark, Palettes.seferHcDark),
      ]) {
        final declared = vars(selector);
        expect(declared, contains('--surface: ${hex(scheme.surface)}'), reason: selector);
        expect(declared, contains('--primary: ${hex(scheme.primary)}'), reason: selector);
        expect(declared, contains('--muted: ${hex(scheme.onSurfaceVariant)}'), reason: selector);
        expect(declared, contains('--track: ${hex(sefer.ringTrack)}'), reason: selector);
      }
      // The saved settings, as shared_preferences writes them on the web.
      expect(html, contains("localStorage.getItem('flutter.settings.v1')"));
      expect(html, contains('JSON.parse(JSON.parse('));
      for (final mode in AppThemeMode.values.where((m) => m != AppThemeMode.system)) {
        expect(html, contains("'${mode.name}'"), reason: 'the loader knows the $mode theme');
      }
      expect(html, contains("settings.language === '${AppLanguage.hebrew.name}'"));
      expect(html, contains('settings.reduceMotion === true'));
    });

    test('says when loading is slow, in either language', () {
      expect(html, contains('<p id="loading-text">Loading…</p>'));
      expect(html, contains("'טוען…'"));
      expect(html, contains("hebrew ? 'עדיין טוען…' : 'Still loading…'"));
      expect(html, contains('}, 8000);'));
      expect(html, contains('@media (prefers-reduced-motion: reduce)'));
    });

    test('points readers without JavaScript to the static pages, in both languages', () {
      final noscript = html.substring(html.indexOf('<noscript>\n'), html.indexOf('</noscript>', html.indexOf('<noscript>\n')));
      for (final page in ['privacy', 'support', 'delete-account']) {
        expect(noscript, contains('href="legal/$page.html"'));
        expect(noscript, contains('href="legal/$page.he.html"'));
      }
      expect(noscript, contains('<p lang="he" dir="rtl">'));
    });
  });

  group('manifest.json', () {
    test('installs one app, which opens in its existing window', () {
      expect(manifest['id'], './');
      expect(manifest['scope'], './');
      expect(manifest['start_url'], '.');
      expect(manifest['launch_handler'], {'client_mode': 'focus-existing'});
      expect(manifest['description'], isNotEmpty);
    });

    test('has shortcuts to Today and Progress, with icons', () {
      final shortcuts = (manifest['shortcuts'] as List).cast<Map<String, dynamic>>();
      expect([for (final s in shortcuts) s['url']], ['./#/today', './#/progress']);
      for (final shortcut in shortcuts) {
        for (final icon in (shortcut['icons'] as List).cast<Map<String, dynamic>>()) {
          final (w, h) = _pngSize('web/${icon['src']}');
          expect(icon['sizes'], '${w}x$h', reason: '${icon['src']}');
        }
      }
    });

    // What Chrome's richer install dialog asks of screenshots.
    test('has screenshots for phones and computers', () {
      final screenshots = (manifest['screenshots'] as List).cast<Map<String, dynamic>>();
      final ratios = <String, Set<double>>{};
      for (final shot in screenshots) {
        final (w, h) = _pngSize('web/${shot['src']}');
        expect(shot['sizes'], '${w}x$h', reason: '${shot['src']}');
        expect(shot['type'], 'image/png');
        expect(shot['label'], isNotEmpty);
        expect([w, h].every((d) => d >= 320 && d <= 3840), isTrue, reason: '${shot['src']}');
        final long = w > h ? w : h;
        final short = w > h ? h : w;
        expect(long / short, lessThanOrEqualTo(2.3), reason: '${shot['src']}');
        expect(shot['form_factor'] == 'wide', w > h, reason: '${shot['src']}');
        ratios.putIfAbsent(shot['form_factor'] as String, () => {}).add(w / h);
      }
      expect(ratios.keys, unorderedEquals(['narrow', 'wide']));
      expect(ratios.values.every((r) => r.length == 1), isTrue, reason: 'one aspect ratio per form factor');
    });
  });

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

/// The width and height in a PNG's header.
(int, int) _pngSize(String path) {
  final bytes = File(path).readAsBytesSync();
  expect(bytes.sublist(1, 4), ascii.encode('PNG'), reason: path);
  final header = ByteData.sublistView(bytes, 16, 24);
  return (header.getUint32(0), header.getUint32(4));
}
