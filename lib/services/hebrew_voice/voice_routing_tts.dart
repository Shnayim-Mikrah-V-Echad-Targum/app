import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/text/hebrew_phonemes.dart';
import '../../core/text/hebrew_text.dart';
import '../tts.dart';
import 'hebrew_voice.dart';
import 'voice_settings.dart';

/// The speech engine TtsService speaks through: the device's own, but for
/// pointed Hebrew and Aramaic once one of the app's voices is on the device
/// ([HebrewVoices]), which reads it here and plays it, reporting its start,
/// end and stop as the device's engine would, so that the service, its queue
/// and its audio session are the same whichever voice reads.
///
/// Each utterance is read by the voice the reader chose for its [role]
/// (VoiceSettings): while that voice isn't on the device, by the clearest
/// one that is; with none, or if the reader chose the device's, by the
/// device's. The Hebrew comes with its cantillation, for the stress
/// (HebrewSpeech.spoken, keepTeamim): it is removed for the device's voices,
/// which mis-read it. Unpointed Hebrew (Rashi), and every other language,
/// are the device's to read; and should the app's voice fail, the device's
/// reads in its place.
class VoiceRoutingTts extends FlutterTts {
  VoiceRoutingTts(this.voices, {required this._settings, @visibleForTesting AudioPlayer Function()? player}) : _newPlayer = player ?? AudioPlayer.new;

  final HebrewVoices voices;
  final VoiceSettings Function() _settings;
  final AudioPlayer Function() _newPlayer;

  /// What the next utterance is (TtsService sets it before each).
  SpeechRole role = SpeechRole.mikrah;

  // Made for the first utterance of the app's voice, so that a device that
  // never hears it never starts a player.
  AudioPlayer? _audio;
  StreamSubscription<void>? _completions;

  AudioPlayer get _player => _audio ??= _start(_newPlayer());

  AudioPlayer _start(AudioPlayer player) {
    // The speech service holds the audio focus (Android) and sets the
    // session (iOS): the player only plays.
    unawaited(
      player
          .setAudioContext(
            AudioContext(
              android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none, usageType: AndroidUsageType.media),
              iOS: AudioContextIOS(
                category: AVAudioSessionCategory.playback,
                options: const {AVAudioSessionOptions.duckOthers, AVAudioSessionOptions.interruptSpokenAudioAndMixWithOthers},
              ),
            ),
          )
          .then((_) {}, onError: (Object _) {}),
    );
    _completions = player.onPlayerComplete.listen((_) {
      if (!_playing) return;
      _playing = false;
      completionHandler?.call();
    });
    return player;
  }

  String _language = 'he-IL';
  double _rate = kDefaultSpeechRate;

  // An utterance of the app's voice is being made ([_making]) or played.
  bool _making = false;
  bool _playing = false;
  int _token = 0;

  static bool _isHebrew(String language) => language.toLowerCase().startsWith('he') || language.toLowerCase().startsWith('iw');

  /// The voice that reads [text] as [role], or null for the device's.
  String? voiceFor(String text, SpeechRole role) {
    if (!_isHebrew(_language) || !HebrewPhonemes.isPointed(text)) return null;
    final chosen = _settings().voiceFor(role);
    if (chosen == VoiceSettings.deviceVoice) return null;
    if (voices.ready(chosen)) return chosen;
    return voices.readyVoices.firstOrNull?.id;
  }

  /// The pace the reader set, relative to the voices' own.
  double get _speed => (_rate / kDefaultSpeechRate).clamp(0.25, 4.0);

  // Utterances made ahead of time ([prefetch]): the next of a queue.
  final _prepared = <String, Future<Uint8List>>{};

  String _key(String text, String voice) => '$voice|$_speed|${_settings().hashCode}|$text';

  Future<Uint8List> _make(String text, String voice) =>
      _prepared.remove(_key(text, voice)) ?? voices.speak(text, id: voice, settings: _settings(), speed: _speed);

  /// Makes [text], read as [role], ahead of its turn, so that it is ready to
  /// play once the one before it ends. Does nothing for the device's voice.
  void prefetch(String text, {required SpeechRole role}) {
    final voice = voiceFor(text, role);
    if (voice == null) return;
    final key = _key(text, voice);
    if (_prepared.containsKey(key)) return;
    while (_prepared.length >= 3) {
      _prepared.remove(_prepared.keys.first);
    }
    final made = _prepared[key] = voices.speak(text, id: voice, settings: _settings(), speed: _speed);
    made.then(
      (_) {},
      onError: (Object _) {
        _prepared.remove(key);
      },
    );
  }

  @override
  Future<dynamic> setLanguage(String language) {
    _language = language;
    return super.setLanguage(language);
  }

  @override
  Future<dynamic> setSpeechRate(double rate) {
    // The browser's rate is given doubled (TtsService.webEngine).
    _rate = kIsWeb ? rate / 2 : rate;
    return super.setSpeechRate(rate);
  }

  /// Hebrew is available whenever one of the app's voices is, and the
  /// reader hasn't chosen the device's.
  @override
  Future<dynamic> isLanguageAvailable(String language) async {
    if (_isHebrew(language) && _settings().torah != VoiceSettings.deviceVoice && voices.readyVoices.isNotEmpty) return true;
    return super.isLanguageAvailable(language);
  }

  @override
  Future<dynamic> get getVoices async {
    final list = await super.getVoices;
    if (voices.readyVoices.isEmpty) return list;
    return [
      ...?(list as List?),
      {'name': 'Shnayim Mikrah', 'locale': 'he-IL'},
    ];
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    final voice = voiceFor(text, role);
    if (voice == null) return super.speak(HebrewText.stripTeamim(text), focus: focus);
    final token = ++_token;
    _making = true;
    try {
      final audio = await _make(text, voice);
      if (token != _token) return 1; // stopped meanwhile, and reported then
      _making = false;
      _playing = true;
      startHandler?.call();
      await _player.play(BytesSource(audio, mimeType: 'audio/wav'));
      return 1;
    } catch (_) {
      if (token != _token) return 1;
      _making = false;
      _playing = false;
      // The device's voice reads it instead.
      return super.speak(HebrewText.stripTeamim(text), focus: focus);
    }
  }

  @override
  Future<dynamic> stop() async {
    if (!_making && !_playing) return super.stop();
    _token++;
    _making = false;
    _playing = false;
    try {
      await _audio?.stop();
    } catch (_) {}
    cancelHandler?.call();
    return 1;
  }

  void dispose() {
    unawaited(_completions?.cancel());
    unawaited(_audio?.dispose());
  }
}
