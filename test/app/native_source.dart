import 'dart:convert';
import 'dart:io';

/// The body, braces and all, of the function or block in the C++ [source]
/// that begins with [start]: CI compiles the Windows runner but never runs
/// it, so tests check its source. Kotlin's braces read the same. Throws if
/// there is none.
String cppBody(String source, String start) {
  final at = source.indexOf(start);
  if (at == -1) throw StateError('No "$start" in the source');
  final open = source.indexOf('{', at);
  var depth = 0;
  for (var i = open; open != -1 && i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}' && --depth == 0) return source.substring(open, i + 1);
  }
  throw StateError('"$start" has no body');
}

/// The file at [path] in the package [name], as `flutter pub get` fetched
/// it (.dart_tool/package_config.json): the native source of a plugin,
/// whose names and formats the app's own native code relies on.
String packageSource(String name, String path) {
  final config = File('.dart_tool/package_config.json');
  final packages = (jsonDecode(config.readAsStringSync()) as Map<String, dynamic>)['packages'] as List;
  final package = packages.cast<Map<String, dynamic>>().firstWhere((p) => p['name'] == name);
  final root = config.absolute.uri.resolve('${package['rootUri']}/');
  return File.fromUri(root.resolve(path)).readAsStringSync();
}
