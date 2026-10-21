// Where there is no file system (the web), no preferences file to set aside
// (see preferences_recovery.dart).

Future<String?> setAsideUnreadablePreferences({Future<String> Function()? supportPath}) async => null;
