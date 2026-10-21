// The preferences file of Windows (and of Linux, should the app ship there),
// set aside when it can't be read (see preferences_recovery.dart).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// The file shared_preferences_windows and shared_preferences_linux keep
/// every preference in, in the app's support directory: on Windows
/// %APPDATA%\Shnayim Mikrah\Shnayim Mikrah (windows/runner/Runner.rc).
const preferencesFileName = 'shared_preferences.json';

/// What [preferencesFileName] is renamed to when it can't be read.
const setAsideFileName = '$preferencesFileName.corrupt';

/// Renames the preferences file [setAsideFileName], beside it, if it is
/// there and can't be read, so that the app can start afresh; returns the
/// new name, or null if nothing was set aside.
///
/// The plugins rewrite the whole file in place on every change, with no
/// copy to fall back on, so a power cut, a crash or a full disk as they
/// write can leave it cut short or full of NULs; they then fail to read it
/// on every start. A file they could read is left as it is, as is one that
/// can't be opened at all (held by another program, say): whatever failed,
/// it was not what the file holds. One set aside earlier is replaced.
///
/// Never throws: should this fail too, the app runs on preferences kept in
/// memory instead.
Future<String?> setAsideUnreadablePreferences({@visibleForTesting Future<String> Function()? supportPath}) async {
  if (defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.linux) return null;
  try {
    final directory = await (supportPath ?? () async => (await getApplicationSupportDirectory()).path)();
    final file = File('$directory${Platform.pathSeparator}$preferencesFileName');
    if (!file.existsSync() || preferencesReadable(await file.readAsBytes())) return null;
    await file.rename('$directory${Platform.pathSeparator}$setAsideFileName');
    return setAsideFileName;
  } catch (e) {
    debugPrint('Could not set the preferences file aside: $e');
    return null;
  }
}

/// Whether the plugins can read [bytes] as preferences: nothing at all, or
/// UTF-8 JSON, any object in which holds no null (which they can't cast).
@visibleForTesting
bool preferencesReadable(List<int> bytes) {
  if (bytes.isEmpty) return true;
  try {
    final data = json.decode(utf8.decode(bytes));
    return data is! Map || !data.values.contains(null);
  } on FormatException {
    return false;
  }
}
