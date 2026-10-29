import '../../core/text/hebrew_pronunciation.dart';
import 'voice_catalogue.dart';

/// What an utterance of Listen is, for the voice the reader chose for it.
enum SpeechRole {
  /// The Torah, and anything else that isn't the Targum or the haftarah.
  mikrah,
  targum,
  haftarah,
}

/// Which voice reads what, how it says the text, and how it sounds
/// (Settings, Accessibility, Hebrew voice). Every choice has a default,
/// the best the app's tests found, and every one is the reader's to change.
class VoiceSettings {
  const VoiceSettings({
    this.torah = kDefaultHebrewVoice,
    this.targum,
    this.haftarah,
    this.pronunciation = HebrewPronunciation.israeli,
    this.pauses = true,
    this.variation,
    this.rhythm,
    this.steps = defaultSteps,
    this.guidance = defaultGuidance,
    this.evenLoudness = true,
  });

  /// In place of a voice's id: the device's own voice.
  static const deviceVoice = 'device';
  static const defaultSteps = 8;
  static const defaultGuidance = 3.0;

  /// The voice that reads the Torah: a voice's id ([hebrewVoices]), or
  /// [deviceVoice]. While the voice chosen isn't on the device, the clearest
  /// that is reads in its place, and with none, the device's.
  final String torah;

  /// The voice that reads Targum Onkelos; null for the Torah's.
  final String? targum;

  /// The voice that reads the haftarah; null for the Torah's.
  final String? haftarah;

  /// How the vowels on which the traditions differ, and the stress, are said.
  final HebrewPronunciation pronunciation;

  /// Whether the voice pauses at the great dividing accents and a paseq, as
  /// well as at the end of a verse.
  final bool pauses;

  /// A Piper voice's variation of sound, 0 to 1; null for each voice's own.
  final double? variation;

  /// A Piper voice's variation of timing, 0 to 1.5; null for each voice's own.
  final double? rhythm;

  /// A Blue voice's steps from noise to speech, 2 to 32.
  final int steps;

  /// How closely a Blue voice keeps to the text, 1 to 5.
  final double guidance;

  /// Whether each utterance is brought to the same loudness, as the voices
  /// differ, and some speak softly.
  final bool evenLoudness;

  /// The voice chosen for [role].
  String voiceFor(SpeechRole role) => switch (role) {
        SpeechRole.mikrah => torah,
        SpeechRole.targum => targum ?? torah,
        SpeechRole.haftarah => haftarah ?? torah,
      };

  /// These settings with [role] read by [voice]; for the Targum and the
  /// haftarah, null for the Torah's.
  VoiceSettings withVoice(SpeechRole role, String? voice) => switch (role) {
        SpeechRole.mikrah => copyWith(torah: voice ?? kDefaultHebrewVoice),
        SpeechRole.targum => copyWith(targum: () => voice),
        SpeechRole.haftarah => copyWith(haftarah: () => voice),
      };

  /// [targum], [haftarah], [variation] and [rhythm] take a function, so that
  /// they can be set to null.
  VoiceSettings copyWith({
    String? torah,
    String? Function()? targum,
    String? Function()? haftarah,
    HebrewPronunciation? pronunciation,
    bool? pauses,
    double? Function()? variation,
    double? Function()? rhythm,
    int? steps,
    double? guidance,
    bool? evenLoudness,
  }) =>
      VoiceSettings(
        torah: torah ?? this.torah,
        targum: targum == null ? this.targum : targum(),
        haftarah: haftarah == null ? this.haftarah : haftarah(),
        pronunciation: pronunciation ?? this.pronunciation,
        pauses: pauses ?? this.pauses,
        variation: variation == null ? this.variation : variation(),
        rhythm: rhythm == null ? this.rhythm : rhythm(),
        steps: steps ?? this.steps,
        guidance: guidance ?? this.guidance,
        evenLoudness: evenLoudness ?? this.evenLoudness,
      );

  Map<String, dynamic> toJson() => {
        'torah': torah,
        'targum': targum,
        'haftarah': haftarah,
        'pronunciation': pronunciation.toJson(),
        'pauses': pauses,
        'variation': variation,
        'rhythm': rhythm,
        'steps': steps,
        'guidance': guidance,
        'evenLoudness': evenLoudness,
      };

  factory VoiceSettings.fromJson(Object? j) {
    if (j is! Map) return const VoiceSettings();
    String? voice(Object? v) => v is String && (v == deviceVoice || hebrewVoiceById(v) != null) ? v : null;
    double? number(Object? v, double min, double max) => v is num ? v.toDouble().clamp(min, max) : null;
    return VoiceSettings(
      torah: voice(j['torah']) ?? kDefaultHebrewVoice,
      targum: voice(j['targum']),
      haftarah: voice(j['haftarah']),
      pronunciation: HebrewPronunciation.fromJson(j['pronunciation']),
      pauses: j['pauses'] is bool ? j['pauses'] as bool : true,
      variation: number(j['variation'], 0, 1),
      rhythm: number(j['rhythm'], 0, 1.5),
      steps: (number(j['steps'], 2, 32) ?? defaultSteps).round(),
      guidance: number(j['guidance'], 1, 5) ?? defaultGuidance,
      evenLoudness: j['evenLoudness'] is bool ? j['evenLoudness'] as bool : true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VoiceSettings &&
      other.torah == torah &&
      other.targum == targum &&
      other.haftarah == haftarah &&
      other.pronunciation == pronunciation &&
      other.pauses == pauses &&
      other.variation == variation &&
      other.rhythm == rhythm &&
      other.steps == steps &&
      other.guidance == guidance &&
      other.evenLoudness == evenLoudness;

  @override
  int get hashCode => Object.hash(torah, targum, haftarah, pronunciation, pauses, variation, rhythm, steps, guidance, evenLoudness);
}
