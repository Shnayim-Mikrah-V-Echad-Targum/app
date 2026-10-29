/// How the app's own Hebrew voice says the vowels and letters on which the
/// reading traditions differ (HebrewPhonemes): the qamatz, the holam, the
/// tsere, the shuruk and qubbutz, a tav without a dagesh, and where the
/// stress falls. Each is the reader's to set; [HebrewPronunciationPreset]
/// sets the sounds as a tradition says them, and leaves the stress, which is
/// the accents' wherever the Torah is read with them, to be set apart.
///
/// Only sounds the voices were trained on are offered: the Yemenite ח, ע, ג
/// and ד, and the Sephardi ח and ע, need sounds that none of them makes.
class HebrewPronunciation {
  const HebrewPronunciation({
    this.qamatz = QamatzSound.a,
    this.holam = HolamSound.o,
    this.tsere = TsereSound.e,
    this.shuruk = ShurukSound.u,
    this.tavRafe = TavRafeSound.t,
    this.stress = StressRule.accents,
  });

  /// A qamatz gadol: "a" in Israeli and Sephardi Hebrew, "o" for the
  /// Lithuanians and Yekkes, "u" in Poland and Galicia. A qamatz qatan and a
  /// hataf qamatz are always "o".
  final QamatzSound qamatz;

  /// A holam, written or full (ֹ, וֹ).
  final HolamSound holam;

  /// A tsere (ֵ); a segol is always "e".
  final TsereSound tsere;

  /// A shuruk (וּ) and a qubbutz (ֻ).
  final ShurukSound shuruk;

  /// A tav without a dagesh: "t", or the Ashkenazi "s" (sav).
  final TavRafeSound tavRafe;

  /// Where a word is stressed.
  final StressRule stress;

  static const israeli = HebrewPronunciation();

  /// The preset whose sounds these are, whatever the stress; null if set
  /// by hand.
  HebrewPronunciationPreset? get preset {
    for (final p in HebrewPronunciationPreset.values) {
      if (p.pronunciation.copyWith(stress: stress) == this) return p;
    }
    return null;
  }

  /// [preset]'s sounds, with this stress.
  HebrewPronunciation withPreset(HebrewPronunciationPreset preset) => preset.pronunciation.copyWith(stress: stress);

  HebrewPronunciation copyWith({
    QamatzSound? qamatz,
    HolamSound? holam,
    TsereSound? tsere,
    ShurukSound? shuruk,
    TavRafeSound? tavRafe,
    StressRule? stress,
  }) =>
      HebrewPronunciation(
        qamatz: qamatz ?? this.qamatz,
        holam: holam ?? this.holam,
        tsere: tsere ?? this.tsere,
        shuruk: shuruk ?? this.shuruk,
        tavRafe: tavRafe ?? this.tavRafe,
        stress: stress ?? this.stress,
      );

  Map<String, dynamic> toJson() => {
        'qamatz': qamatz.name,
        'holam': holam.name,
        'tsere': tsere.name,
        'shuruk': shuruk.name,
        'tavRafe': tavRafe.name,
        'stress': stress.name,
      };

  factory HebrewPronunciation.fromJson(Object? j) {
    if (j is! Map) return israeli;
    T e<T extends Enum>(List<T> values, Object? name, T fallback) => values.where((v) => v.name == name).firstOrNull ?? fallback;
    return HebrewPronunciation(
      qamatz: e(QamatzSound.values, j['qamatz'], QamatzSound.a),
      holam: e(HolamSound.values, j['holam'], HolamSound.o),
      tsere: e(TsereSound.values, j['tsere'], TsereSound.e),
      shuruk: e(ShurukSound.values, j['shuruk'], ShurukSound.u),
      tavRafe: e(TavRafeSound.values, j['tavRafe'], TavRafeSound.t),
      stress: e(StressRule.values, j['stress'], StressRule.accents),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HebrewPronunciation &&
      other.qamatz == qamatz &&
      other.holam == holam &&
      other.tsere == tsere &&
      other.shuruk == shuruk &&
      other.tavRafe == tavRafe &&
      other.stress == stress;

  @override
  int get hashCode => Object.hash(qamatz, holam, tsere, shuruk, tavRafe, stress);
}

/// The reading traditions the voice can follow, each a set of the sounds of
/// [HebrewPronunciation].
enum HebrewPronunciationPreset {
  /// As Israel reads, which is the Sephardi reading too but for ח and ע.
  israeli(HebrewPronunciation()),

  /// Lithuanian (Litvish): bOrukh, kohein, Shabbos.
  lithuanian(HebrewPronunciation(
    qamatz: QamatzSound.o,
    holam: HolamSound.ej,
    tsere: TsereSound.ej,
    tavRafe: TavRafeSound.s,
  )),

  /// Polish and Galician (Chassidish): bUrikh, koyhain, Shabbos.
  polish(HebrewPronunciation(
    qamatz: QamatzSound.u,
    holam: HolamSound.oj,
    tsere: TsereSound.aj,
    shuruk: ShurukSound.i,
    tavRafe: TavRafeSound.s,
  )),

  /// Hungarian (Oberlander): bOrukh, koyhein.
  hungarian(HebrewPronunciation(
    qamatz: QamatzSound.o,
    holam: HolamSound.oj,
    tsere: TsereSound.ej,
    tavRafe: TavRafeSound.s,
  )),

  /// German (Yekkish): bOrukh, kouhein.
  german(HebrewPronunciation(
    qamatz: QamatzSound.o,
    holam: HolamSound.ou,
    tsere: TsereSound.ej,
    tavRafe: TavRafeSound.s,
  ));

  const HebrewPronunciationPreset(this.pronunciation);
  final HebrewPronunciation pronunciation;
}

enum QamatzSound {
  a('a'),
  o('o'),
  u('u');

  const QamatzSound(this.sound);
  final String sound;
}

enum HolamSound {
  o('o'),
  oj('oj'),
  ej('ej'),
  ou('ou'),
  au('au');

  const HolamSound(this.sound);
  final String sound;
}

enum TsereSound {
  e('e'),
  ej('ej'),
  aj('aj');

  const TsereSound(this.sound);
  final String sound;
}

enum ShurukSound {
  u('u'),
  i('i');

  const ShurukSound(this.sound);
  final String sound;
}

enum TavRafeSound {
  t('t'),
  s('s');

  const TavRafeSound(this.sound);
  final String sound;
}

/// Where a word's stress falls.
enum StressRule {
  /// Where its accent stands (the Masoretic stress), as the Torah is read.
  accents,

  /// On the syllable before the last, as many Ashkenazim read; a word of
  /// one syllable on that one.
  penultimate,
}
