import 'package:flutter/services.dart';

/// Fonts bundled as plain assets instead of under `fonts:` in pubspec.yaml.
///
/// They are not in FontManifest.json, so the web build does not download them
/// at start-up. Call [ensure] before showing text in one of these families;
/// until it completes, the style's fallback fonts are used, and text already on
/// screen is laid out again once the font arrives.
abstract final class OptionalFonts {
  static const _files = {
    'NotoRashiHebrew': ['assets/fonts/rashi/NotoRashiHebrew-Regular.ttf'],
  };
  static final _loading = <String, Future<void>>{};

  /// Whether [family] is loaded on demand rather than at start-up.
  static bool isOptional(String? family) => _files.containsKey(family);

  /// Registers [family] the first time it is asked for. Later calls return the
  /// same future. Completes at once for null and for families that are always
  /// bundled. If loading fails, the error is passed on and the next call tries
  /// again.
  static Future<void> ensure(String? family) {
    final files = _files[family];
    if (family == null || files == null) return Future.value();
    final pending = _loading[family];
    if (pending != null) return pending;
    final loading = _load(family, files);
    _loading[family] = loading;
    loading.then<void>((_) {}, onError: (Object _) {
      _loading.remove(family);
    });
    return loading;
  }

  static Future<void> _load(String family, List<String> files) async {
    // Read every file before registering any, so a missing one leaves no
    // half-registered family behind.
    final data = await Future.wait(files.map(rootBundle.load));
    final loader = FontLoader(family);
    for (final bytes in data) {
      loader.addFont(Future.value(bytes));
    }
    await loader.load();
  }
}
