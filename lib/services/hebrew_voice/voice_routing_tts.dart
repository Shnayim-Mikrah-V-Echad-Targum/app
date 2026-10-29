import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/text/hebrew_phonemes.dart';
import '../../core/text/hebrew_text.dart';
import 'hebrew_voice.dart';

/// The speech engine TtsService speaks through: the device's own, but for
/// pointed Hebrew and Aramaic once the app's Hebrew voice is on the device
/// ([HebrewVoice]), which reads it here and plays it, reporting its start,
/// end and stop as the device's engine would, so that the service, its queue
/// and its audio session are the same whichever voice reads.
///
/// The Hebrew comes with its cantillation, for the stress
/// (HebrewSpeech.spoken, keepTeamim): it is removed for the device's voices,
/// which mis-read it. Unpointed Hebrew (Rashi), and every other language,
/// are the device's to read; and should the app's voice fail, the device's
/// reads in its place.
class VoiceRoutingTts extends FlutterTts {
  VoiceRoutingTts(this.voice, {@visibleForTesting AudioPlayer Function()? player}) : _newPlayer = player ?? AudioPlayer.new;

  final HebrewVoice voice;
  final AudioPlayer Function() _newPlayer;

  // Made for the first utterance of the app's voice, so that a device that
  // never hears it never starts a player.
  AudioPlayer? _audio;
  StreamSubscription<void>? _completions;

  AudioPlayer get _player => _audio ??= _start(_newPlayer());

  AudioPlayer _start(AudioPlayer player) {
    // The speech service holds the audio focus (Android) and sets the
    // session (iOS): the player only plays.
    unawaited(player
        .setAudioContext(AudioContext(
          android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none, usageType: AndroidUsageType.media),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.duckOthers, AVAudioSessionOptions.interruptSpokenAudioAndMixWithOthers},
          ),
        ))
        .then((_) {}, onError: (Object _) {}));
    _completions = player.onPlayerComplete.listen((_) {
      if (!_playing) return;
      _playing = false;
      completionHandler?.call();
    });
    return player;
  }

  String _language = 'he-IL';
  double _rate = 0.5;

  // An utterance of the app's voice is being made ([_making]) or played.
  bool _making = false;
  bool _playing = false;
  int _token = 0;

  bool get _hebrew => _language.toLowerCase().startsWith('he') || _language.toLowerCase().startsWith('iw');

  /// Whether [text] is for the app's voice.
  bool _ours(String text) => _hebrew && voice.ready && HebrewPhonemes.isPointed(text);

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

  /// Hebrew is available whenever the app's own voice is.
  @override
  Future<dynamic> isLanguageAvailable(String language) async {
    if (voice.ready && (language.toLowerCase().startsWith('he') || language.toLowerCase().startsWith('iw'))) return true;
    return super.isLanguageAvailable(language);
  }

  @override
  Future<dynamic> get getVoices async {
    final voices = await super.getVoices;
    if (!voice.ready) return voices;
    return [
      ...?(voices as List?),
      {'name': 'Shnayim Mikrah', 'locale': 'he-IL'},
    ];
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    if (!_ours(text)) return super.speak(HebrewText.stripTeamim(text), focus: focus);
    final token = ++_token;
    _making = true;
    try {
      final audio = await voice.speak(text, rate: _rate);
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
