/// Utilities for pointed (nikud) and cantillated (ta'amim) Hebrew text.
///
/// Unicode reference: the Hebrew block U+0590–U+05FF.
///  * U+0591–U+05AF  cantillation marks (ta'amim)
///  * U+05BD         meteg (a stress/secondary accent mark)
///  * U+05C0         paseq / legarmeih stroke
///  * U+05C4–U+05C5  upper / lower Masoretic dots: the extraordinary points
///                   written in the Sefer Torah (e.g. over וישקהו, Gen 33:4)
///  * U+05C6         nun hafucha, the inverted nun around Num 10:35–36
///  * U+05B0–U+05BC, U+05BF, U+05C1–U+05C2, U+05C7  vowel points, dagesh,
///                   rafe, shin/sin dots, qamatz qatan
///  * U+034F         combining grapheme joiner, used to order marks
abstract final class HebrewText {
  static final _teamim = RegExp('[\u0591-\u05af\u05bd]');
  static final _nikud = RegExp('[ְ-ׇּֿׁׂ]');
  static final _cgj = RegExp('͏');
  // Part of the text of the scroll, so shown whatever the display settings;
  // only speech leaves them out.
  static final _masoraDots = RegExp('[\u05c4\u05c5]');
  // A paseq with the spaces around it collapses to a single space.
  static final _paseq = RegExp(r'\s*׀\s*');
  static final _spaces = RegExp(r'[  ]{2,}');

  /// Removes cantillation marks, meteg and the paseq stroke. The Masoretic
  /// dots stay: they are written in the scroll, not added for chanting.
  static String stripTeamim(String s) => s
      .replaceAll(_paseq, ' ')
      .replaceAll(_teamim, '')
      .replaceAll(_cgj, '')
      .replaceAll(_spaces, ' ');

  /// Removes vowel points (and dagesh, shin/sin dots).
  static String stripNikud(String s) =>
      s.replaceAll(_nikud, '').replaceAll(_cgj, '');

  /// Removes every mark, leaving only letters and punctuation.
  static String consonantsOnly(String s) => stripNikud(stripTeamim(s)).replaceAll(_masoraDots, '');

  /// Applies the reader's display preferences.
  static String forDisplay(String s, {required bool nikud, required bool teamim}) {
    var out = s;
    if (!teamim) out = stripTeamim(out);
    if (!nikud) out = stripNikud(out);
    return out;
  }

  static bool containsHebrew(String s) => RegExp('[֐-׿]').hasMatch(s);

  /// Whether [codeUnit] is one of the marks [consonantsOnly] removes: a
  /// cantillation mark, meteg, vowel point, dagesh, shin or sin dot, a
  /// Masoretic dot, or the combining grapheme joiner. The paseq is not one:
  /// it stands between words.
  static bool isMark(int codeUnit) =>
      (codeUnit >= 0x0591 && codeUnit <= 0x05BD) ||
      codeUnit == 0x05BF ||
      codeUnit == 0x05C1 ||
      codeUnit == 0x05C2 ||
      codeUnit == 0x05C4 ||
      codeUnit == 0x05C5 ||
      codeUnit == 0x05C7 ||
      codeUnit == 0x034F;

  static final _finals = RegExp('[ךםןףץ]');

  /// Writes the five final letters (ך ם ן ף ץ) in their ordinary forms, so a
  /// word compares alike whether or not it ends where they stand.
  static String foldFinals(String s) =>
      s.replaceAllMapped(_finals, (m) => String.fromCharCode(foldFinal(m[0]!.codeUnitAt(0))));

  /// [foldFinals] for one UTF-16 code unit: a final letter's ordinary form,
  /// which Unicode places straight after it, or [codeUnit] itself.
  static int foldFinal(int codeUnit) => switch (codeUnit) {
        0x05DA || 0x05DD || 0x05DF || 0x05E3 || 0x05E5 => codeUnit + 1,
        _ => codeUnit,
      };

  static const _hebrewLetters = 'אבגדהוזחטיכלמנסעפצקרשת';

  /// Formats a number in Hebrew numerals (gematria), e.g. 15 → ט״ו.
  static String gematria(int n, {bool punctuate = true}) {
    if (n <= 0) return '$n';
    final buf = StringBuffer();
    var rest = n % 1000;
    const hundreds = ['', 'ק', 'ר', 'ש', 'ת', 'תק', 'תר', 'תש', 'תת', 'תתק'];
    buf.write(hundreds[rest ~/ 100]);
    rest %= 100;
    if (rest == 15) {
      buf.write('טו');
    } else if (rest == 16) {
      buf.write('טז');
    } else {
      const tens = ['', 'י', 'כ', 'ל', 'מ', 'נ', 'ס', 'ע', 'פ', 'צ'];
      buf.write(tens[rest ~/ 10]);
      if (rest % 10 > 0) buf.write(_hebrewLetters[rest % 10 - 1]);
    }
    final s = buf.toString();
    if (!punctuate) return s;
    if (s.length == 1) return '$s׳';
    return '${s.substring(0, s.length - 1)}״${s.substring(s.length - 1)}';
  }

  // The geresh and gershayim, and the quotation marks typed for them.
  static final _numeralMarks = RegExp('[׳״\'"`’‘”“]');

  static final _letterValues = {
    for (final (i, letter) in _hebrewLetters.split('').indexed)
      letter.codeUnitAt(0): switch (i) {
        < 9 => i + 1,
        < 18 => (i - 8) * 10,
        _ => (i - 17) * 100,
      },
  };

  /// Reads a number in Hebrew numerals, with or without a geresh or
  /// gershayim: כ״ח → 28, ט״ו → 15, ק׳ → 100.
  ///
  /// Only the form [gematria] writes counts, so that a word is not taken for
  /// a number: letters from the largest down, 15 and 16 as טו and טז (never
  /// יה and יו), and no final letters. Null for anything else, such as בא or
  /// לך.
  static int? parseGematria(String s) {
    final letters = s.trim().replaceAll(_numeralMarks, '');
    if (letters.isEmpty) return null;
    var n = 0;
    for (final unit in letters.codeUnits) {
      final value = _letterValues[unit];
      if (value == null) return null;
      n += value;
    }
    return gematria(n, punctuate: false) == letters ? n : null;
  }
}

/// How the Divine Name is rendered when text is spoken aloud.
enum DivineNameSpeech {
  /// "Adonai" (or "Elohim" where so vocalized), as in prayer and Torah reading.
  adonai,

  /// "HaShem", as commonly said outside of prayer.
  hashem,
}

/// Builds text for speech output (screen readers and text-to-speech).
abstract final class HebrewSpeech {
  static final _wordSplit = RegExp(r'(\s+|־)');
  // Vowel points, any number. Cantillation is gone before words are matched.
  static const _v = '[\u05b0-\u05bc\u05bf\u05c1\u05c2\u05c7]*';
  // Each pattern for the Divine Name matches a whole word in four parts:
  // the punctuation before it, any prefix letters with their vowels, the
  // Name as written, and the punctuation after it.
  static final _tetragrammaton =
      RegExp('^(?<lead>[^א-ת]*)(?<prefix>(?:[ובכלמשה]$_v){0,2})(?<name>י$_vה$_vו$_vה$_v)(?<after>[^א-ת]*)\$');
  // Onkelos writes the Name יְיָ, with a prefix where it has one (דַּיְיָ).
  static final _targumName =
      RegExp('^(?<lead>[^א-ת]*)(?<prefix>(?:[ודלבמכ]$_v)?)(?<name>י$_vי$_v)(?<after>[^א-ת]*)\$');
  // Rashi abbreviates it ה' (or with a geresh), also after one or two
  // prefix letters (לַה', שֶׁמֵּה', הלה'), the Aramaic ד (דַה'), quotation
  // marks (שֶׁ"ה'), and inside quotation marks or braces.
  static final _rashiName = RegExp(
    '^(?<lead>["״“„{\\[]*)(?<prefix>(?:[ובכלמשהד]$_v){0,2})["״“„]*(?<name>ה$_v[\'׳])(?<after>[.,:;!?)"״”}\\]]*)\$',
  );
  // But ה' is also the numeral 5. Rashi cites chapters by number, as in
  // (ישעיהו ה') or (שם ה', ד'), and counts with it: "כְּבֶן ה'" (five years
  // old), "ה' שָׁנִים" (five years), "וְה' מֵאוֹת" (five hundred). The nouns
  // are those Rashi on the Torah counts this way.
  static final _endsCitation = RegExp('[),:;]');
  static final _beforeCount = RegExp('^כ?ב[ןת]\$');
  static final _counted = RegExp('^(?:שנים|מאות|אלפים|מקומות|אברים)\$');

  /// Prepares one verse for speech: removes cantillation (screen readers
  /// mis-handle it) and the Masoretic dots, optionally removes vowels, and
  /// substitutes the Divine Name according to [divineName].
  ///
  /// Set [targum] for Targum Onkelos, which writes the Name יְיָ, and [rashi]
  /// for Rashi, who writes ה'.
  static String spoken(
    String text, {
    bool keepNikud = true,
    DivineNameSpeech divineName = DivineNameSpeech.adonai,
    bool targum = false,
    bool rashi = false,
  }) {
    // A sof pasuq ends a sentence: speak it as a full stop, always followed
    // by a space so the next word is never run into it. The extraordinary
    // points and the inverted nun are written, not read.
    final cleaned = HebrewText.stripTeamim(text)
        .replaceAll(HebrewText._masoraDots, '')
        .replaceAll('\u05c6', '')
        .replaceAll('׃', '. ');
    final parts = cleaned.split(_wordSplit);
    final seps = _wordSplit.allMatches(cleaned).map((m) => m.group(0)!).toList();
    final out = StringBuffer();
    var parens = 0;
    for (var i = 0; i < parts.length; i++) {
      final word = parts[i];
      final inParens = parens > 0 || word.contains('(');
      parens += '('.allMatches(word).length - ')'.allMatches(word).length;
      if (parens < 0) parens = 0;
      final m = _tetragrammaton.firstMatch(word) ??
          (targum ? _targumName.firstMatch(word) : null) ??
          (rashi ? _rashiName.firstMatch(word) : null);
      final numeral = m != null && m.pattern == _rashiName && _isNumeral(m, parts, i, inParens: inParens);
      out.write(m == null || numeral ? word : _substitute(m, divineName));
      if (i < seps.length) out.write(seps[i] == '־' ? ' ' : seps[i]);
    }
    final s = out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return keepNikud ? s : HebrewText.stripNikud(s);
  }

  /// Whether Rashi's ה' in words[i] is the numeral: closing a citation
  /// without a prefix, or counting what is next to it.
  static bool _isNumeral(RegExpMatch m, List<String> words, int i, {required bool inParens}) {
    if (inParens && m.namedGroup('prefix')!.isEmpty && _endsCitation.hasMatch(m.namedGroup('after')!)) return true;
    return (i > 0 && _beforeCount.hasMatch(_letters(words[i - 1]))) ||
        (i + 1 < words.length && _counted.hasMatch(_letters(words[i + 1])));
  }

  static String _letters(String word) => HebrewText.consonantsOnly(word).replaceAll(RegExp('[^א-ת]'), '');

  static String _substitute(RegExpMatch m, DivineNameSpeech mode) {
    final lead = m.namedGroup('lead')!;
    final prefix = m.namedGroup('prefix')!;
    final after = m.namedGroup('after')!;
    return switch (mode) {
      // A prefix keeps its vowels, set for this reading: לַיהוָה is read
      // לַאֲדֹנָי. Vocalized with a hiriq in the Name itself (יֱהֹוִה), it is
      // read "Elohim".
      DivineNameSpeech.adonai =>
        '$lead$prefix${m.namedGroup('name')!.contains('\u05b4') ? 'אֱלֹהִים' : 'אֲדֹנָי'}$after',
      DivineNameSpeech.hashem => '$lead${_hashemWithPrefix(_letters(prefix))}$after',
    };
  }

  /// "HaShem" after the prefix [letters], as Hebrew joins them: ל, ב and כ
  /// take the article's vowel and its ה drops (לַשֵּׁם, as in "Hodu
  /// laShem"); any other keeps it (וְהַשֵּׁם, מֵהַשֵּׁם, שֶׁהַשֵּׁם,
  /// and the Aramaic דְּהַשֵּׁם). The vowels written under a prefix were
  /// set for "Adonai", so they are not kept.
  static String _hashemWithPrefix(String letters) {
    if (letters.isEmpty) return 'הַשֵּׁם';
    final last = letters[letters.length - 1];
    if (letters.length == 1) {
      return switch (last) {
        'ל' => 'לַשֵּׁם',
        'ב' => 'בַּשֵּׁם',
        'כ' => 'כַּשֵּׁם',
        'ו' => 'וְהַשֵּׁם',
        'מ' => 'מֵהַשֵּׁם',
        'ש' => 'שֶׁהַשֵּׁם',
        'ד' => 'דְּהַשֵּׁם',
        _ => 'הַשֵּׁם',
      };
    }
    // Two letters. After ש or מ the next letter is doubled
    // (שֶׁבַּשֵּׁם); after any other, ב and כ are soft (וּבַשֵּׁם,
    // "uvaShem"). ו is וּ before ב or מ, and an interrogative ה is הֲ
    // (הֲלַשֵּׁם).
    final first = letters[0];
    final doubled = first == 'ש' || first == 'מ';
    final joined = switch (last) {
      'ל' => doubled ? 'לַּשֵּׁם' : 'לַשֵּׁם',
      'ב' => doubled ? 'בַּשֵּׁם' : 'בַשֵּׁם',
      'כ' => doubled ? 'כַּשֵּׁם' : 'כַשֵּׁם',
      'ו' => 'וְהַשֵּׁם',
      'מ' => doubled ? 'מֵּהַשֵּׁם' : 'מֵהַשֵּׁם',
      'ש' => doubled ? 'שֶּׁהַשֵּׁם' : 'שֶׁהַשֵּׁם',
      'ד' => 'דְּהַשֵּׁם',
      _ => 'הַשֵּׁם',
    };
    final lead = switch (first) {
      'ו' => last == 'ב' || last == 'מ' ? 'וּ' : 'וְ',
      'ש' => 'שֶׁ',
      'מ' => 'מִ',
      'ה' => 'הֲ',
      'ד' => 'דְּ',
      'כ' => 'כְּ',
      'ל' => 'לְ',
      'ב' => 'בְּ',
      _ => first,
    };
    return '$lead$joined';
  }
}
