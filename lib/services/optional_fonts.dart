import 'package:flutter/foundation.dart';
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

  /// Registers [family] the first time it is asked for, reading its files from
  /// [bundle] (by default the app's [rootBundle]). Later calls return the same
  /// future. Completes at once for null and for families that are always
  /// bundled. If loading fails, the error is passed on and the next call tries
  /// again.
  static Future<void> ensure(String? family, {AssetBundle? bundle}) {
    final files = _files[family];
    if (family == null || files == null) return Future.value();
    final pending = _loading[family];
    if (pending != null) return pending;
    final loading = _load(family, files, bundle ?? rootBundle);
    _loading[family] = loading;
    loading.then<void>((_) {}, onError: (Object _) {
      _loading.remove(family);
    });
    return loading;
  }

  /// Forgets every load, finished or not, as if the app had just started. A
  /// family the engine has already registered stays registered.
  @visibleForTesting
  static void reset() => _loading.clear();

  static Future<void> _load(String family, List<String> files, AssetBundle bundle) async {
    // Read every file before registering any, so a missing one leaves no
    // half-registered family behind. One at a time: Future.wait drops the
    // values of a SynchronousFuture, which some bundles (flutter_test's
    // among them) return.
    final data = [for (final file in files) await bundle.load(file)];
    final loader = FontLoader(family);
    for (final bytes in data) {
      loader.addFont(Future.value(bytes));
    }
    await loader.load();
  }
}
