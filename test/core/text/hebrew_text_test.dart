import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/text/hebrew_text.dart';

void main() {
  const genesis11 = 'בְּרֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים אֵ֥ת הַשָּׁמַ֖יִם וְאֵ֥ת הָאָֽרֶץ׃';

  test('stripTeamim removes cantillation and meteg but keeps vowels', () {
    expect(HebrewText.stripTeamim(genesis11), 'בְּרֵאשִׁית בָּרָא אֱלֹהִים אֵת הַשָּׁמַיִם וְאֵת הָאָרֶץ׃');
  });

  test('stripNikud removes vowels and keeps letters and punctuation', () {
    expect(HebrewText.consonantsOnly(genesis11), 'בראשית ברא אלהים את השמים ואת הארץ׃');
  });

  test('paseq collapses to a single space when cantillation is hidden', () {
    expect(HebrewText.stripTeamim('אֱלֹהִ֤ים ׀ לָאוֹר֙'), 'אֱלֹהִים לָאוֹר');
  });

  test('maqaf is kept', () {
    expect(HebrewText.consonantsOnly('עַל־פְּנֵ֣י'), 'על־פני');
  });

  test('isMark names exactly the marks consonantsOnly removes', () {
    for (final c in [for (var c = 0x0590; c <= 0x05FF; c++) c, 0x034F]) {
      // The paseq becomes a space rather than vanishing.
      if (c == 0x05C0) {
        expect(HebrewText.isMark(c), isFalse);
        continue;
      }
      final removed = HebrewText.consonantsOnly('א${String.fromCharCode(c)}ב') == 'אב';
      expect(HebrewText.isMark(c), removed, reason: 'U+${c.toRadixString(16)}');
    }
    for (final kept in ['־', '׃', 'א', 'ת', ' ']) {
      expect(HebrewText.isMark(kept.codeUnitAt(0)), isFalse, reason: kept);
    }
  });

  test('foldFinals writes final letters in their ordinary forms', () {
    expect(HebrewText.foldFinals('ךםןףץ'), 'כמנפצ');
    expect(HebrewText.foldFinals('הָאָרֶץ וַיֵּלֶךְ חָרָן'), 'הָאָרֶצ וַיֵּלֶכְ חָרָנ');
    expect(HebrewText.foldFinals('Abraham'), 'Abraham');
    expect(HebrewText.foldFinal('ם'.codeUnitAt(0)), 'מ'.codeUnitAt(0));
    expect(HebrewText.foldFinal('ב'.codeUnitAt(0)), 'ב'.codeUnitAt(0));
  });

  test('gematria', () {
    expect(HebrewText.gematria(1), 'א׳');
    expect(HebrewText.gematria(15), 'ט״ו');
    expect(HebrewText.gematria(16), 'ט״ז');
    expect(HebrewText.gematria(28), 'כ״ח');
    expect(HebrewText.gematria(787), 'תשפ״ז');
    expect(HebrewText.gematria(31, punctuate: false), 'לא');
  });

  group('parseGematria', () {
    test('reads numbers with or without a geresh or gershayim', () {
      expect(HebrewText.parseGematria('כ״ח'), 28);
      expect(HebrewText.parseGematria('כח'), 28);
      expect(HebrewText.parseGematria('י״ב'), 12);
      expect(HebrewText.parseGematria('א׳'), 1);
      expect(HebrewText.parseGematria('ק׳'), 100);
      expect(HebrewText.parseGematria('תשפ״ז'), 787);
    });

    test('takes the quotation marks typed for them', () {
      expect(HebrewText.parseGematria('כ"ח'), 28);
      expect(HebrewText.parseGematria("ג'"), 3);
      expect(HebrewText.parseGematria('ט”ו'), 15);
    });

    test('reads 15 and 16 as they are written', () {
      expect(HebrewText.parseGematria('ט״ו'), 15);
      expect(HebrewText.parseGematria('טז'), 16);
      expect(HebrewText.parseGematria('קט״ו'), 115);
      expect(HebrewText.parseGematria('יה'), isNull);
      expect(HebrewText.parseGematria('יו'), isNull);
    });

    test('takes no word for a number', () {
      for (final word in ['בא', 'לך', 'ראה', 'עקב', 'חכ', 'אב', 'כך', '', '׳', 'abc', '12', 'כ ח']) {
        expect(HebrewText.parseGematria(word), isNull, reason: word);
      }
    });

    test('reads back every number gematria writes', () {
      for (var n = 1; n < 1000; n++) {
        expect(HebrewText.parseGematria(HebrewText.gematria(n)), n, reason: '$n');
        expect(HebrewText.parseGematria(HebrewText.gematria(n, punctuate: false)), n, reason: '$n');
      }
    });
  });

  group('HebrewSpeech', () {
    test('the Divine Name is read as Adonai, or Elohim where so vocalized', () {
      expect(HebrewSpeech.spoken('וַיֹּ֥אמֶר יְהֹוָ֖ה אֶל־מֹשֶׁ֑ה'), contains('אֲדֹנָי'));
      expect(HebrewSpeech.spoken('אֲדֹנָ֤י יֱהֹוִה֙'), contains('אֱלֹהִים'));
      expect(HebrewSpeech.spoken('לַֽיהֹוָ֔ה'), startsWith('ל'));
    });

    test('HaShem mode', () {
      expect(HebrewSpeech.spoken('יְהֹוָ֖ה', divineName: DivineNameSpeech.hashem), 'הַשֵּׁם');
    });

    test('cantillation is removed and maqaf becomes a space', () {
      final s = HebrewSpeech.spoken('עַל־פְּנֵ֣י תְה֑וֹם׃');
      expect(s, 'עַל פְּנֵי תְהוֹם.');
    });

    test('a sof pasuq is always followed by a space', () {
      expect(HebrewSpeech.spoken('לֹ֥א תִּרְצָ֖ח׃לֹ֣א תִּנְאָ֑ף׃'), 'לֹא תִּרְצָח. לֹא תִּנְאָף.');
    });

    test('consonants-only output', () {
      expect(HebrewSpeech.spoken(genesis11, keepNikud: false, divineName: DivineNameSpeech.hashem),
          'בראשית ברא אלהים את השמים ואת הארץ.');
    });
  });
}
