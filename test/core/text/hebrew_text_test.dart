import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/text/hebrew_text.dart';

void main() {
  const genesis11 = 'בְּרֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים אֵ֥ת הַשָּׁמַ֖יִם וְאֵ֥ת הָאָֽרֶץ׃';

  // Dots over every letter of וַיִּשָּׁקֵהוּ, as written in the scroll.
  const genesis33_4 = 'וַיָּ֨רׇץ עֵשָׂ֤ו לִקְרָאתוֹ֙ וַֽיְחַבְּקֵ֔הוּ וַיִּפֹּ֥ל עַל־צַוָּארָ֖ו וַׄיִּׄשָּׁׄקֵ֑ׄהׄוּׄ וַיִּבְכּֽוּ׃';
  // Set off by an inverted nun at its start.
  const numbers10_35 = '׆ וַיְהִ֛י בִּנְסֹ֥עַ הָאָרֹ֖ן וַיֹּ֣אמֶר מֹשֶׁ֑ה קוּמָ֣ה ׀ יְהֹוָ֗ה וְיָפֻ֙צוּ֙ אֹֽיְבֶ֔יךָ';

  test('stripTeamim removes cantillation and meteg but keeps vowels', () {
    expect(HebrewText.stripTeamim(genesis11), 'בְּרֵאשִׁית בָּרָא אֱלֹהִים אֵת הַשָּׁמַיִם וְאֵת הָאָרֶץ׃');
  });

  test('stripNikud removes vowels and keeps letters and punctuation', () {
    expect(HebrewText.consonantsOnly(genesis11), 'בראשית ברא אלהים את השמים ואת הארץ׃');
  });

  test('paseq collapses to a single space when cantillation is hidden', () {
    expect(HebrewText.stripTeamim('אֱלֹהִ֤ים ׀ לָאוֹר֙'), 'אֱלֹהִים לָאוֹר');
  });

  group('the Masoretic dots', () {
    test('stay when cantillation is hidden, with or without vowels', () {
      for (final nikud in [true, false]) {
        final shown = HebrewText.forDisplay(genesis33_4, nikud: nikud, teamim: false);
        expect('\u05c4'.allMatches(shown), hasLength(6), reason: 'nikud: $nikud');
        expect(shown, isNot(contains('\u0591')), reason: 'the etnachta is gone');
      }
      expect(HebrewText.forDisplay(genesis33_4, nikud: false, teamim: false), contains('ו\u05c4י\u05c4ש\u05c4ק\u05c4ה\u05c4ו\u05c4'));
    });

    test('are not letters', () {
      expect(HebrewText.consonantsOnly(genesis33_4), contains(' וישקהו '));
    });

    test('and the inverted nun are not spoken', () {
      final s = HebrewSpeech.spoken(numbers10_35);
      expect(s, isNot(contains('\u05c6')));
      expect(s, startsWith('וַיְהִי בִּנְסֹעַ'));
      final kiss = HebrewSpeech.spoken(genesis33_4);
      expect(kiss, isNot(contains('\u05c4')));
      expect(kiss, contains(' וַיִּשָּׁקֵהוּ '));
    });
  });

  test('maqaf is kept', () {
    expect(HebrewText.consonantsOnly('עַל־פְּנֵ֣י'), 'על־פני');
  });

  test('gematria', () {
    expect(HebrewText.gematria(1), 'א׳');
    expect(HebrewText.gematria(15), 'ט״ו');
    expect(HebrewText.gematria(16), 'ט״ז');
    expect(HebrewText.gematria(28), 'כ״ח');
    expect(HebrewText.gematria(787), 'תשפ״ז');
    expect(HebrewText.gematria(31, punctuate: false), 'לא');
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
