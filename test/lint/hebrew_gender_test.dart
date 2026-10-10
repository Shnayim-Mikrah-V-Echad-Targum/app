import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Hebrew UI addresses the reader without slashed gender forms ("את/ה",
/// "תסיים/י", "מנהל/ת"): it uses an infinitive, a plural or an impersonal
/// form instead, as in "איך לקרוא?" or "צוות הניהול".
void main() {
  final he = {
    for (final MapEntry(:key, :value) in (jsonDecode(File('lib/l10n/app_he.arb').readAsStringSync()) as Map).entries)
      if (!(key as String).startsWith('@')) key: value as String,
  };

  test('the Hebrew strings were found', () => expect(he, contains('appTitle')));

  test('no Hebrew string uses a slashed gender form', () {
    final slashed = [
      for (final MapEntry(:key, :value) in he.entries)
        for (final form in slashedForms(value)) '$key: $form',
    ];
    expect(slashed, isEmpty, reason: 'Rewrite each in tool/l10n/he_strings.py.');
  });

  test('the check sees what it is for', () {
    expect(slashedForms('את/ה מקדים/ה את התוכנית'), ['את/ה', 'מקדים/ה']);
    expect(slashedForms('אם תסיים/י עד שבת'), ['תסיים/י']);
    expect(slashedForms('מחובר/ת בשם'), ['מחובר/ת']);
    expect(slashedForms('חבר/ה לשעבר'), ['חבר/ה']);
    // A slash between words, or between numbers, is not a gender form.
    expect(slashedForms('השמעה / עצירה'), isEmpty);
    expect(slashedForms('2/7 עליות'), isEmpty);
  });
}

/// The words in [s] written with a slash between Hebrew letters.
List<String> slashedForms(String s) =>
    [for (final m in RegExp(r'[א-ת]+/[א-ת]+').allMatches(s)) m[0]!];
