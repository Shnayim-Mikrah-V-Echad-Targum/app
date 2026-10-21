import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'preferences_file_stub.dart' if (dart.library.io) 'preferences_file_io.dart' as file;

/// The device's stored preferences (the settings, progress and notes), or,
/// where they can't be read, preferences to start afresh with: whatever has
/// become of them, the app opens.
///
/// - On Windows, a preferences file that a power cut or a crash left cut
///   short is set aside, beside it, for support to look at
///   ([file.setAsideUnreadablePreferences]), and the app starts afresh.
/// - A failure that passes (the file held for a moment by another program)
///   is over by a second try.
/// - Where they can't be read at all, as in a browser that blocks the site's
///   storage (reading localStorage throws), the app runs on preferences kept
///   in memory, until it closes.
///
/// What went wrong is reported, and with it what became of the preferences,
/// so that About offers to copy it for support.
Future<SharedPreferences> openPreferences({@visibleForTesting Future<String> Function()? supportPath}) async {
  try {
    return await SharedPreferences.getInstance();
  } catch (error, stack) {
    final (prefs, outcome) = await _recover(supportPath);
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'preferences',
      context: ErrorDescription('while reading the stored preferences; $outcome'),
    ));
    return prefs;
  }
}

/// Preferences once those stored could not be read, and what became of
/// them. A failed [SharedPreferences.getInstance] reads them afresh the
/// next time: it forgets its failure, and the platform's store caches only
/// what it has read.
Future<(SharedPreferences, String)> _recover(Future<String> Function()? supportPath) async {
  final setAside = await file.setAsideUnreadablePreferences(supportPath: supportPath);
  try {
    return (
      await SharedPreferences.getInstance(),
      setAside == null
          ? 'they were read at the second try'
          : 'they were set aside as $setAside, and the app started afresh',
    );
  } catch (_) {
    SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();
    return (
      await SharedPreferences.getInstance(),
      'the app runs on preferences kept in memory, which are lost when it closes',
    );
  }
}
