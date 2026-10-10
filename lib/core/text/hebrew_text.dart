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
  // Each pattern for the Divine Name matches a whole word in three parts:
  // what precedes the Name (punctuation, then any prefix letters with their
  // vowels), the Name as written, and the punctuation after it.
  static final _tetragrammaton =
      RegExp('^(?<before>[^א-ת]*(?:[ובכלמשה]$_v){0,2})(?<name>י$_vה$_vו$_vה$_v)(?<after>[^א-ת]*)\$');
  // Onkelos writes the Name יְיָ, with a prefix where it has one (דַּיְיָ).
  static final _targumName =
      RegExp('^(?<before>[^א-ת]*(?:[ודלבמכ]$_v)?)(?<name>י$_vי$_v)(?<after>[^א-ת]*)\$');
  // Rashi abbreviates it ה' (or with a geresh), also after a prefix (לַה')
  // and inside quotation marks or braces.
  static final _rashiName = RegExp(
    '^(?<before>["״“„{\\[]*(?<prefix>(?:[ובכלמש]$_v)?))(?<name>ה$_v[\'׳])(?<after>[.,:;!?)"״”}\\]]*)\$',
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
    final name = switch (mode) {
      // Vocalized with a hiriq in the Name itself (יֱהֹוִה) it is read "Elohim".
      DivineNameSpeech.adonai => m.namedGroup('name')!.contains('\u05b4') ? 'אֱלֹהִים' : 'אֲדֹנָי',
      DivineNameSpeech.hashem => 'הַשֵּׁם',
    };
    // What precedes the Name is kept as written, so a prefix keeps its
    // vowels: לַיהוָה is read לַאֲדֹנָי.
    return '${m.namedGroup('before')}$name${m.namedGroup('after')}';
  }
}
