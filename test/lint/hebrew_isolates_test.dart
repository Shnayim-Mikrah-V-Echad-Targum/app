import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Latin runs that the bidi algorithm would reorder inside Hebrew text are
/// isolated (docs/DESIGN_SYSTEM.md §4.6). A range of numbers is the common
/// case: an en dash between digits takes the Hebrew direction, so "1–6"
/// shows as "6–1".
void main() {
  final he = {
    for (final MapEntry(:key, :value) in (jsonDecode(File('lib/l10n/app_he.arb').readAsStringSync()) as Map).entries)
      if (!(key as String).startsWith('@')) key: value as String,
  };

  test('the Hebrew strings were found', () => expect(he, contains('appTitle')));

  test('every isolate in the Hebrew strings is closed', () {
    expect([for (final MapEntry(:key, :value) in he.entries) if (!balanced(value)) key], isEmpty);
  });

  test('every range of numbers in the Hebrew strings is isolated', () {
    final bare = [
      for (final MapEntry(:key, :value) in he.entries)
        for (final range in bareRanges(value)) '$key: $range',
    ];
    expect(bare, isEmpty, reason: r'Put each between \u2066 and \u2069 in tool/l10n/he_strings.py.');
  });

  test('the checks see what they are for', () {
    expect(bareRanges('עליות 1–6 בימים'), ['1–6']);
    expect(bareRanges('לונדון 1929 – 1934, דרך'), ['1929 – 1934']);
    expect(bareRanges('פרק 3:22—4:18'), ['3:22—4:18']);
    expect(bareRanges('עליות \u20661–6\u2069 בימים, \u20662–40\u2069 תווים'), isEmpty);
    // A hyphen-minus joins its numbers into one run of their own.
    expect(bareRanges('גילאי 3-6'), isEmpty);
    expect(bareRanges('א׳–ו׳, 2 עד 3'), isEmpty);

    expect(balanced('\u2066a\u2069 \u2068b\u2069'), isTrue);
    expect(balanced('\u2066a'), isFalse);
    expect(balanced('a\u2069\u2066'), isFalse);
  });
}

/// Whether every isolate in [s] (U+2066, U+2067 or U+2068) is closed by a
/// U+2069 after it, and no U+2069 closes nothing.
bool balanced(String s) {
  var open = 0;
  for (final rune in s.runes) {
    if (rune >= 0x2066 && rune <= 0x2068) open++;
    if (rune == 0x2069 && --open < 0) return false;
  }
  return open == 0;
}

/// The ranges of numbers in [s], joined by an en or em dash, that are not
/// inside an isolate.
List<String> bareRanges(String s) {
  final outside = s.replaceAll(RegExp('[\u2066-\u2068][^\u2069]*\u2069'), ' ');
  return [for (final m in RegExp(r'\d(?:[\d:.,]*\d)?\s?[–—]\s?\d(?:[\d:.,]*\d)?').allMatches(outside)) m[0]!];
}
