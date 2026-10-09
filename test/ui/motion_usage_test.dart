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
      r'\b(showDialog|showGeneralDialog|showAdaptiveDialog|showCupertinoDialog|showModalBottomSheet|'
      r'showDatePicker|showDateRangePicker|showTimePicker)\s*[<(]',
    );
    expect(uses(direct, except: 'lib/ui/widgets/common.dart'), isEmpty);
  });

  test('status messages go through showStatus', () {
    expect(uses(RegExp(r'\.showSnackBar\s*\('), except: 'lib/services/feedback.dart'), isEmpty);
  });

  test('every popup menu passes popUpAnimationStyle', () {
    final missing = <String>[];
    for (final MapEntry(key: path, value: source) in sources.entries) {
      for (final match in RegExp(r'\b(PopupMenuButton\s*<[^>]*>|showMenu\s*(<[^>]*>)?)\s*\(').allMatches(source)) {
        // The argument list, up to its closing parenthesis.
        var depth = 0;
        var end = match.end - 1;
        do {
          final c = source[end++];
          if (c == '(') depth++;
          if (c == ')') depth--;
        } while (depth > 0);
        final arguments = source.substring(match.end, end);
        if (!arguments.contains('popUpAnimationStyle:')) {
          missing.add('$path:${'\n'.allMatches(source.substring(0, match.start)).length + 1}');
        }
      }
    }
    expect(missing, isEmpty);
  });
}
