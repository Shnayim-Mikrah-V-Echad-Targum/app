/// The body, braces and all, of the function or block in the C++ [source]
/// that begins with [start]: CI compiles the Windows runner but never runs
/// it, so tests check its source. Throws if there is none.
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
