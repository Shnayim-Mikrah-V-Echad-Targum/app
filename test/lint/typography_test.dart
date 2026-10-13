import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/features/community/data/demo_forum_repository.dart';

/// The interface's text is typeset, not typed: an apostrophe is ’ (U+2019)
/// and quotation marks are “ ” (Hebrew’s geresh and gershayim are ׳ and ״),
/// never the typewriter's ' and ", which EB Garamond draws as straight ticks.
void main() {
  Map<String, String> values(String path) => {
        for (final MapEntry(:key, :value) in (jsonDecode(File(path).readAsStringSync()) as Map).entries)
          if (!(key as String).startsWith('@')) key: value as String,
      };

  final en = values('lib/l10n/app_en.arb');
  final he = values('lib/l10n/app_he.arb');

  test('the strings were found', () {
    expect(en, contains('appTitle'));
    expect(he, contains('appTitle'));
  });

  test('no English string has a straight apostrophe or quotation mark', () {
    expect(straight(en), isEmpty, reason: 'In lib/l10n/app_en.arb, write ’ for \' and “ ” for ".');
  });

  test('no Hebrew string has a straight apostrophe or quotation mark', () {
    expect(straight(he), isEmpty, reason: 'In tool/l10n/he_strings.py, write ׳ or ’ for \' and ״ or “ ” for ".');
  });

  test('no English policy has a straight apostrophe or quotation mark', () {
    final legal = jsonDecode(File('assets/legal/legal.json').readAsStringSync()) as Map<String, dynamic>;
    final texts = <String, String>{};
    void collect(Object? node, String path) {
      switch (node) {
        case String s:
          texts[path] = s;
        case Map m:
          for (final MapEntry(:key, :value) in m.entries) {
            collect(value, '$path/$key');
          }
        case List l:
          for (final (i, item) in l.indexed) {
            collect(item, '$path/$i');
          }
      }
    }

    collect(legal['en'], 'en');
    collect((legal['titles'] as Map)['en'], 'titles/en');
    expect(texts, hasLength(greaterThan(20)));
    expect(straight(texts), isEmpty, reason: 'In assets/legal/legal.json, write ’ for \' and “ ” for ".');
  });

  test('no forum the demo seeds has a straight apostrophe or quotation mark in its English', () async {
    // The Community page and each forum's page show these as they are; the
    // server's are checked in supabase/tests/behavior.sql.
    final forums = await DemoForumRepository().forums();
    expect(forums, isNotEmpty);
    expect(straight({for (final f in forums) ...{'${f.slug} name': f.nameEn, '${f.slug} description': f.descriptionEn}}), isEmpty,
        reason: 'In lib/features/community/data/demo_forum_repository.dart, write ’ for \' and “ ” for ".');
  });

  test('the check sees what it is for', () {
    expect(straight({'a': 'Today’s “reading”', 'b': "Today's", 'c': 'say "todah"', 'd': 'רש״י'}), ['b', 'c']);
  });
}

/// The keys of [strings] whose text has an ASCII apostrophe (U+0027) or
/// quotation mark (U+0022).
List<String> straight(Map<String, String> strings) => [
      for (final MapEntry(:key, :value) in strings.entries)
        if (value.contains("'") || value.contains('"')) key,
    ];
