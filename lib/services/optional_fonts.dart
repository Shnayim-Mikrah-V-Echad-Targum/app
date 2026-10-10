import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Fonts bundled as plain assets instead of under `fonts:` in pubspec.yaml:
/// the Rashi script, and the scripture and interface fonts a reader may opt
/// into.
///
/// They are not in FontManifest.json, so the web build does not download them
/// at start-up. Call [ensure] before showing text in one of these families;
/// until it completes, the style's fallback fonts are used, and text already on
/// screen is laid out again once the font arrives. The app loads the fonts its
/// settings choose (main.dart, before the first frame, and the app as the
/// settings change, or as it resumes after one failed to load), and builds its
/// theme in an interface font only once [isLoaded] says it has arrived.
abstract final class OptionalFonts {
  static const _files = {
    'NotoRashiHebrew': ['assets/fonts/rashi/NotoRashiHebrew-Regular.ttf'],
    // Scripture fonts (ScriptureFont). Only Taamey Frank's Medium: its Bold
    // draws the cantillation marks as empty glyphs.
    'TaameyFrank': ['assets/fonts/optional/TaameyFrankCLM-Medium.ttf'],
    'EzraSIL': ['assets/fonts/optional/EzraSIL-Regular.ttf'],
    // Interface fonts (UiFont), each in 400 and 700. A family's weights are
    // told apart by the files themselves.
    'AtkinsonHyperlegibleNext': [
      'assets/fonts/optional/AtkinsonHyperlegibleNext-Regular.ttf',
      'assets/fonts/optional/AtkinsonHyperlegibleNext-Bold.ttf',
    ],
    'Lexend': [
      'assets/fonts/optional/Lexend-Regular.ttf',
      'assets/fonts/optional/Lexend-Bold.ttf',
    ],
    'OpenDyslexic': [
      'assets/fonts/optional/OpenDyslexic-Regular.otf',
      'assets/fonts/optional/OpenDyslexic-Bold.otf',
    ],
  };
  static final _loading = <String, Future<void>>{};
  static final _loaded = <String>{};

  /// Every family loaded on demand.
  @visibleForTesting
  static Iterable<String> get families => _files.keys;

  /// The asset files of [family], or none if it is always bundled.
  @visibleForTesting
  static List<String> filesOf(String family) => _files[family] ?? const [];

  /// Whether text in [family] is drawn in it now: it has loaded, or it needs
  /// no loading (null, or a family that is always bundled).
  static bool isLoaded(String? family) => family == null || !_files.containsKey(family) || _loaded.contains(family);

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
    // Registered before anyone else's, so whoever awaits [ensure] finds the
    // family loaded.
    loading.then<void>((_) => _loaded.add(family), onError: (Object _) {
      _loading.remove(family);
    });
    return loading;
  }

  /// Loads each of [families] as [ensure] does, all at once. Never fails: a
  /// family that can't be loaded is reported, and its text keeps to the
  /// fallback fonts.
  static Future<void> ensureAll(Iterable<String?> families, {AssetBundle? bundle}) => Future.wait([
        for (final family in families.toSet())
          ensure(family, bundle: bundle).catchError((Object e) => debugPrint('Font $family unavailable: $e')),
      ]);

  /// Whether [family] has been asked for since the app started (or since
  /// [reset]), and has not failed to load.
  @visibleForTesting
  static bool isRequested(String family) => _loading.containsKey(family);

  /// Forgets every load, finished or not, as if the app had just started. A
  /// family the engine has already registered stays registered.
  @visibleForTesting
  static void reset() {
    _loading.clear();
    _loaded.clear();
  }

  static Future<void> _load(String family, List<String> files, AssetBundle bundle) async {
    // Read every file before registering any, so a missing one leaves no
    // half-registered family behind. Every request starts at once, so a
    // family of two files costs one round trip on the web, not two; they are
    // awaited in turn because Future.wait drops the values of a
    // SynchronousFuture, which some bundles (flutter_test's among them)
    // return.
    final pending = [for (final file in files) bundle.load(file)];
    final data = <ByteData>[];
    // Each is awaited, so that a second failure is not left unhandled.
    (Object, StackTrace)? failure;
    for (final load in pending) {
      try {
        data.add(await load);
      } catch (e, stack) {
        failure ??= (e, stack);
      }
    }
    if (failure case (final error, final stack)) Error.throwWithStackTrace(error, stack);
    final loader = FontLoader(family);
    for (final bytes in data) {
      loader.addFont(Future.value(bytes));
    }
    await loader.load();
  }
}
