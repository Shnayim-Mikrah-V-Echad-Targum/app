import 'hebrew_pronunciation.dart';

/// Pointed Hebrew, and the Aramaic of Targum Onkelos, as the sounds a voice
/// speaks: IPA in the schema of Phonikud (https://phonikud.github.io, CC BY
/// 4.0), whose rules for modern Hebrew these follow, and on which the
/// built-in Hebrew voice was trained (HebrewVoice).
///
/// The Masoretic text says more than modern Hebrew writes, and this reads it:
///  * the stress, from the cantillation: the accent stands on the stressed
///    syllable, but for the accents written before or after the word whatever
///    its stress (pashta, zarqa, segolta, telisha, yetiv, dehi), and the
///    silluq of a verse's last word, which shares its sign with the meteg;
///    a word with none (one joined to the next by a maqaf, or the Targum,
///    which has no accents) is stressed on its last syllable;
///  * a vocal shva: at the start of a word (after the conjunction וּ too),
///    after a silent shva, under a doubled letter (a strong dagesh), before
///    the same letter again, or after a long vowel or hiriq with a meteg
///    (וַאֲבָֽרְכָה, but וַֽיְהִי); any
///    other is silent, as modern Hebrew reads it, but for the ה, א and ע it
///    is under, which are sounded (וֶהְיֵה, נַעְשֶׂה);
///  * a qamatz qatan, where the text marks it (ׇ), and before a hataf qamatz;
///  * a pause after the great dividing accents (etnachta, segolta, zaqef), a
///    paseq, and the end of a verse.
///
/// The vowels on which the reading traditions differ, and the stress, are
/// said as [HebrewPronunciation] sets them: as Israel reads, by default.
///
/// Text without vowels has no reading here: [isPointed] says whether a text
/// has enough of them.
abstract final class HebrewPhonemes {
  static const _stress = 'ˈ';

  /// Whether [text] is pointed throughout, as the Torah and the Targum are,
  /// rather than mostly bare letters, as Rashi is.
  static bool isPointed(String text) {
    var letters = 0;
    var pointed = 0;
    String? last;
    for (final rune in text.runes) {
      final c = String.fromCharCode(rune);
      if (_isLetter(rune)) {
        letters++;
        last = c;
      } else if (last != null && _isVowel(rune)) {
        pointed++;
        last = null;
      }
    }
    return letters > 0 && pointed / letters > 0.5;
  }

  /// The sounds of [text], one verse or line: words, with the stress before
  /// its vowel, separated by spaces, and the pauses as commas and full stops:
  /// at the end of a verse, and with [pauses], at its dividing accents and a
  /// paseq too.
  static String phonemize(String text, {HebrewPronunciation pronunciation = HebrewPronunciation.israeli, bool pauses = true}) {
    final tokens = _tokens(text);
    final out = StringBuffer();
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      switch (t) {
        case _Word():
          // The last word of a verse: its meteg sign is the silluq, its stress.
          final endsVerse = tokens.skip(i + 1).whereType<_Word>().isEmpty && tokens.skip(i + 1).any((t) => t is _Pause && t.endsVerse);
          final sounds = _word(t.letters, endsVerse: endsVerse, p: pronunciation);
          if (sounds.isEmpty) continue;
          if (out.isNotEmpty && !_endsWithSpace(out)) out.write(' ');
          out.write(sounds);
          if (t.pauseAfter && pauses) out.write(',');
        case _Pause():
          final s = out.toString();
          if (s.isEmpty || (!t.endsVerse && !pauses)) continue;
          final mark = t.endsVerse ? '.' : ',';
          // One pause, the stronger, where two meet.
          if (s.endsWith(',') || s.endsWith('.')) {
            if (mark == '.') {
              out.clear();
              out.write('${s.substring(0, s.length - 1)}.');
            }
          } else {
            out.write(mark);
          }
      }
    }
    return out.toString().trim();
  }

  static bool _endsWithSpace(StringBuffer b) => b.toString().endsWith(' ');

  // --- Reading the text ----------------------------------------------------

  static bool _isLetter(int c) => c >= 0x05D0 && c <= 0x05EA;
  static bool _isVowel(int c) => (c >= 0x05B0 && c <= 0x05BB) || c == 0x05C7;
  static bool _isMark(int c) =>
      (c >= 0x0591 && c <= 0x05BD) || c == 0x05BF || c == 0x05C1 || c == 0x05C2 || (c >= 0x05C4 && c <= 0x05C5) || c == 0x05C7 || c == 0x034F;

  // Accents written on the first or last letter whatever the stress.
  static const _prepositive = {0x05A0, 0x059A, 0x05AD}; // telisha gedola, yetiv, dehi
  static const _postpositive = {0x0592, 0x0599, 0x05A9, 0x05AE}; // segolta, pashta, telisha qetana, zarqa
  // Accents after which the reading pauses.
  static const _pausing = {0x0591, 0x0592, 0x0594, 0x0595}; // etnachta, segolta, zaqef qatan and gadol
  static const _meteg = 0x05BD;
  static final _tetragrammaton = RegExp(r'^([ובכלמשה]{0,2})יהוה$');
  static final _targumName = RegExp(r'^([ודלבמכ]?)יי$');

  static List<_Token> _tokens(String text) {
    final tokens = <_Token>[];
    var letters = <_Letter>[];
    void endWord() {
      if (letters.isEmpty) return;
      final pause = letters.any((l) => l.marks.any(_pausing.contains));
      tokens.add(_Word(letters, pauseAfter: pause));
      letters = <_Letter>[];
    }

    for (final rune in text.runes) {
      if (_isLetter(rune)) {
        letters.add(_Letter(rune));
      } else if (_isMark(rune)) {
        if (letters.isNotEmpty) letters.last.marks.add(rune);
      } else if (rune == 0x05F3 || rune == 0x05F4 || rune == 0x27 || rune == 0x22) {
        // A geresh or gershayim belongs to the word.
        if (letters.isNotEmpty) letters.last.geresh = true;
      } else {
        endWord();
        switch (rune) {
          case 0x05C3 || 0x2E || 0x21 || 0x3F: // sof pasuq, . ! ?
            tokens.add(_Pause(endsVerse: true));
          case 0x05C0 || 0x2C || 0x3A || 0x3B: // paseq , : ;
            tokens.add(_Pause(endsVerse: false));
        }
      }
    }
    endWord();
    return tokens;
  }

  // --- One word ------------------------------------------------------------

  static String _word(List<_Letter> letters, {required bool endsVerse, required HebrewPronunciation p}) {
    final n = letters.length;
    if (n == 0) return '';
    // The Divine Name is never voiced as written, should it come here so:
    // read Adonai, after any prefix (HebrewSpeech substitutes it first, as
    // the reader chooses).
    final bare = letters.map((l) => l.char).join();
    final name = _tetragrammaton.firstMatch(bare) ?? _targumName.firstMatch(bare);
    if (name != null) {
      final prefix = name.group(1)!.length;
      // Adonai's holam and qamatz as the reader says them, stressed on the
      // last syllable, or with the penultimate rule on the one before.
      final adonai = p.stress == StressRule.penultimate ? 'ʔadˈ${p.holam.sound}n${p.qamatz.sound}j' : 'ʔad${p.holam.sound}nˈ${p.qamatz.sound}j';
      return '${prefix == 0 ? '' : _word(letters.sublist(0, prefix), endsVerse: false, p: p).replaceAll(_stress, '')}$adonai';
    }
    // The letter whose syllable is stressed, if the accents say.
    int? stressed;
    for (var i = 0; i < n; i++) {
      for (final m in letters[i].marks) {
        if (m >= 0x0591 && m <= 0x05AE && !_prepositive.contains(m) && !_postpositive.contains(m)) stressed = i;
      }
    }
    // A pashta written twice: the first stands on the stressed letter.
    if (stressed == null) {
      final pashta = [for (var i = 0; i < n; i++) if (letters[i].marks.contains(0x0599)) i];
      if (pashta.length > 1) stressed = pashta.first;
    }
    if (stressed == null && endsVerse) {
      for (var i = n - 1; i >= 0; i--) {
        if (letters[i].marks.contains(_meteg)) {
          stressed = i;
          break;
        }
      }
    }

    final sounds = <_Sound>[];
    final silentShva = List<bool>.filled(n, false);
    for (var i = 0; i < n; i++) {
      final cur = letters[i];
      final prev = i > 0 ? letters[i - 1] : null;
      final next = i + 1 < n ? letters[i + 1] : null;
      final last = i == n - 1;
      final c = cur.char;

      // The vowels on the letter, in order (a patah and a hiriq on the lamed
      // of Jerusalem, יְרוּשָׁלַ͏ִם, are "ajim").
      final vowels = <String>[];
      for (final m in cur.marks) {
        final v = _vowel(m, cur, next, p);
        if (v != null) vowels.add(v);
      }

      // Shva: vocal or silent.
      var vocalShva = false;
      if (cur.has(0x05B0) && vowels.isEmpty) {
        vocalShva = !last &&
            (i == 0 ||
                // After the conjunction וּ, still the start of the word.
                (i == 1 && prev!.char == 'ו' && prev.has(0x05BC)) ||
                (prev != null && silentShva[i - 1]) ||
                _strongDagesh(cur, prev) ||
                (next != null && _same(c, next.char)) ||
                // A meteg (ga'ya) on a long vowel before it, or a hiriq, marks
                // the syllable open; on a short one (וַֽיְהִי) it doesn't.
                (prev != null && prev.has(_meteg) && _longOrHiriq(prev)));
        if (!vocalShva) silentShva[i] = true;
      }

      String consonant = '';
      var vowel = vowels.join('j');
      var vowelBefore = false; // a furtive patah, read before its letter

      // A letter whose vowel is the vowel letter after it: תֹהוּ, תְהוֹם.
      final voicedByNext = next != null && vowels.isEmpty && !cur.has(0x05B0) && _isVowelLetter(next, cur);
      switch (c) {
        case 'א' || 'ע':
          // Under a silent shva within the word too (נַעְשֶׂה): the stop.
          if (vowel.isNotEmpty || vocalShva || voicedByNext || (cur.has(0x05B0) && !last)) consonant = 'ʔ';
        case 'ה':
          if (cur.has(0x05BC) || vowel.isNotEmpty || vocalShva || voicedByNext || (cur.has(0x05B0) && !last)) consonant = 'h';
        case 'ו':
          if (cur.has(0x05BC) && vowels.isEmpty && !cur.has(0x05B0)) {
            // Shuruk: the vowel u, or a doubled v with no vowel of its own.
            if (prev == null || !_hasVowelSound(prev) || prev.char == 'ו') {
              vowel = p.shuruk.sound;
            } else {
              consonant = 'v';
            }
          } else if (prev != null && _isVowelLetter(cur, prev)) {
            // Holam male: the o of the letter before.
            vowel = p.holam.sound;
          } else if (vowels.isNotEmpty || vocalShva || cur.has(0x05BC)) {
            consonant = 'v';
          } else if (last) {
            // -ָיו, as in דְּבָרָיו: "av".
            consonant = 'v';
          }
        case 'י':
          if (vowels.isNotEmpty || cur.has(0x05BC) || vocalShva || cur.has(0x05B0)) {
            consonant = 'j';
          } else if (prev != null && (prev.has(0x05B4) || prev.has(0x05B5) || prev.has(0x05B6))) {
            // A vowel letter after i or e.
          } else if (next != null && next.char == 'ו' && next.marks.isEmpty && i + 2 == n) {
            // -ָיו: the yod is silent.
          } else if (prev != null) {
            consonant = 'j';
          }
        case 'ש':
          if (cur.marks.isEmpty && prev != null && prev.char == 'ש') {
            // יִשָּׂשכָר: the second shin is not read.
          } else {
            consonant = cur.has(0x05C2) ? 's' : 'ʃ';
          }
        default:
          consonant = _consonant(cur, p);
      }

      // A patah under a final ח, ע or הּ is read before it.
      if (last && cur.has(0x05B7) && (c == 'ח' || c == 'ע' || (c == 'ה' && cur.has(0x05BC))) && prev != null) {
        vowelBefore = true;
        if (c == 'ע') consonant = '';
      }
      if (vocalShva && vowel.isEmpty) vowel = 'e';
      sounds.add(_Sound(consonant, vowel, vowelBefore: vowelBefore, fromShva: vocalShva && vowels.isEmpty));
    }

    // The stress: before the vowel of the stressed letter, or the next full
    // vowel after it; or, unsaid, the last syllable's (not a furtive patah's).
    int? target;
    if (stressed != null && p.stress == StressRule.accents) {
      for (var i = stressed; i < n; i++) {
        if (sounds[i].vowel.isNotEmpty && !sounds[i].fromShva) {
          target = i;
          break;
        }
      }
    }
    if (target == null) {
      final full = [for (var i = 0; i < n; i++) if (sounds[i].vowel.isNotEmpty && !sounds[i].fromShva && !sounds[i].vowelBefore) i];
      if (full.isNotEmpty && p.stress == StressRule.penultimate) {
        target = full.length > 1 ? full[full.length - 2] : full.last;
      } else if (full.isNotEmpty) {
        target = full.last;
        // The dual's -ayim (שָׁמַיִם, צָהֳרַיִם) is stressed before its yod.
        final yod = full.last;
        if (full.length > 1 && letters[yod].char == 'י' && letters[yod].has(0x05B4) && yod == n - 2) target = full[full.length - 2];
      }
    }
    final out = StringBuffer();
    for (var i = 0; i < n; i++) {
      final s = sounds[i];
      final v = i == target ? '$_stress${s.vowel}' : s.vowel;
      out.write(s.vowelBefore ? '$v${s.consonant}' : '${s.consonant}$v');
    }
    return out.toString();
  }

  /// The vowel [mark] sounds on [cur], as [p] says it, or null for any other
  /// mark.
  static String? _vowel(int mark, _Letter cur, _Letter? next, HebrewPronunciation p) => switch (mark) {
        0x05B4 => 'i',
        0x05B5 => p.tsere.sound,
        0x05B6 || 0x05B1 => 'e',
        0x05B7 || 0x05B2 => 'a',
        // A qamatz before a hataf qamatz is a qamatz qatan (צָהֳרַיִם).
        0x05B8 => next != null && next.has(0x05B3) ? 'o' : p.qamatz.sound,
        0x05B9 || 0x05BA => p.holam.sound,
        0x05B3 || 0x05C7 => 'o',
        0x05BB => p.shuruk.sound,
        _ => null,
      };

  static String _consonant(_Letter l, HebrewPronunciation p) {
    final hard = l.has(0x05BC);
    return switch (l.char) {
      'ב' => hard ? 'b' : 'v',
      'כ' || 'ך' => hard ? 'k' : 'χ',
      'פ' || 'ף' => hard ? 'p' : 'f',
      'ג' => l.geresh ? 'dʒ' : 'ɡ',
      'ד' => 'd',
      'ז' => l.geresh ? 'ʒ' : 'z',
      'ח' => 'χ',
      'ט' => 't',
      'ת' => hard ? 't' : p.tavRafe.sound,
      'ל' => 'l',
      'מ' || 'ם' => 'm',
      'נ' || 'ן' => 'n',
      'ס' => 's',
      'צ' || 'ץ' => l.geresh ? 'tʃ' : 'ts',
      'ק' => 'k',
      'ר' => 'ʁ',
      _ => '',
    };
  }

  /// Whether [l] is a ו that is the vowel of [before]: a shuruk, or a holam
  /// male after a letter with no vowel of its own (שָׁלוֹם, but מִצְוֹת).
  static bool _isVowelLetter(_Letter l, _Letter before) {
    if (l.char != 'ו') return false;
    final own = l.marks.where((m) => _isVowel(m) && m != 0x05B9).isNotEmpty;
    if (own) return false;
    if (l.has(0x05BC) && !l.has(0x05B9)) return !_hasVowelSound(before) || before.char == 'ו';
    return l.has(0x05B9) && !_hasVowelSound(before) && !before.has(0x05B0);
  }

  /// Whether [l] has a full vowel, or is a vowel letter carrying one (a
  /// shuruk or holam male).
  static bool _hasVowelSound(_Letter l) => l.marks.any((m) => _isVowel(m) && m != 0x05B0) || (l.char == 'ו' && l.has(0x05BC));

  /// Whether [l] has a long vowel (qamatz gadol, tsere, holam, a shuruk) or
  /// a hiriq.
  static bool _longOrHiriq(_Letter l) =>
      l.has(0x05B8) || l.has(0x05B5) || l.has(0x05B9) || l.has(0x05BA) || l.has(0x05B4) || (l.char == 'ו' && l.has(0x05BC));

  /// A dagesh that doubles its letter: on one of בגדכפת after a vowel, or on
  /// any other letter but a mappiq's ה and a shuruk's ו.
  static bool _strongDagesh(_Letter l, _Letter? prev) {
    if (!l.has(0x05BC) || prev == null) return false;
    if ('בגדכפתךף'.contains(l.char)) return _hasVowelSound(prev);
    return l.char != 'ה' && l.char != 'ו';
  }

  static bool _same(String a, String b) => _plain(a) == _plain(b);
  static String _plain(String c) => switch (c) { 'ך' => 'כ', 'ם' => 'מ', 'ן' => 'נ', 'ף' => 'פ', 'ץ' => 'צ', _ => c };
}

sealed class _Token {}

class _Word extends _Token {
  _Word(this.letters, {required this.pauseAfter});
  final List<_Letter> letters;
  final bool pauseAfter;
}

class _Pause extends _Token {
  _Pause({required this.endsVerse});
  final bool endsVerse;
}

class _Letter {
  _Letter(int rune) : char = String.fromCharCode(rune);
  final String char;
  final List<int> marks = [];
  bool geresh = false;
  bool has(int mark) => marks.contains(mark);
}

class _Sound {
  _Sound(this.consonant, this.vowel, {required this.vowelBefore, required this.fromShva});
  final String consonant;
  final String vowel;
  final bool vowelBefore;
  final bool fromShva;
}
