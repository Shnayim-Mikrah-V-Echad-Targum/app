import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Padding that differs between its left and right sides is written by start
/// and end (EdgeInsetsDirectional), so that it mirrors in the Hebrew UI. A
/// physical EdgeInsets with unequal sides is right in one direction only: in
/// RTL a post header or a notice's icon ends up against the card's edge.
///
/// Physical padding that is meant to be so, such as around scripture, which
/// runs right to left in both UIs, is listed in [_physical] with the reason.
void main() {
  final sources = {
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart')) file.path.replaceAll(r'\', '/'): file.readAsStringSync(),
  };

  test('the sources were found', () => expect(sources, contains('lib/ui/widgets/common.dart')));

  test('no EdgeInsets.fromLTRB or EdgeInsets.only has unequal left and right sides', () {
    final offenders = [
      for (final MapEntry(key: path, value: source) in sources.entries)
        for (final (line, call) in unequalSides(source))
          if (!_physical.containsKey('$path: $call')) '$path:$line: $call',
    ];
    expect(
      offenders,
      isEmpty,
      reason: 'Write these with EdgeInsetsDirectional (start and end), or list a padding that must not mirror in '
          '_physical with the reason.',
    );
  });

  test('every padding allowed to stay physical is still there', () {
    final found = {
      for (final MapEntry(key: path, value: source) in sources.entries)
        for (final (_, call) in unequalSides(source)) '$path: $call',
    };
    expect(_physical.keys.where((k) => !found.contains(k)), isEmpty);
  });

  test('the check sees every way of writing them', () {
    List<String> calls(String source) => [for (final (_, call) in unequalSides(source)) call];

    expect(calls('EdgeInsets.fromLTRB(16, 8, 4, 8)'), ['EdgeInsets.fromLTRB(16,8,4,8)']);
    expect(calls('const EdgeInsets.only(right: 4)'), ['EdgeInsets.only(right:4)']);
    expect(calls('EdgeInsets.only(left: 8, top: 2)'), ['EdgeInsets.only(left:8,top:2)']);
    expect(calls('EdgeInsets.only(left: p.left, right: q.right)'), hasLength(1));
    expect(calls('x;\nEdgeInsets.fromLTRB(\n  f(a, b),\n  0,\n  g(a),\n  0,\n)'), hasLength(1));
    expect(unequalSides('a;\nb;\nEdgeInsets.only(right: 1)').single.$1, 3);

    // Equal sides, or none.
    expect(calls('EdgeInsets.fromLTRB(16, first ? 16 : 0, 16, last ? 16 : 0)'), isEmpty);
    expect(calls('EdgeInsets.fromLTRB(16, 0, 16.0, 0)'), isEmpty);
    expect(calls('EdgeInsets.fromLTRB(f(a, b), 0, f(a,b), 0,)'), isEmpty);
    expect(calls('EdgeInsets.only(top: 4, bottom: 12)'), isEmpty);
    expect(calls('EdgeInsets.only(left: 8, right: 8)'), isEmpty);
    // Sides of a padding already resolved for the text direction.
    expect(calls('EdgeInsets.only(left: p.left, right: p.right)'), isEmpty);
    expect(calls('EdgeInsets.fromLTRB(inset.left, 4, inset.right, 4)'), isEmpty);
    // Directional padding, and mentions that are not code.
    expect(calls('EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8)'), isEmpty);
    expect(calls('EdgeInsetsDirectional.only(start: 8)'), isEmpty);
    expect(calls('// EdgeInsets.only(left: 8)\n/* EdgeInsets.fromLTRB(1, 2, 3, 4) */'), isEmpty);
    expect(calls("final s = 'EdgeInsets.only(left: 8)', t = \"\${'EdgeInsets.only(left: 8)'}\";"), isEmpty);
    expect(calls("r'EdgeInsets.only(left: 8)'; '''\nEdgeInsets.only(left: 8)\n'''"), isEmpty);
    // Code inside an interpolation is still code.
    expect(calls(r"'${EdgeInsets.only(left: 8)}'"), hasLength(1));
  });
}

/// Physical paddings with unequal sides that are meant not to mirror, as
/// `'path: call'`, the call without its spaces, with the reason.
const _physical = <String, String>{
  'lib/features/reader/scripture_text.dart: EdgeInsets.only(right:ruleGap)':
      "A verse's gold rule, at the scripture's start: the right, in either language of the app (§4.7).",
  'lib/features/reader/scripture_text.dart: EdgeInsets.only(right:ScriptureStyles(context,settings).hangingGutter(constraints.maxWidth))':
      "The gutter a verse's number hangs in, at the right of the Hebrew in either language of the app (§4.7).",
  'lib/features/reader/reader_screen.dart: EdgeInsets.only(right:12)':
      "The rule of the Hebrew's block among the Targum, where the Hebrew begins: at the right in either language.",
};

/// The EdgeInsets.fromLTRB and EdgeInsets.only calls in [source] whose left
/// and right sides differ, with the line each starts on, and the call without
/// its spaces. A side read from the same side of a padding (`p.left` and
/// `p.right`) passes: that padding was resolved for the text direction.
List<(int, String)> unequalSides(String source) {
  final code = _codeOnly(source);
  final found = <(int, String)>[];
  for (final match in RegExp(r'\bEdgeInsets\s*\.\s*(fromLTRB|only)\s*\(').allMatches(code)) {
    final open = match.end - 1;
    final close = _closing(code, open);
    final args = _splitArguments(code.substring(open + 1, close));
    final String left, right;
    if (match[1] == 'fromLTRB') {
      if (args.length != 4) continue;
      (left, right) = (args[0], args[2]);
    } else {
      final named = {
        for (final a in args)
          if (RegExp(r'^(\w+)\s*:([\s\S]*)$').firstMatch(a) case final m?) m[1]!: m[2]!.trim(),
      };
      (left, right) = (named['left'] ?? '0', named['right'] ?? '0');
    }
    if (_same(left, right)) continue;
    final call = code.substring(match.start, close + 1).replaceAll(RegExp(r'\s'), '');
    found.add(('\n'.allMatches(code.substring(0, match.start)).length + 1, call));
  }
  return found;
}

bool _same(String left, String right) {
  String normal(String s) {
    final t = s.replaceAll(RegExp(r'\s'), '');
    return num.tryParse(t)?.toDouble().toString() ?? t;
  }

  final (l, r) = (normal(left), normal(right));
  if (l == r) return true;
  final resolved = RegExp(r'^(.+)\.left$').firstMatch(l)?.group(1);
  return resolved != null && r == '$resolved.right';
}

/// The index of the bracket that closes the one at [open].
int _closing(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    if ('([{'.contains(code[i])) depth++;
    if (')]}'.contains(code[i]) && --depth == 0) return i;
  }
  return code.length - 1;
}

/// [args] split at its top-level commas, each trimmed, without a trailing
/// empty one.
List<String> _splitArguments(String args) {
  final parts = <String>[];
  var depth = 0, start = 0;
  for (var i = 0; i < args.length; i++) {
    final c = args[i];
    if ('([{'.contains(c)) depth++;
    if (')]}'.contains(c)) depth--;
    if (c == ',' && depth == 0) {
      parts.add(args.substring(start, i).trim());
      start = i + 1;
    }
  }
  final last = args.substring(start).trim();
  if (last.isNotEmpty) parts.add(last);
  return parts;
}

/// [source] with its comments and the text of its strings blanked out, line
/// breaks kept, so that offsets and line numbers still match. The code inside
/// an interpolation (`${…}`) is kept.
String _codeOnly(String source) {
  final out = StringBuffer();
  // For each string being read, its quote; null for an interpolation's code,
  // with the depth of its braces alongside.
  final stack = <(String?, int)>[];
  var i = 0;
  void blank(int n) {
    for (var k = 0; k < n && i < source.length; k++, i++) {
      out.write(source[i] == '\n' ? '\n' : ' ');
    }
  }

  void keep(int n) {
    out.write(source.substring(i, i + n));
    i += n;
  }

  while (i < source.length) {
    final top = stack.isEmpty ? null : stack.last;
    final quote = top?.$1;
    if (quote != null) {
      // Inside a string. A raw one is marked by a leading 'r'.
      final raw = quote.startsWith('r');
      final q = raw ? quote.substring(1) : quote;
      if (source.startsWith(q, i)) {
        stack.removeLast();
        keep(q.length);
      } else if (!raw && source[i] == r'\') {
        blank(2);
      } else if (!raw && source.startsWith(r'${', i)) {
        stack.add((null, 0));
        keep(2);
      } else {
        blank(1);
      }
      continue;
    }
    if (source.startsWith('//', i)) {
      while (i < source.length && source[i] != '\n') {
        blank(1);
      }
    } else if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      blank((end < 0 ? source.length : end + 2) - i);
    } else if (RegExp(r"""r?('''|\"\"\"|'|")""").matchAsPrefix(source, i) case final m?
        when i == 0 || !RegExp(r'\w').hasMatch(source[i - 1]) || m[0]!.startsWith(m[1]!)) {
      stack.add((m[0]!.startsWith('r') ? 'r${m[1]}' : m[1], 0));
      keep(m[0]!.length);
    } else if (top != null && source[i] == '{') {
      stack[stack.length - 1] = (null, top.$2 + 1);
      keep(1);
    } else if (top != null && source[i] == '}') {
      if (top.$2 == 0) {
        stack.removeLast();
      } else {
        stack[stack.length - 1] = (null, top.$2 - 1);
      }
      keep(1);
    } else {
      keep(1);
    }
  }
  return out.toString();
}
