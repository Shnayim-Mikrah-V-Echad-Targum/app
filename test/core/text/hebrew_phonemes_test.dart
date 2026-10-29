import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/core/text/hebrew_phonemes.dart';
import 'package:shnayim_mikrah/core/text/hebrew_text.dart';
import 'package:shnayim_mikrah/services/hebrew_voice/hebrew_voice.dart';

void main() {
  String p(String text) => HebrewPhonemes.phonemize(text);

  group('the stress', () {
    test('stands where the accent does', () {
      // Tipcha on the shin, munach on the resh, etnachta on the he.
      expect(p('בְּרֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים'), 'beʁeʃˈit baʁˈa ʔelohˈim,');
      // A segolate, stressed before its last syllable.
      expect(p('וְהָאָ֗רֶץ'), 'vehaʔˈaʁets');
      expect(p('וַיֹּ֥אמֶר'), 'vajˈomeʁ');
    });

    test('takes the silluq of a verse\'s last word, which shares the meteg\'s sign', () {
      expect(p('וְאֵ֥ת הָאָֽרֶץ׃'), 'veʔˈet haʔˈaʁets.');
    });

    test('ignores accents written before or after the word, whatever its stress', () {
      // A single pashta on the last letter: the stress is the last syllable's.
      expect(p('תֹ֙הוּ֙'), 'tˈohu', reason: 'a pashta written twice: the first is the stress');
      // Zarqa is written on the last letter; a word without another accent
      // is read on its last syllable.
      expect(p('אֱלֹהִים֮'), 'ʔelohˈim');
    });

    test('falls on the last syllable without an accent, but before a dual\'s -ayim', () {
      expect(p('שָׁלוֹם'), 'ʃalˈom');
      expect(p('צָהֳרַיִם'), 'tsohoʁˈajim');
      expect(p('רוּחַ'), 'ʁˈuaχ', reason: 'not on a furtive patah');
    });
  });

  group('the vowels', () {
    test('a vocal shva at the start, after a silent one, under a doubled letter, and before the same letter', () {
      expect(p('יְהִ֣י'), 'jehˈi');
      expect(p('הַֽמִּשְׁפְּתָֽיִם׃'), 'hamiʃpetˈajim.');
      expect(p('הִנְנִי'), 'hinenˈi');
      expect(p('וּקְשַׁרְתָּ֥ם'), 'ukeʃaʁtˈam', reason: 'after the conjunction וּ, still the start');
      expect(p('וַֽיְהִי'), 'vajhˈi', reason: 'a silent shva after a short vowel');
    });

    test('vowel letters, holam male and shuruk, and a consonant ו before a holam', () {
      expect(p('תְה֑וֹם'), 'tehˈom,');
      expect(p('מִצְוֹת'), 'mitsvˈot');
      expect(p('עֲוֹן'), 'ʔavˈon');
      expect(p('וּבֵין'), 'uvˈen');
      expect(p('דְּבָרָיו'), 'devaʁˈav');
      expect(p('אֲדֹנָי'), 'ʔadonˈaj');
    });

    test('a qamatz qatan where the text marks it, and before a hataf qamatz', () {
      expect(p('כׇּל'), 'kˈol');
      expect(p('צָהֳרַיִם'), startsWith('tsoho'));
    });

    test('the patah of Jerusalem\'s lamed with its hiriq, and Issachar\'s second shin not read', () {
      expect(p('יְרוּשָׁלַ͏ִם'), 'jeʁuʃalˈajim');
      expect(p('יִשָּׂשכָ֖ר'), 'jisaχˈaʁ');
    });

    test('a furtive patah read before its letter, and a mappiq\'s ה sounded', () {
      expect(p('וְר֣וּחַ'), 'veʁˈuaχ');
      expect(p('אַרְצָהּ'), 'ʔaʁtsˈah');
    });
  });

  test('pauses after the great dividing accents, a paseq, and the end of a verse', () {
    expect(p('וַיֹּ֥אמֶר אֱלֹהִ֖ים יְהִ֣י א֑וֹר וַֽיְהִי־אֽוֹר׃'), 'vajˈomeʁ ʔelohˈim jehˈi ʔˈoʁ, vajhˈi ʔˈoʁ.');
    expect(p('וַיִּקְרָ֨א ׀ אֱלֹהִ֤ים'), 'vajikʁˈa, ʔelohˈim');
  });

  test('never voices the Divine Name as written, in the Torah or the Targum', () {
    expect(p('וַיֹּ֤אמֶר יְהֹוָה֙'), 'vajˈomeʁ ʔadonˈaj');
    expect(p('לַיהוָה'), 'laʔadonˈaj');
    expect(p('בְּרָא יְיָ'), 'beʁˈa ʔadonˈaj');
    // As Listen gives it, the reader's choice made first.
    final hashem = HebrewSpeech.spoken('וַיֹּ֤אמֶר יְהֹוָה֙ אֶל־אַבְרָ֔ם', keepTeamim: true, divineName: DivineNameSpeech.hashem);
    expect(p(hashem), 'vajˈomeʁ haʃˈem ʔˈel ʔavʁˈam,');
  });

  test('tells pointed text from bare letters', () {
    expect(HebrewPhonemes.isPointed('בְּרֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים'), isTrue);
    expect(HebrewPhonemes.isPointed('בראשית ברא אלהים'), isFalse);
    expect(HebrewPhonemes.isPointed('Rashi in English'), isFalse);
  });

  test('every verse of the Torah and of Onkelos becomes sounds the voice has', () {
    String flat(Object? v) => switch (v) {
          String s => s,
          List l => l.map(flat).join(),
          Map m => '${m['big'] ?? m['small'] ?? m['text'] ?? ''}',
          _ => '',
        };
    final unknown = <String>{};
    var verses = 0;
    for (final layer in ['mikrah', 'onkelos']) {
      for (final book in ['genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy']) {
        final data = jsonDecode(File('assets/text/$layer/$book.json').readAsStringSync()) as Map;
        for (final chapter in data['chapters'] as List) {
          for (final verse in chapter as List) {
            final text = HebrewSpeech.spoken(flat(verse), keepTeamim: true, targum: layer == 'onkelos');
            final sounds = p(text);
            verses++;
            expect(sounds, isNotEmpty, reason: text);
            for (final rune in sounds.runes) {
              final c = String.fromCharCode(rune);
              if (!HebrewVoice.speaks(c)) unknown.add(c);
            }
            expect(sounds, isNot(contains('jehov')), reason: text);
          }
        }
      }
    }
    expect(verses, greaterThan(11000));
    expect(unknown, isEmpty);
  });
}
