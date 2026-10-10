import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reduce Motion reaches every overlay only if nothing goes around the app's
/// helpers (docs/DESIGN_SYSTEM.md §8): dialogs and sheets through
/// showAppDialog and showAppSheet, status messages through showStatus, and
/// every popup menu naming its animation style.
void main() {
  // Each library under lib/, without its comments.
  final sources = {
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart') && !file.path.contains('/l10n/'))
        file.path.replaceAll(r'\', '/'): file.readAsStringSync().replaceAll(RegExp(r'//.*'), ''),
  };

  List<String> uses(RegExp pattern, {required String except}) => [
        for (final MapEntry(key: path, value: source) in sources.entries)
          if (path != except)
            for (final match in pattern.allMatches(source)) '$path: ${match[0]}',
      ];

  test('the sources were found', () => expect(sources, contains('lib/ui/widgets/common.dart')));

  test('dialogs and sheets open through showAppDialog and showAppSheet', () {
    final direct = RegExp(
      r'\b(showDialog|showGeneralDialog|showAdaptiveDialog|showCupertinoDialog|showAboutDialog|'
      r'showModalBottomSheet|showBottomSheet|showCupertinoModalPopup|'
      r'showDatePicker|showDateRangePicker|showTimePicker)\s*[<(]',
    );
    expect(uses(direct, except: 'lib/ui/widgets/common.dart'), isEmpty);
  });

  test('no DropdownButton, whose menu fades in whatever the motion setting', () {
    expect(uses(RegExp(r'\b(DropdownButton|DropdownButtonFormField)\s*[<(]'), except: ''), isEmpty);
  });

  test('status messages go through showStatus', () {
    expect(uses(RegExp(r'\.showSnackBar\s*\('), except: 'lib/services/feedback.dart'), isEmpty);
  });

  test('every popup menu passes popUpAnimationStyle', () {
    final missing = [
      for (final MapEntry(key: path, value: source) in sources.entries)
        for (final line in _menusWithoutStyle(source)) '$path:$line',
    ];
    expect(missing, isEmpty);
  });

  test('the menu check sees every way of writing a menu', () {
    expect(_menusWithoutStyle('PopupMenuButton(itemBuilder: (_) => [])'), [1]);
    expect(_menusWithoutStyle('PopupMenuButton<String>(itemBuilder: (_) => [])'), [1]);
    expect(_menusWithoutStyle('x;\nPopupMenuButton<Map<String, int>> (\n  itemBuilder: f(g()),\n)'), [2]);
    expect(_menusWithoutStyle('showMenu(context: c, items: [])'), [1]);
    expect(_menusWithoutStyle('showMenu<int>(context: c, items: [])'), [1]);
    expect(_menusWithoutStyle('PopupMenuButton(popUpAnimationStyle: s, itemBuilder: f)'), isEmpty);
    expect(_menusWithoutStyle('showMenu<int>(context: c, popUpAnimationStyle: s, items: [])'), isEmpty);
    // Mentions that open nothing.
    expect(_menusWithoutStyle('find.byType(PopupMenuButton<String>); PopupMenuButtonState s;'), isEmpty);
  });
}

/// The lines of [source] that open a popup menu without passing
/// popUpAnimationStyle: a PopupMenuButton or showMenu call, with or without
/// type arguments (nested ones included).
List<int> _menusWithoutStyle(String source) {
  int skipSpace(int i) {
    while (i < source.length && source[i].trim().isEmpty) {
      i++;
    }
    return i;
  }

  final lines = <int>[];
  for (final match in RegExp(r'\b(PopupMenuButton|showMenu)\b').allMatches(source)) {
    var start = skipSpace(match.end);
    if (start < source.length && source[start] == '<') {
      var angles = 0;
      do {
        final c = source[start++];
        if (c == '<') angles++;
        if (c == '>') angles--;
      } while (angles > 0 && start < source.length);
      start = skipSpace(start);
    }
    // A mention that isn't a call, in a type or a finder, has no argument list.
    if (start >= source.length || source[start] != '(') continue;
    // The argument list, up to its closing parenthesis.
    var depth = 0;
    var end = start;
    do {
      final c = source[end++];
      if (c == '(') depth++;
      if (c == ')') depth--;
    } while (depth > 0 && end < source.length);
    if (!source.substring(start, end).contains('popUpAnimationStyle:')) {
      lines.add('\n'.allMatches(source.substring(0, match.start)).length + 1);
    }
  }
  return lines;
}
