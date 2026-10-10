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

    test('a prefix keeps its vowels, and punctuation stays', () {
      expect(HebrewSpeech.spoken('לַֽיהֹוָ֔ה'), 'לַאֲדֹנָי');
      expect(HebrewSpeech.spoken('וַֽיהֹוָ֔ה'), 'וַאֲדֹנָי');
      expect(HebrewSpeech.spoken('כִּ֛י אֲנִ֥י יְהֹוָֽה׃'), 'כִּי אֲנִי אֲדֹנָי.');
      // Deuteronomy 32:6, with two prefix letters.
      expect(HebrewSpeech.spoken('הַֽלְיהֹוָה֙ תִּגְמְלוּ־זֹ֔את'), 'הַלְאֲדֹנָי תִּגְמְלוּ זֹאת');
    });

    group('HaShem after a prefix, as Hebrew joins them', () {
      // Deuteronomy 32:6 (הַֽלְיהֹוָה֙) has an interrogative ה, then ל.
      const cases = {
        'לַֽיהֹוָ֔ה': 'לַשֵּׁם',
        'בַּֽיהֹוָ֔ה': 'בַּשֵּׁם',
        'כַּֽיהֹוָ֔ה': 'כַּשֵּׁם',
        'וַֽיהֹוָ֔ה': 'וְהַשֵּׁם',
        'מֵיְהֹוָ֔ה': 'מֵהַשֵּׁם',
        'שֶׁיְהֹוָ֔ה': 'שֶׁהַשֵּׁם',
        'וּבַֽיהֹוָ֔ה': 'וּבַשֵּׁם',
        'וְלַֽיהֹוָ֔ה': 'וְלַשֵּׁם',
        'הַֽלְיהֹוָה֙': 'הֲלַשֵּׁם',
      };
      for (final MapEntry(key: written, value: spoken) in cases.entries) {
        test('$written is read $spoken', () {
          expect(HebrewSpeech.spoken(written, divineName: DivineNameSpeech.hashem), spoken);
        });
      }

      test('in the Targum and Rashi too, with punctuation kept', () {
        expect(HebrewSpeech.spoken('לַיָי', targum: true, divineName: DivineNameSpeech.hashem), 'לַשֵּׁם');
        expect(HebrewSpeech.spoken('קֳדָם דַּיְיָ:', targum: true, divineName: DivineNameSpeech.hashem), 'קֳדָם דְּהַשֵּׁם:');
        expect(HebrewSpeech.spoken('"לַה׳", כְּמוֹ', rashi: true, divineName: DivineNameSpeech.hashem), '"לַשֵּׁם", כְּמוֹ');
        expect(HebrewSpeech.spoken("וה' המטיר.", rashi: true, divineName: DivineNameSpeech.hashem), 'וְהַשֵּׁם המטיר.');
        // Genesis 24:50 and the heading of Deuteronomy 32:6, in Rashi.
        expect(
          HebrewSpeech.spoken("וְנִכָּר שֶׁמֵּה' יָצָא", rashi: true, divineName: DivineNameSpeech.hashem),
          'וְנִכָּר שֶׁמֵּהַשֵּׁם יָצָא',
        );
        expect(HebrewSpeech.spoken("הלה' תגמלו זאת.", rashi: true, divineName: DivineNameSpeech.hashem), 'הֲלַשֵּׁם תגמלו זאת.');
      });
    });

    group('Targum', () {
      test('the Name יְיָ is read as chosen', () {
        expect(HebrewSpeech.spoken('וַאֲמַר יְיָ', targum: true), 'וַאֲמַר אֲדֹנָי');
        expect(HebrewSpeech.spoken('וַאֲמַר יְיָ', targum: true, divineName: DivineNameSpeech.hashem), 'וַאֲמַר הַשֵּׁם');
        expect(HebrewSpeech.spoken('וַאֲמַר יְיָ', targum: true, keepNikud: false), 'ואמר אדני');
      });

      test('with a prefix', () {
        expect(HebrewSpeech.spoken('קֳדָם דַּיְיָ', targum: true), 'קֳדָם דַּאֲדֹנָי');
        expect(HebrewSpeech.spoken('וְהֵימִין בְּמֵימְרָא דַיְיָ:', targum: true), 'וְהֵימִין בְּמֵימְרָא דַאֲדֹנָי:');
      });

      test('only when asked for', () {
        expect(HebrewSpeech.spoken('וַאֲמַר יְיָ'), 'וַאֲמַר יְיָ');
        expect(HebrewSpeech.spoken('וַאֲמַר יְיָ', rashi: true), 'וַאֲמַר יְיָ');
      });
    });

    group('Rashi', () {
      test("ה' is read as chosen, but not as a chapter number", () {
        expect(HebrewSpeech.spoken("וַיֹּאמֶר ה' (שמות ה')", rashi: true), "וַיֹּאמֶר אֲדֹנָי (שמות ה')");
        expect(
          HebrewSpeech.spoken("עַד שַׁקַּמְתִּי דְּבוֹרָה (שופטים ה') כְּמוֹ", rashi: true),
          "עַד שַׁקַּמְתִּי דְּבוֹרָה (שופטים ה') כְּמוֹ",
        );
        expect(HebrewSpeech.spoken("(פסוק יד) \"ה' יִלָּחֵם לָכֶם\"", rashi: true), '(פסוק יד) "אֲדֹנָי יִלָּחֵם לָכֶם"');
      });

      test('a remark in parentheses can name it too', () {
        expect(
          HebrewSpeech.spoken("(וְכֵן לִישׁוּעָה, ה' אִישׁ מִלְחָמָה ה' שְׁמוֹ, וְכֵן כֻּלָּם)", rashi: true),
          '(וְכֵן לִישׁוּעָה, אֲדֹנָי אִישׁ מִלְחָמָה אֲדֹנָי שְׁמוֹ, וְכֵן כֻּלָּם)',
        );
        expect(HebrewSpeech.spoken("(שֶׁנֶּאֱמַר בָּנִים אַתֶּם לַה')", rashi: true), '(שֶׁנֶּאֱמַר בָּנִים אַתֶּם לַאֲדֹנָי)');
      });

      test('with a prefix, punctuation and quotation marks', () {
        expect(HebrewSpeech.spoken("יוֹדוּ לַה' חַסְדּוֹ", rashi: true), 'יוֹדוּ לַאֲדֹנָי חַסְדּוֹ');
        expect(HebrewSpeech.spoken("לפני ה'.", rashi: true, divineName: DivineNameSpeech.hashem), 'לפני הַשֵּׁם.');
        expect(HebrewSpeech.spoken('"לַה׳", כְּמוֹ', rashi: true), '"לַאֲדֹנָי", כְּמוֹ');
        expect(HebrewSpeech.spoken("וה' המטיר.", rashi: true), 'ואֲדֹנָי המטיר.');
      });

      test('after two prefix letters, an Aramaic ד, or quotation marks', () {
        // Genesis 24:50, Exodus 15:17, Exodus 34:5 and the heading of
        // Deuteronomy 32:6, as the bundled Rashi writes them.
        expect(HebrewSpeech.spoken("וְנִכָּר שֶׁמֵּה' יָצָא הַדָּבָר", rashi: true), 'וְנִכָּר שֶׁמֵּאֲדֹנָי יָצָא הַדָּבָר');
        expect(HebrewSpeech.spoken("בִּזְמַן שֶׁ\"ה' יִמְלֹךְ", rashi: true), 'בִּזְמַן שֶׁאֲדֹנָי יִמְלֹךְ');
        expect(HebrewSpeech.spoken("וּקְרָא בִשְׁמָא דַה':", rashi: true), 'וּקְרָא בִשְׁמָא דַאֲדֹנָי:');
        expect(HebrewSpeech.spoken("הלה' תגמלו זאת.", rashi: true), 'הלאֲדֹנָי תגמלו זאת.');
      });

      test("ה' counting something is a number", () {
        expect(HebrewSpeech.spoken("וּבֶן ע' כְּבֶן ה' בְּלֹא חֵטְא", rashi: true), "וּבֶן ע' כְּבֶן ה' בְּלֹא חֵטְא");
        expect(HebrewSpeech.spoken("וְה' מֵאוֹת", rashi: true), "וְה' מֵאוֹת");
        expect(HebrewSpeech.spoken("וּלְפִיכָךְ מֵת ה' שָׁנִים קֹדֶם זְמַנּוֹ", rashi: true), "וּלְפִיכָךְ מֵת ה' שָׁנִים קֹדֶם זְמַנּוֹ");
      });

      test('only when asked for', () {
        expect(HebrewSpeech.spoken("וַיֹּאמֶר ה'"), "וַיֹּאמֶר ה'");
        expect(HebrewSpeech.spoken("וַיֹּאמֶר ה'", targum: true), "וַיֹּאמֶר ה'");
      });
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
