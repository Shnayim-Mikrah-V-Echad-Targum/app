/// Utilities for pointed (nikud) and cantillated (ta'amim) Hebrew text.
///
/// Unicode reference: the Hebrew block U+0590–U+05FF.
///  * U+0591–U+05AF  cantillation marks (ta'amim)
///  * U+05BD         meteg (a stress/secondary accent mark)
///  * U+05C0         paseq / legarmeih stroke
///  * U+05C4–U+05C5  upper / lower Masoretic dots
///  * U+05B0–U+05BC, U+05BF, U+05C1–U+05C2, U+05C7  vowel points, dagesh,
///                   rafe, shin/sin dots, qamatz qatan
///  * U+034F         combining grapheme joiner, used to order marks
abstract final class HebrewText {
  static final _teamim = RegExp('[֑-ֽׅ֯ׄ]');
  static final _nikud = RegExp('[ְ-ׇּֿׁׂ]');
  static final _cgj = RegExp('͏');
  // A paseq with the spaces around it collapses to a single space.
  static final _paseq = RegExp(r'\s*׀\s*');
  static final _spaces = RegExp(r'[  ]{2,}');

  /// Removes cantillation marks, meteg and the paseq stroke.
  static String stripTeamim(String s) => s
      .replaceAll(_paseq, ' ')
      .replaceAll(_teamim, '')
      .replaceAll(_cgj, '')
      .replaceAll(_spaces, ' ');

  /// Removes vowel points (and dagesh, shin/sin dots).
  static String stripNikud(String s) =>
      s.replaceAll(_nikud, '').replaceAll(_cgj, '');

  /// Removes every mark, leaving only letters and punctuation.
  static String consonantsOnly(String s) => stripNikud(stripTeamim(s));

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
  static final _tetragrammaton = RegExp('^([ובכלמשה]?)יהוה\$');

  /// Prepares one verse for speech: removes cantillation (screen readers
  /// mis-handle it), optionally removes vowels, and substitutes the Divine
  /// Name according to [divineName].
  static String spoken(
    String text, {
    bool keepNikud = true,
    DivineNameSpeech divineName = DivineNameSpeech.adonai,
  }) {
    // A sof pasuq ends a sentence: speak it as a full stop, always followed
    // by a space so the next word is never run into it.
    final cleaned = HebrewText.stripTeamim(text).replaceAll('׃', '. ');
    final parts = cleaned.split(_wordSplit);
    final seps = _wordSplit.allMatches(cleaned).map((m) => m.group(0)!).toList();
    final out = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      out.write(_substituteName(parts[i], divineName));
      if (i < seps.length) out.write(seps[i] == '־' ? ' ' : seps[i]);
    }
    final s = out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return keepNikud ? s : HebrewText.stripNikud(s);
  }

  static String _substituteName(String word, DivineNameSpeech mode) {
    final bare = HebrewText.consonantsOnly(word).replaceAll(RegExp('[^א-ת]'), '');
    final m = _tetragrammaton.firstMatch(bare);
    if (m == null) return word;
    final prefix = m.group(1)!;
    // Vocalized with a hiriq in the Name itself (יֱהֹוִה) it is read "Elohim".
    final nameStart = word.indexOf('י', prefix.isEmpty ? 0 : word.indexOf(prefix) + 1);
    final readAsElohim = nameStart >= 0 && word.substring(nameStart).contains('ִ');
    switch (mode) {
      case DivineNameSpeech.adonai:
        return '$prefix${readAsElohim ? 'אֱלֹהִים' : 'אֲדֹנָי'}';
      case DivineNameSpeech.hashem:
        return '$prefixהַשֵּׁם';
    }
  }
}
